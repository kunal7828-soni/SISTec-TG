import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  const Student({
    required this.studentId,
    required this.name,
    required this.rollNumber,
    required this.semester,
    required this.section,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    this.assignedTgId,
  });

  final String studentId;
  final String name;
  final String rollNumber;
  final String semester;
  final String section;
  final String? assignedTgId;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Student.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    if (data == null) {
      throw const FormatException(
        'Student document is missing its data.',
      );
    }

    return Student(
      studentId: _requiredString(
        data,
        'studentId',
        doc.id,
      ),
      name: _requiredString(
        data,
        'name',
        doc.id,
      ),
      rollNumber: _requiredString(
        data,
        'rollNumber',
        doc.id,
      ),
      semester: _optionalString(
            data['semester'],
          ) ??
          '',
      section: _optionalString(
            data['section'],
          ) ??
          '',
      assignedTgId: _optionalString(
        data['assignedTgId'],
      ),
      active: _optionalBool(
        data['active'],
        defaultValue: true,
      ),
      createdAt: _timestamp(
        data['createdAt'],
      ),
      updatedAt: _timestamp(
        data['updatedAt'],
      ),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'studentId': studentId,
        'name': name,
        'rollNumber': rollNumber,
        'semester': semester,
        'section': section,
        'assignedTgId': assignedTgId,
        'active': active,
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
        'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      };

  Student copyWith({
    String? studentId,
    String? name,
    String? rollNumber,
    String? semester,
    String? section,
    String? assignedTgId,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Student(
      studentId: studentId ?? this.studentId,
      name: name ?? this.name,
      rollNumber: rollNumber ?? this.rollNumber,
      semester: semester ?? this.semester,
      section: section ?? this.section,
      assignedTgId: assignedTgId ?? this.assignedTgId,
      active: active ?? this.active,
      createdAt: createdAt ?? this.createdAt,
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
      throw FormatException(
        'Invalid $field in student document $docId.',
      );
    }

    return value.trim();
  }

  static String? _optionalString(Object? value) {
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  static bool _optionalBool(
    Object? value, {
    required bool defaultValue,
  }) {
    return value is bool ? value : defaultValue;
  }

  static DateTime? _timestamp(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}
