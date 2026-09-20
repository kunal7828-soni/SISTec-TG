import 'dart:async';

import '../../models/student.dart';
import '../../models/tg.dart';
import '../student_repository.dart';
import '../../sheets/google_attendance_data_source.dart';
import '../../../core/services/google_sheets_service.dart';

class GoogleSheetsStudentRepository implements StudentRepository {
  GoogleSheetsStudentRepository({
    GoogleAttendanceDataSource? dataSource,
    GoogleSheetsService? sheetsService,
  })  : _dataSource = dataSource ?? GoogleAttendanceDataSource(),
        _sheetsService = sheetsService ?? GoogleSheetsService.instance;

  final GoogleAttendanceDataSource _dataSource;
  final GoogleSheetsService _sheetsService;

  Tg? _findTg(String? tgId) {
    if (tgId == null || tgId.isEmpty) return null;

    for (final tg in _dataSource.tgs) {
      if (tg.tgId == tgId) return tg;
    }

    return null;
  }

  @override
  Stream<List<Student>> watchStudents({
    bool activeOnly = false,
  }) async* {
    await _dataSource.load();

    yield _filter(
      _dataSource.students,
      activeOnly: activeOnly,
    );

    await for (final _ in _dataSource.changes) {
      yield _filter(
        _dataSource.students,
        activeOnly: activeOnly,
      );
    }
  }

  List<Student> _filter(
    List<Student> items, {
    required bool activeOnly,
  }) {
    if (!activeOnly) {
      return List<Student>.from(items);
    }

    return items.where((student) => student.active).toList();
  }

  @override
  Future<Student?> getStudentById(
    String studentId,
  ) async {
    await _dataSource.load();

    for (final student in _dataSource.students) {
      if (student.studentId == studentId) {
        return student;
      }
    }

    return null;
  }

  @override
  Stream<List<Student>> watchStudentsByTg(
    String tgId, {
    bool activeOnly = false,
  }) async* {
    await _dataSource.load();

    List<Student> getStudents() {
      final students = _dataSource.students
          .where(
            (student) => student.assignedTgId == tgId,
          )
          .toList();

      return _filter(
        students,
        activeOnly: activeOnly,
      );
    }

    yield getStudents();

    await for (final _ in _dataSource.changes) {
      yield getStudents();
    }
  }

  @override
  Future<void> addStudent(Student student) async {
    final tg = _findTg(student.assignedTgId);

    await _sheetsService.addStudent(
      tgId: student.assignedTgId ?? '',
      tgName: tg?.name ?? '',
      name: student.name,
      rollNumber: student.rollNumber,
      semester: student.semester,
      section: student.section,
    );

    await _dataSource.refresh();
  }

  @override
  Future<void> updateStudent(Student student) async {
    final tg = _findTg(student.assignedTgId);

    await _sheetsService.updateStudent(
      rollNumber: student.studentId,
      tgId: student.assignedTgId ?? '',
      tgName: tg?.name ?? '',
      name: student.name,
      semester: student.semester,
      section: student.section,
    );

    await _dataSource.refresh();
  }

  @override
  Future<void> assignToTg(
    String studentId,
    String? tgId,
  ) async {
    final current = await getStudentById(studentId);
    if (current == null) {
      throw StateError('Student $studentId was not found.');
    }

    final updated = current.copyWith(
      assignedTgId: tgId,
      updatedAt: DateTime.now(),
    );

    await updateStudent(updated);
  }

  @override
  Future<void> setActive(
    String studentId,
    bool active,
  ) {
    throw UnimplementedError(
      'Student active status is not currently '
      'represented in Daily_Attendace.',
    );
  }

  @override
  Future<void> deleteStudent(
    String studentId,
  ) async {
    await _sheetsService.deleteStudent(rollNumber: studentId);
    await _dataSource.refresh();
  }
}
