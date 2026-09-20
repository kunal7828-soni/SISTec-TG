import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { present, absent }

class Attendance {
  const Attendance({
    required this.attendanceId,
    required this.studentId,
    required this.tgId,
    required this.date,
    required this.status,
    required this.markedAt,
    required this.markedBy,
    required this.updatedAt,
  });

  final String attendanceId;
  final String studentId;
  final String tgId;
  final DateTime date;
  final AttendanceStatus status;
  final DateTime? markedAt;
  final String? markedBy;
  final DateTime? updatedAt;

  /// Deterministic ID: one student + one calendar date can map to one document.
  static String documentId(
      {required String studentId, required DateTime date}) {
    final normalized = DateTime(date.year, date.month, date.day);
    final dateKey = '${normalized.year.toString().padLeft(4, '0')}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
    return '${dateKey}_$studentId';
  }

  factory Attendance.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw const FormatException('Attendance document is missing its data.');
    }

    final date = _timestamp(data['date']);
    if (date == null) {
      throw FormatException('Invalid date in attendance document ${doc.id}.');
    }

    return Attendance(
      attendanceId: doc.id,
      studentId: _requiredString(data, 'studentId', doc.id),
      tgId: _requiredString(data, 'tgId', doc.id),
      date: date,
      status: _status(data['status'], doc.id),
      markedAt: _timestamp(data['markedAt']),
      markedBy: _optionalString(data['markedBy']),
      updatedAt: _timestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'tgId': tgId,
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'status': status.name,
        'markedAt': markedAt == null ? null : Timestamp.fromDate(markedAt!),
        'markedBy': markedBy,
        'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      };

  Attendance copyWith({
    String? attendanceId,
    String? studentId,
    String? tgId,
    DateTime? date,
    AttendanceStatus? status,
    DateTime? markedAt,
    String? markedBy,
    DateTime? updatedAt,
  }) {
    return Attendance(
      attendanceId: attendanceId ?? this.attendanceId,
      studentId: studentId ?? this.studentId,
      tgId: tgId ?? this.tgId,
      date: date ?? this.date,
      status: status ?? this.status,
      markedAt: markedAt ?? this.markedAt,
      markedBy: markedBy ?? this.markedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static String _requiredString(
    Map<String, dynamic> data,
    String field,
    String docId,
  ) {
    final value = data[field];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Invalid $field in attendance document $docId.');
    }
    return value.trim();
  }

  static String? _optionalString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static DateTime? _timestamp(Object? value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
          ? value
          : null;

  static AttendanceStatus _status(Object? value, String docId) {
    if (value is String) {
      for (final status in AttendanceStatus.values) {
        if (status.name == value) return status;
      }
    }
    throw FormatException('Invalid status in attendance document $docId.');
  }
}
