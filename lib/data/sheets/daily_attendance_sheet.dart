import '../models/attendance.dart';
import '../models/student.dart';
import '../models/tg.dart';

class DailyAttendanceSheet {
  DailyAttendanceSheet({
    required this.headers,
    required this.rows,
  });

  final List<String> headers;
  final List<DailyAttendanceRow> rows;

  factory DailyAttendanceSheet.fromRawRows(
    List<List<Object?>> rawRows,
  ) {
    if (rawRows.isEmpty) {
      return DailyAttendanceSheet(
        headers: const [],
        rows: const [],
      );
    }

    final headers =
        rawRows.first.map((value) => value?.toString().trim() ?? '').toList();

    final rows = <DailyAttendanceRow>[];

    for (final rawRow in rawRows.skip(1)) {
      final isEmpty = rawRow.every(
        (value) => value == null || value.toString().trim().isEmpty,
      );

      if (isEmpty) {
        continue;
      }

      rows.add(
        DailyAttendanceRow.fromRawRow(
          headers: headers,
          values: rawRow,
        ),
      );
    }

    return DailyAttendanceSheet(
      headers: headers,
      rows: rows,
    );
  }

  List<Tg> get tgs {
    final result = <String, Tg>{};

    for (final row in rows) {
      if (row.tgId.isEmpty) {
        continue;
      }

      result.putIfAbsent(
        row.tgId,
        () => Tg(
          tgId: row.tgId,
          name: row.tgName,
          active: true,
          createdAt: null,
          updatedAt: null,
        ),
      );
    }

    return result.values.toList();
  }

  List<Student> get students {
    final result = <String, Student>{};

    for (final row in rows) {
      if (row.studentId.isEmpty) {
        continue;
      }

      result.putIfAbsent(
          row.studentId,
          () => Student(
                studentId: row.studentId,
                name: row.studentName,
                rollNumber: row.rollNumber,
                semester: row.semester,
                section: row.section,
                assignedTgId: row.tgId.isEmpty ? null : row.tgId,
                active: true,
                createdAt: null,
                updatedAt: null,
              ));
    }

    return result.values.toList();
  }

  List<Attendance> get attendance {
    final result = <Attendance>[];

    for (final row in rows) {
      if (row.studentId.isEmpty) {
        continue;
      }

      for (final entry in row.attendance.entries) {
        final status = entry.value;

        if (status == null) {
          continue;
        }

        result.add(
          Attendance(
            attendanceId: Attendance.documentId(
              studentId: row.studentId,
              date: entry.key,
            ),
            studentId: row.studentId,
            tgId: row.tgId,
            date: entry.key,
            status: status,
            markedAt: null,
            markedBy: null,
            updatedAt: null,
          ),
        );
      }
    }

    return result;
  }
}

class DailyAttendanceRow {
  DailyAttendanceRow({
    required this.tgId,
    required this.tgName,
    required this.studentName,
    required this.rollNumber,
    required this.semester,
    required this.section,
    required this.attendance,
  });

  final String tgId;
  final String tgName;
  final String studentName;
  final String rollNumber;
  final String semester;
  final String section;

  final Map<DateTime, AttendanceStatus?> attendance;

  String get studentId {
    if (rollNumber.isNotEmpty) {
      return rollNumber;
    }

    return '$tgId-$studentName';
  }

  factory DailyAttendanceRow.fromRawRow({
    required List<String> headers,
    required List<Object?> values,
  }) {
    final row = <String, String>{};

    for (var index = 0; index < headers.length; index++) {
      if (headers[index].isEmpty) {
        continue;
      }

      final value = index < values.length ? values[index] : null;

      row[headers[index]] = value?.toString().trim() ?? '';
    }

    final attendance = <DateTime, AttendanceStatus?>{};

    // Date columns are detected from the header itself.
    // No hard-coded column number is used.
    for (final header in headers) {
      final date = _parseDate(header);

      if (date == null) {
        continue;
      }

      attendance[date] = _parseStatus(row[header]);
    }

    return DailyAttendanceRow(
      tgId: row['TG_ID'] ?? '',
      tgName: row['TG_Name'] ?? '',
      studentName: row['Student_Name'] ?? '',
      rollNumber: row['RollNo.'] ?? '',
      semester: row['Semester'] ?? '',
      section: row['Section'] ?? '',
      attendance: attendance,
    );
  }

  static AttendanceStatus? _parseStatus(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    switch (value.trim().toUpperCase()) {
      case 'P':
      case 'PRESENT':
        return AttendanceStatus.present;

      case 'A':
      case 'ABSENT':
        return AttendanceStatus.absent;

      default:
        return null;
    }
  }

  static DateTime? _parseDate(String value) {
    final parts = value.trim().split('-');

    if (parts.length != 3) {
      return null;
    }

    final day = int.tryParse(parts[0]);
    final month = _monthNumber(parts[1]);

    if (day == null || month == null) {
      return null;
    }

    var year = int.tryParse(parts[2]);

    if (year == null) {
      return null;
    }

    // Supports both:
    // 10-Sep-26
    // 10-Sep-2026
    if (parts[2].length == 2) {
      year += 2000;
    }

    try {
      final date = DateTime(year, month, day);

      // Prevent invalid dates such as 31-Feb-26.
      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }

      return date;
    } catch (_) {
      return null;
    }
  }

  static int? _monthNumber(String value) {
    switch (value.trim().toLowerCase()) {
      case 'jan':
        return 1;
      case 'feb':
        return 2;
      case 'mar':
        return 3;
      case 'apr':
        return 4;
      case 'may':
        return 5;
      case 'jun':
        return 6;
      case 'jul':
        return 7;
      case 'aug':
        return 8;
      case 'sep':
        return 9;
      case 'oct':
        return 10;
      case 'nov':
        return 11;
      case 'dec':
        return 12;
      default:
        return null;
    }
  }
}
