import '../../core/utils/formatters.dart';

/// Client du magasin.
class Client {
  const Client({
    this.id,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.createdAt,
  });

  final int? id;
  final String firstName;
  final String lastName;
  final String phone;
  final DateTime createdAt;

  String get fullName => '$firstName $lastName'.trim();
  String get normalizedPhone => AppFormatters.normalizePhone(phone);

  Client copyWith({
    int? id,
    String? firstName,
    String? lastName,
    String? phone,
    DateTime? createdAt,
  }) {
    return Client(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory Client.fromMap(Map<String, Object?> map) {
    return Client(
      id: map['id'] as int?,
      firstName: map['first_name'] as String,
      lastName: map['last_name'] as String,
      phone: map['phone'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap({bool includeId = false}) {
    return <String, Object?>{
      if (includeId && id != null) 'id': id,
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'phone': phone.trim(),
      'phone_normalized': normalizedPhone,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
