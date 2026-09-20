import '../models/attendance.dart';

abstract interface class AttendanceRepository {
  Stream<List<Attendance>> watchAttendanceForDate(DateTime date);
  Stream<List<Attendance>> watchAttendanceForTgAndDate(
    String tgId,
    DateTime date,
  );
  Stream<List<Attendance>> watchAttendanceForStudent(String studentId);
  Future<Attendance?> getAttendance(String studentId, DateTime date);
  Future<bool> attendanceExists(String studentId, DateTime date);
  Future<void> createOrUpdateAttendance(Attendance attendance);
  Future<List<Attendance>> getAttendanceHistory({
    String? studentId,
    String? tgId,
    DateTime? from,
    DateTime? to,
    int? limit,
  });
}
