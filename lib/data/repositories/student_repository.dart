import '../models/student.dart';

abstract interface class StudentRepository {
  Stream<List<Student>> watchStudents({bool activeOnly = false});
  Future<Student?> getStudentById(String studentId);
  Stream<List<Student>> watchStudentsByTg(
    String tgId, {
    bool activeOnly = false,
  });
  Future<void> addStudent(Student student);
  Future<void> updateStudent(Student student);
  Future<void> assignToTg(String studentId, String? tgId);
  Future<void> setActive(String studentId, bool active);
  Future<void> deleteStudent(String studentId);
}
