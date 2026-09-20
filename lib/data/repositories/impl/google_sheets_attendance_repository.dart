import 'dart:async';

import '../../../core/services/google_sheets_service.dart';
import '../../models/attendance.dart';
import '../../sheets/google_attendance_data_source.dart';
import '../attendance_repository.dart';

class GoogleSheetsAttendanceRepository implements AttendanceRepository {
  GoogleSheetsAttendanceRepository({
    GoogleAttendanceDataSource? dataSource,
    GoogleSheetsService? sheetsService,
  })  : _dataSource = dataSource ?? GoogleAttendanceDataSource(),
        _sheetsService = sheetsService ?? GoogleSheetsService.instance;

  final GoogleAttendanceDataSource _dataSource;
  final GoogleSheetsService _sheetsService;

  static DateTime _day(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  @override
  Stream<List<Attendance>> watchAttendanceForDate(DateTime date) async* {
    await _dataSource.load();

    List<Attendance> getItems() {
      final target = _day(date);

      return _dataSource.attendance
          .where((attendance) => _day(attendance.date) == target)
          .toList();
    }

    yield getItems();

    await for (final _ in _dataSource.changes) {
      yield getItems();
    }
  }

  @override
  Stream<List<Attendance>> watchAttendanceForTgAndDate(
    String tgId,
    DateTime date,
  ) async* {
    await _dataSource.load();

    List<Attendance> getItems() {
      final target = _day(date);

      return _dataSource.attendance
          .where(
            (attendance) =>
                attendance.tgId == tgId && _day(attendance.date) == target,
          )
          .toList();
    }

    yield getItems();

    await for (final _ in _dataSource.changes) {
      yield getItems();
    }
  }

  @override
  Stream<List<Attendance>> watchAttendanceForStudent(
    String studentId,
  ) async* {
    await _dataSource.load();

    List<Attendance> getItems() {
      final items = _dataSource.attendance
          .where((attendance) => attendance.studentId == studentId)
          .toList();

      items.sort((a, b) => b.date.compareTo(a.date));
      return items;
    }

    yield getItems();

    await for (final _ in _dataSource.changes) {
      yield getItems();
    }
  }

  @override
  Future<Attendance?> getAttendance(
    String studentId,
    DateTime date,
  ) async {
    await _dataSource.load();

    final target = _day(date);

    for (final attendance in _dataSource.attendance) {
      if (attendance.studentId == studentId &&
          _day(attendance.date) == target) {
        return attendance;
      }
    }

    return null;
  }

  @override
  Future<bool> attendanceExists(
    String studentId,
    DateTime date,
  ) async {
    return await getAttendance(studentId, date) != null;
  }

  @override
  Future<void> createOrUpdateAttendance(Attendance attendance) async {
    final status = switch (attendance.status) {
      AttendanceStatus.present => 'P',
      AttendanceStatus.absent => 'A',
    };

    await _sheetsService.updateAttendanceStatus(
      rollNumber: attendance.studentId,
      date: attendance.date,
      status: status,
    );

    await _dataSource.refresh();
  }

  @override
  Future<List<Attendance>> getAttendanceHistory({
    String? studentId,
    String? tgId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    await _dataSource.load();

    var items = List<Attendance>.from(_dataSource.attendance);

    if (studentId != null) {
      items = items.where((item) => item.studentId == studentId).toList();
    }

    if (tgId != null) {
      items = items.where((item) => item.tgId == tgId).toList();
    }

    if (from != null) {
      final start = _day(from);
      items = items.where((item) => !_day(item.date).isBefore(start)).toList();
    }

    if (to != null) {
      final end = _day(to);
      items = items.where((item) => !_day(item.date).isAfter(end)).toList();
    }

    items.sort((a, b) => b.date.compareTo(a.date));

    if (limit != null && items.length > limit) {
      items = items.take(limit).toList();
    }

    return items;
  }
}
