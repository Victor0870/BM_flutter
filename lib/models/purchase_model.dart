import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một phiếu nhập kho
class PurchaseModel {
  final String id;
  final String supplierName; // Tên nhà cung cấp
  final DateTime timestamp;
  final double totalAmount;
  final List<PurchaseItem> items;
  final String status; // 'DRAFT' (nháp) hoặc 'COMPLETED' (đã nhập)
  final String userId; // ID của shop/user tạo phiếu nhập
  final String branchId; // ID của chi nhánh nhập hàng (bắt buộc)

  PurchaseModel({
    required this.id,
    required this.supplierName,
    required this.timestamp,
    required this.totalAmount,
    required this.items,
    this.status = 'DRAFT',
    required this.userId,
    required this.branchId,
  });

  /// Tạo PurchaseModel từ Firestore document
  factory PurchaseModel.fromFirestore(Map<String, dynamic> data, String id) {
    return PurchaseModel(
      id: id,
      supplierName: data['supplierName'] ?? '',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => PurchaseItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      status: data['status'] ?? 'DRAFT',
      userId: data['userId'] ?? '',
      branchId: data['branchId'] ?? '', // Bắt buộc, mặc định rỗng nếu không có
    );
  }

  /// Tạo PurchaseModel từ JSON
  factory PurchaseModel.fromJson(Map<String, dynamic> json) {
    return PurchaseModel(
      id: json['id'] ?? '',
      supplierName: json['supplierName'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => PurchaseItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      status: json['status'] ?? 'DRAFT',
      userId: json['userId'] ?? '',
      branchId: json['branchId'] ?? '', // Bắt buộc, mặc định rỗng nếu không có
    );
  }

  /// Tạo PurchaseModel từ Map (dùng cho SQLite)
  factory PurchaseModel.fromMap(Map<String, dynamic> map) {
    return PurchaseModel(
      id: map['id'] as String,
      supplierName: map['supplierName'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      items: (map['items'] as String?) != null
          ? (PurchaseItem.fromJsonList(map['items'] as String))
          : [],
      status: map['status'] as String,
      userId: map['userId'] as String,
      branchId: map['branchId'] as String? ?? '', // Bắt buộc, mặc định rỗng nếu không có
    );
  }

  /// Chuyển đổi sang JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'supplierName': supplierName,
      'timestamp': timestamp.toIso8601String(),
      'totalAmount': totalAmount,
      'items': items.map((item) => item.toMap()).toList(),
      'status': status,
      'userId': userId,
      'branchId': branchId,
    };
  }

  /// Chuyển đổi sang Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'supplierName': supplierName,
      'timestamp': Timestamp.fromDate(timestamp),
      'totalAmount': totalAmount,
      'items': items.map((item) => item.toMap()).toList(),
      'status': status,
      'userId': userId,
      'branchId': branchId,
    };
  }

  /// Chuyển đổi sang Map (dùng cho SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplierName': supplierName,
      'timestamp': timestamp.toIso8601String(),
      'totalAmount': totalAmount,
      'items': items.map((item) => item.toMap()).toList().toString(), // Lưu dạng JSON string
      'status': status,
      'userId': userId,
      'branchId': branchId,
    };
  }

  /// Copy với các trường được cập nhật
  PurchaseModel copyWith({
    String? id,
    String? supplierName,
    DateTime? timestamp,
    double? totalAmount,
    List<PurchaseItem>? items,
    String? status,
    String? userId,
    String? branchId,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      supplierName: supplierName ?? this.supplierName,
      timestamp: timestamp ?? this.timestamp,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      branchId: branchId ?? this.branchId,
    );
  }
}

/// Model đại diện cho một item trong phiếu nhập
class PurchaseItem {
  final String productId;
  final String productName;
  final double quantity;
  final double importPrice; // Giá nhập tại thời điểm đó
  final double subtotal; // quantity * importPrice

  PurchaseItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.importPrice,
  }) : subtotal = quantity * importPrice;

  /// Tạo PurchaseItem từ Map
  factory PurchaseItem.fromMap(Map<String, dynamic> map) {
    return PurchaseItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      importPrice: (map['importPrice'] ?? 0).toDouble(),
    );
  }

  /// Tạo danh sách PurchaseItem từ JSON string (dùng cho SQLite)
  static List<PurchaseItem> fromJsonList(String jsonString) {
    try {
      // Parse JSON string thành List
      final List<dynamic> itemsList = jsonDecode(jsonString);
      return itemsList
          .map((item) => PurchaseItem.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Chuyển đổi sang Map
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'importPrice': importPrice,
      'subtotal': subtotal,
    };
  }

  /// Copy với các trường được cập nhật
  PurchaseItem copyWith({
    String? productId,
    String? productName,
    double? quantity,
    double? importPrice,
  }) {
    return PurchaseItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      importPrice: importPrice ?? this.importPrice,
    );
  }
}

