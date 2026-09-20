import 'package:cloud_firestore/cloud_firestore.dart';

class Tg {
  const Tg({
    required this.tgId,
    required this.name,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    this.pin,
  });

  final String tgId;
  final String name;
  final String? pin;
  final bool active;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Tg.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw const FormatException('TG document is missing its data.');
    }

    return Tg(
      tgId: _requiredString(data, 'tgId', doc.id),
      name: _requiredString(data, 'name', doc.id),
      pin: _optionalString(data['pin']),
      active: _optionalBool(data['active'], defaultValue: true),
      createdAt: _timestamp(data['createdAt']),
      updatedAt: _timestamp(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'tgId': tgId,
        'name': name,
        if (pin != null && pin!.isNotEmpty) 'pin': pin,
        'active': active,
        'createdAt': createdAt == null ? null : Timestamp.fromDate(createdAt!),
        'updatedAt': updatedAt == null ? null : Timestamp.fromDate(updatedAt!),
      };

  Tg copyWith({
    String? tgId,
    String? name,
    String? pin,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tg(
      tgId: tgId ?? this.tgId,
      name: name ?? this.name,
      pin: pin ?? this.pin,
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
      throw FormatException('Invalid $field in TG document $docId.');
    }
    return value.trim();
  }

  static String? _optionalString(Object? value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  static bool _optionalBool(Object? value, {required bool defaultValue}) =>
      value is bool ? value : defaultValue;

  static DateTime? _timestamp(Object? value) => value is Timestamp
      ? value.toDate()
      : value is DateTime
          ? value
          : null;
}
