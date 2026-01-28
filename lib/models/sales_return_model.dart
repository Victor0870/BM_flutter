import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'sale_model.dart';

/// Model đại diện cho hóa đơn hàng trả (Sales Return)
class SalesReturnModel {
  final String id;
  final String originalSaleId; // ID của hóa đơn bán hàng gốc
  final String? customerId; // ID khách hàng từ đơn gốc
  final String branchId; // Chi nhánh thực hiện trả hàng
  final List<SaleItem> items; // Danh sách các mặt hàng được trả lại
  final double totalRefundAmount; // Tổng số tiền cần hoàn trả cho khách
  final String reason; // Lý do trả hàng
  final String paymentMethod; // Phương thức hoàn tiền: Cash, Bank Transfer, hoặc Debt
  final DateTime timestamp;
  final String userId; // Người thực hiện lệnh trả hàng

  SalesReturnModel({
    required this.id,
    required this.originalSaleId,
    this.customerId,
    required this.branchId,
    required this.items,
    required this.totalRefundAmount,
    required this.reason,
    required this.paymentMethod,
    required this.timestamp,
    required this.userId,
  });

  /// Tạo SalesReturnModel từ Firestore document
  factory SalesReturnModel.fromFirestore(Map<String, dynamic> data, String id) {
    return SalesReturnModel(
      id: id,
      originalSaleId: data['originalSaleId'] ?? '',
      customerId: data['customerId'],
      branchId: data['branchId'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalRefundAmount: (data['totalRefundAmount'] ?? 0).toDouble(),
      reason: data['reason'] ?? '',
      paymentMethod: data['paymentMethod'] ?? 'CASH',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      userId: data['userId'] ?? '',
    );
  }

  /// Tạo SalesReturnModel từ JSON
  factory SalesReturnModel.fromJson(Map<String, dynamic> json) {
    return SalesReturnModel(
      id: json['id'] ?? '',
      originalSaleId: json['originalSaleId'] ?? '',
      customerId: json['customerId'],
      branchId: json['branchId'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      totalRefundAmount: (json['totalRefundAmount'] ?? 0).toDouble(),
      reason: json['reason'] ?? '',
      paymentMethod: json['paymentMethod'] ?? 'CASH',
      timestamp: DateTime.parse(json['timestamp']),
      userId: json['userId'] ?? '',
    );
  }

  /// Tạo SalesReturnModel từ Map (dùng cho SQLite)
  factory SalesReturnModel.fromMap(Map<String, dynamic> map) {
    return SalesReturnModel(
      id: map['id'] as String,
      originalSaleId: map['originalSaleId'] as String,
      customerId: map['customerId'] as String?,
      branchId: map['branchId'] as String,
      items: (map['items'] as String?) != null
          ? (SaleItem.fromJsonList(map['items'] as String))
          : [],
      totalRefundAmount: (map['totalRefundAmount'] as num).toDouble(),
      reason: map['reason'] as String,
      paymentMethod: map['paymentMethod'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      userId: map['userId'] as String,
    );
  }

  /// Chuyển đổi sang JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'originalSaleId': originalSaleId,
      'customerId': customerId,
      'branchId': branchId,
      'items': items.map((item) => item.toMap()).toList(),
      'totalRefundAmount': totalRefundAmount,
      'reason': reason,
      'paymentMethod': paymentMethod,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }

  /// Chuyển đổi sang Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'originalSaleId': originalSaleId,
      'customerId': customerId,
      'branchId': branchId,
      'items': items.map((item) => item.toMap()).toList(),
      'totalRefundAmount': totalRefundAmount,
      'reason': reason,
      'paymentMethod': paymentMethod,
      'timestamp': Timestamp.fromDate(timestamp),
      'userId': userId,
      'createdAt': Timestamp.now(), // Thời điểm tạo hóa đơn trả hàng
    };
  }

  /// Chuyển đổi sang Map (dùng cho SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalSaleId': originalSaleId,
      'customerId': customerId,
      'branchId': branchId,
      'items': jsonEncode(items.map((item) => item.toMap()).toList()), // Lưu dạng JSON string
      'totalRefundAmount': totalRefundAmount,
      'reason': reason,
      'paymentMethod': paymentMethod,
      'timestamp': timestamp.toIso8601String(),
      'userId': userId,
    };
  }

  /// Tạo bản copy với các trường được cập nhật
  SalesReturnModel copyWith({
    String? id,
    String? originalSaleId,
    String? customerId,
    String? branchId,
    List<SaleItem>? items,
    double? totalRefundAmount,
    String? reason,
    String? paymentMethod,
    DateTime? timestamp,
    String? userId,
  }) {
    return SalesReturnModel(
      id: id ?? this.id,
      originalSaleId: originalSaleId ?? this.originalSaleId,
      customerId: customerId ?? this.customerId,
      branchId: branchId ?? this.branchId,
      items: items ?? this.items,
      totalRefundAmount: totalRefundAmount ?? this.totalRefundAmount,
      reason: reason ?? this.reason,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
    );
  }
}
