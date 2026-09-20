import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/attendance.dart';
import '../attendance_repository.dart';

class FirestoreAttendanceRepository implements AttendanceRepository {
  FirestoreAttendanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('attendance');

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  Stream<List<Attendance>> watchAttendanceForDate(DateTime date) {
    final day = _day(date);
    return _collection
        .where('date', isEqualTo: Timestamp.fromDate(day))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(Attendance.fromFirestore).toList(),
        );
  }

  @override
  Stream<List<Attendance>> watchAttendanceForTgAndDate(
    String tgId,
    DateTime date,
  ) {
    final day = _day(date);
    return _collection
        .where('tgId', isEqualTo: tgId)
        .where('date', isEqualTo: Timestamp.fromDate(day))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(Attendance.fromFirestore).toList(),
        );
  }

  @override
  Stream<List<Attendance>> watchAttendanceForStudent(String studentId) {
    return _collection
        .where('studentId', isEqualTo: studentId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map(Attendance.fromFirestore).toList(),
        );
  }

  @override
  Future<Attendance?> getAttendance(String studentId, DateTime date) async {
    final id = Attendance.documentId(studentId: studentId, date: date);
    final doc = await _collection.doc(id).get();
    return doc.exists ? Attendance.fromFirestore(doc) : null;
  }

  @override
  Future<bool> attendanceExists(String studentId, DateTime date) async {
    final id = Attendance.documentId(studentId: studentId, date: date);
    final doc = await _collection.doc(id).get();
    return doc.exists;
  }

  @override
  Future<void> createOrUpdateAttendance(Attendance attendance) async {
    final id = Attendance.documentId(
      studentId: attendance.studentId,
      date: attendance.date,
    );

    await _collection.doc(id).set({
      ...attendance.toFirestore(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (attendance.markedAt == null) 'markedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<List<Attendance>> getAttendanceHistory({
    String? studentId,
    String? tgId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    Query<Map<String, dynamic>> query = _collection.orderBy(
      'date',
      descending: true,
    );

    if (studentId != null) {
      query = query.where('studentId', isEqualTo: studentId);
    }
    if (tgId != null) {
      query = query.where('tgId', isEqualTo: tgId);
    }
    if (from != null) {
      query = query.where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(_day(from)),
      );
    }
    if (to != null) {
      query = query.where(
        'date',
        isLessThanOrEqualTo: Timestamp.fromDate(_day(to)),
      );
    }
    if (limit != null) query = query.limit(limit);

    final snapshot = await query.get();
    return snapshot.docs.map(Attendance.fromFirestore).toList();
  }
}
