import 'package:cloud_firestore/cloud_firestore.dart';

/// Model nhà cung cấp (theo shop).
class SupplierModel {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? email;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SupplierModel({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.email,
    this.note,
    this.createdAt,
    this.updatedAt,
  });

  factory SupplierModel.fromFirestore(Map<String, dynamic> data, String id) {
    return SupplierModel(
      id: id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String?,
      address: data['address'] as String?,
      email: data['email'] as String?,
      note: data['note'] as String?,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = <String, dynamic>{
      'name': name,
    };
    if (phone != null) map['phone'] = phone;
    if (address != null) map['address'] = address;
    if (email != null) map['email'] = email;
    if (note != null) map['note'] = note;
    if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt!);
    if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    return map;
  }

  SupplierModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? email,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplierModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      email: email ?? this.email,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
