import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho nhóm khách hàng
class CustomerGroupModel {
  final String id;
  final String name;
  final double discountPercent; // Số dương là giảm giá, số âm là tăng giá
  final String? description;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerGroupModel({
    required this.id,
    required this.name,
    required this.discountPercent,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  /// Tạo CustomerGroupModel từ Firestore document
  factory CustomerGroupModel.fromFirestore(Map<String, dynamic> data, String id) {
    return CustomerGroupModel(
      id: id,
      name: data['name'] ?? '',
      discountPercent: (data['discountPercent'] ?? 0).toDouble(),
      description: data['description'],
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
    );
  }

  /// Tạo CustomerGroupModel từ Map
  factory CustomerGroupModel.fromMap(Map<String, dynamic> map) {
    return CustomerGroupModel(
      id: map['id'] as String,
      name: map['name'] as String,
      discountPercent: (map['discountPercent'] as num).toDouble(),
      description: map['description'] as String?,
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
      'discountPercent': discountPercent,
      'description': description,
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
      'discountPercent': discountPercent,
      'description': description,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Tạo bản copy với các trường được cập nhật
  CustomerGroupModel copyWith({
    String? id,
    String? name,
    double? discountPercent,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerGroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      discountPercent: discountPercent ?? this.discountPercent,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
