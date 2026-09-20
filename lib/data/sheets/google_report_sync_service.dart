import '../../core/services/google_sheets_service.dart';
import 'daily_attendance_sheet.dart';

/// Keeps the two derived Google Sheet tabs in sync with Daily_Attendace.
///
/// Daily_Attendace remains the source of truth. Attendance_Count and
/// configuration is a generated view that are safe to rebuild whenever the
/// source sheet is refreshed.
class GoogleReportSyncService {
  GoogleReportSyncService({GoogleSheetsService? sheetsService})
      : _sheetsService = sheetsService ?? GoogleSheetsService.instance;

  final GoogleSheetsService _sheetsService;

  static const String attendanceCountSheet = 'Attendance_Count';
  static const String configurationSheet = 'configuration';

  Future<void> sync(DailyAttendanceSheet sheet) async {
    final dates = _datesFromHeaders(sheet.headers);

    await _syncAttendanceCount(sheet, dates);
    await _syncConfiguration(sheet, dates);
  }

  Future<void> _syncAttendanceCount(
    DailyAttendanceSheet sheet,
    List<DateTime> dates,
  ) async {
    final values = <List<Object?>>[];

    for (final date in dates) {
      values.add(<Object?>['Date', _formatDisplayDate(date)]);
      values.add(<Object?>[
        'TG_ID',
        'TG_Name',
        'Semester',
        'Section',
        'Total_Students',
        'Absent',
        'Present',
      ]);

      final groups = <String, _GroupCounter>{};

      for (final row in sheet.rows) {
        final key = '${row.tgId}\u0000${row.tgName}\u0000'
            '${row.semester}\u0000${row.section}';
        final counter = groups.putIfAbsent(
          key,
          () => _GroupCounter(
            tgId: row.tgId,
            tgName: row.tgName,
            semester: row.semester,
            section: row.section,
          ),
        );

        counter.total++;
        final status = row.attendance[date];
        if (status?.name == 'present') {
          counter.present++;
        } else if (status?.name == 'absent') {
          counter.absent++;
        }
      }

      final counters = groups.values.toList()
        ..sort((a, b) {
          final tg = a.tgId.compareTo(b.tgId);
          if (tg != 0) return tg;
          final semester = a.semester.compareTo(b.semester);
          if (semester != 0) return semester;
          return a.section.compareTo(b.section);
        });

      for (final counter in counters) {
        values.add(<Object?>[
          counter.tgId,
          counter.tgName,
          counter.semester,
          counter.section,
          counter.total,
          counter.absent,
          counter.present,
        ]);
      }

      values.add(<Object?>[]);
    }

    if (values.isEmpty) {
      values.add(<Object?>[
        'Date',
        'No attendance dates found',
      ]);
    }

    await _sheetsService.replaceSheetValues(
      attendanceCountSheet,
      values,
      clearRange: 'A:Z',
    );
  }

  Future<void> _syncConfiguration(
    DailyAttendanceSheet sheet,
    List<DateTime> dates,
  ) async {
    final values = <List<Object?>>[];

    for (final date in dates) {
      values.add(<Object?>['Date', _formatDisplayDate(date)]);
      values.add(<Object?>[
        'Semester',
        'Present/Students',
        'Attendance %',
      ]);

      final groups = <String, _SemesterCounter>{};

      for (final row in sheet.rows) {
        final semester = row.semester.trim().isEmpty
            ? 'Unknown Semester'
            : row.semester.trim();
        final counter = groups.putIfAbsent(
          semester,
          () => _SemesterCounter(semester),
        );

        counter.totalStudents++;
        if (row.attendance[date]?.name == 'present') {
          counter.present++;
        }
      }

      final counters = groups.values.toList()
        ..sort((a, b) => _semesterSortKey(a.semester)
            .compareTo(_semesterSortKey(b.semester)));

      for (final counter in counters) {
        values.add(<Object?>[
          counter.semester,
          '${counter.present}/${counter.totalStudents}',
          '${counter.rate.toStringAsFixed(2)}%',
        ]);
      }

      values.add(<Object?>[]);
    }

    if (values.isEmpty) {
      values.add(<Object?>[
        'Date',
        'No attendance dates found',
      ]);
    }

    await _sheetsService.replaceSheetValues(
      configurationSheet,
      values,
      clearRange: 'A:Z',
    );
  }

  static List<DateTime> _datesFromHeaders(List<String> headers) {
    final result = <DateTime>{};

    for (final header in headers) {
      final date = _parseDate(header);
      if (date != null) result.add(date);
    }

    final dates = result.toList()..sort((a, b) => b.compareTo(a));
    return dates;
  }

  static DateTime? _parseDate(String value) {
    final parts = value.trim().split('-');
    if (parts.length != 3) return null;

    final day = int.tryParse(parts[0]);
    final month = _monthNumber(parts[1]);
    var year = int.tryParse(parts[2]);

    if (day == null || month == null || year == null) return null;
    if (parts[2].length == 2) year += 2000;

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static int? _monthNumber(String value) {
    const months = <String, int>{
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    return months[value.trim().toLowerCase()];
  }

  static String _formatDisplayDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static int _semesterSortKey(String semester) {
    final match = RegExp(r'(\d+)').firstMatch(semester);
    return match == null ? 999 : int.parse(match.group(1)!);
  }
}

class _GroupCounter {
  _GroupCounter({
    required this.tgId,
    required this.tgName,
    required this.semester,
    required this.section,
  });

  final String tgId;
  final String tgName;
  final String semester;
  final String section;
  int total = 0;
  int present = 0;
  int absent = 0;
}

class _SemesterCounter {
  _SemesterCounter(this.semester);

  final String semester;
  int totalStudents = 0;
  int present = 0;

  double get rate => totalStudents == 0 ? 0 : present / totalStudents * 100;
}
