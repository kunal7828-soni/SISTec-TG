import 'dart:async';

import '../models/attendance.dart';
import '../models/student.dart';
import '../models/tg.dart';
import 'daily_attendance_sheet.dart';
import 'google_report_sync_service.dart';
import '../../core/services/google_sheets_service.dart';

class GoogleAttendanceDataSource {
  GoogleAttendanceDataSource({
    GoogleSheetsService? sheetsService,
    GoogleReportSyncService? reportSyncService,
  })  : _sheetsService = sheetsService ?? GoogleSheetsService.instance,
        _reportSyncService = reportSyncService ?? GoogleReportSyncService();

  final GoogleSheetsService _sheetsService;
  final GoogleReportSyncService _reportSyncService;

  DailyAttendanceSheet? _sheet;

  final StreamController<void> _changes = StreamController<void>.broadcast();

  bool _loading = false;

  Future<DailyAttendanceSheet> load({
    bool forceRefresh = false,
  }) async {
    if (_sheet != null && !forceRefresh) {
      return _sheet!;
    }

    if (_loading) {
      while (_loading) {
        await Future<void>.delayed(
          const Duration(milliseconds: 50),
        );
      }

      if (_sheet != null) {
        return _sheet!;
      }
    }

    _loading = true;

    try {
      // Start each new day with a date column immediately after Section.
      // Existing attendance dates are shifted right automatically.
      final now = DateTime.now();
      await _sheetsService.ensureDailyAttendanceDate(
        DateTime(now.year, now.month, now.day),
      );

      final rawRows = await _sheetsService.readDailyAttendance();

      final parsed = DailyAttendanceSheet.fromRawRows(rawRows);

      _sheet = parsed;

      // Keep the two derived report tabs synchronized with the source data.
      await _reportSyncService.sync(parsed);

      _changes.add(null);

      return parsed;
    } finally {
      _loading = false;
    }
  }

  DailyAttendanceSheet get current {
    final sheet = _sheet;

    if (sheet == null) {
      throw StateError(
        'Google attendance data has not been loaded yet.',
      );
    }

    return sheet;
  }

  List<Tg> get tgs => current.tgs;

  List<Student> get students => current.students;

  List<Attendance> get attendance => current.attendance;

  Stream<void> get changes => _changes.stream;

  Future<void> refresh() async {
    await load(forceRefresh: true);
  }

  void clearCache() {
    _sheet = null;
  }

  void dispose() {
    _changes.close();
  }
}
