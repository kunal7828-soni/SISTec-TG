import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/student.dart';
import '../student_repository.dart';

class FirestoreStudentRepository implements StudentRepository {
  FirestoreStudentRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('students');

  @override
  Stream<List<Student>> watchStudents({bool activeOnly = false}) {
    Query<Map<String, dynamic>> query = _collection.orderBy('name');
    if (activeOnly) query = query.where('active', isEqualTo: true);
    return query.snapshots().map(
          (snapshot) => snapshot.docs.map(Student.fromFirestore).toList(),
        );
  }

  @override
  Future<Student?> getStudentById(String studentId) async {
    final doc = await _collection.doc(studentId).get();
    return doc.exists ? Student.fromFirestore(doc) : null;
  }

  @override
  Stream<List<Student>> watchStudentsByTg(
    String tgId, {
    bool activeOnly = false,
  }) {
    Query<Map<String, dynamic>> query =
        _collection.where('assignedTgId', isEqualTo: tgId).orderBy('name');
    if (activeOnly) query = query.where('active', isEqualTo: true);
    return query.snapshots().map(
          (snapshot) => snapshot.docs.map(Student.fromFirestore).toList(),
        );
  }

  @override
  Future<void> addStudent(Student student) async {
    await _collection.doc(student.studentId).set({
      ...student.toFirestore(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateStudent(Student student) async {
    await _collection.doc(student.studentId).update({
      ...student.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> assignToTg(String studentId, String? tgId) async {
    await _collection.doc(studentId).update({
      'assignedTgId': tgId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setActive(String studentId, bool active) async {
    await _collection.doc(studentId).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteStudent(String studentId) async {
    await _collection.doc(studentId).delete();
  }
}
