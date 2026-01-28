import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho khách hàng
class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String? address;
  final String? groupId; // ID của CustomerGroupModel
  final double totalDebt; // Nợ hiện tại
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.address,
    this.groupId,
    this.totalDebt = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  /// Tạo CustomerModel từ Firestore document
  factory CustomerModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CustomerModel(
      id: id,
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      address: data['address'],
      groupId: data['groupId'],
      totalDebt: (data['totalDebt'] ?? 0).toDouble(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Tạo CustomerModel từ Map
  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      address: map['address'] as String?,
      groupId: map['groupId'] as String?,
      totalDebt: (map['totalDebt'] as num?)?.toDouble() ?? 0.0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }

  /// Chuyển đổi sang Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'groupId': groupId,
      'totalDebt': totalDebt,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Chuyển đổi sang Map (dùng cho SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'groupId': groupId,
      'totalDebt': totalDebt,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Tạo bản copy với các trường được cập nhật
  CustomerModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? groupId,
    double? totalDebt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      groupId: groupId ?? this.groupId,
      totalDebt: totalDebt ?? this.totalDebt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
