import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một phiếu chuyển kho
class TransferModel {
  final String id;
  final String fromBranchId; // Chi nhánh gửi
  final String toBranchId; // Chi nhánh nhận
  final List<TransferItem> items;
  final DateTime timestamp;
  final String status; // 'DRAFT', 'COMPLETED', 'CANCELLED'
  final String userId; // ID của shop/user tạo phiếu chuyển kho
  final String? notes;

  TransferModel({
    required this.id,
    required this.fromBranchId,
    required this.toBranchId,
    required this.items,
    required this.timestamp,
    this.status = 'DRAFT',
    required this.userId,
    this.notes,
  });

  /// Tính tổng số lượng item
  int get itemCount => items.length;

  /// Tính tổng giá trị chuyển (nếu có)
  double get totalValue {
    return items.fold(0.0, (total, item) => total + (item.costPrice * item.quantity));
  }

  /// Tạo TransferModel từ Firestore document
  factory TransferModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TransferModel(
      id: id,
      fromBranchId: data['fromBranchId'] ?? '',
      toBranchId: data['toBranchId'] ?? '',
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => TransferItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      status: data['status'] ?? 'DRAFT',
      userId: data['userId'] ?? '',
      notes: data['notes'],
    );
  }

  /// Tạo TransferModel từ JSON
  factory TransferModel.fromJson(Map<String, dynamic> json) {
    return TransferModel(
      id: json['id'] ?? '',
      fromBranchId: json['fromBranchId'] ?? '',
      toBranchId: json['toBranchId'] ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => TransferItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      timestamp: DateTime.parse(json['timestamp']),
      status: json['status'] ?? 'DRAFT',
      userId: json['userId'] ?? '',
      notes: json['notes'],
    );
  }

  /// Tạo TransferModel từ Map (dùng cho SQLite)
  factory TransferModel.fromMap(Map<String, dynamic> map) {
    return TransferModel(
      id: map['id'] as String,
      fromBranchId: map['fromBranchId'] as String,
      toBranchId: map['toBranchId'] as String,
      items: (map['items'] as String?) != null
          ? TransferItem.fromJsonList(map['items'] as String)
          : [],
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: map['status'] as String,
      userId: map['userId'] as String,
      notes: map['notes'] as String?,
    );
  }

  /// Chuyển đổi sang JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromBranchId': fromBranchId,
      'toBranchId': toBranchId,
      'items': items.map((item) => item.toMap()).toList(),
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'userId': userId,
      'notes': notes,
    };
  }

  /// Chuyển đổi sang Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'fromBranchId': fromBranchId,
      'toBranchId': toBranchId,
      'items': items.map((item) => item.toMap()).toList(),
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
      'userId': userId,
      'notes': notes,
    };
  }

  /// Chuyển đổi sang Map (dùng cho SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fromBranchId': fromBranchId,
      'toBranchId': toBranchId,
      'items': items.map((item) => item.toMap()).toList().toString(), // Lưu dạng JSON string
      'timestamp': timestamp.toIso8601String(),
      'status': status,
      'userId': userId,
      'notes': notes,
    };
  }

  /// Tạo bản copy với các trường được cập nhật
  TransferModel copyWith({
    String? id,
    String? fromBranchId,
    String? toBranchId,
    List<TransferItem>? items,
    DateTime? timestamp,
    String? status,
    String? userId,
    String? notes,
  }) {
    return TransferModel(
      id: id ?? this.id,
      fromBranchId: fromBranchId ?? this.fromBranchId,
      toBranchId: toBranchId ?? this.toBranchId,
      items: items ?? this.items,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      userId: userId ?? this.userId,
      notes: notes ?? this.notes,
    );
  }
}

/// Model đại diện cho một item trong phiếu chuyển kho
class TransferItem {
  final String productId;
  final String productName;
  final double quantity;
  final double costPrice; // Giá nhập để tính giá trị

  TransferItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.costPrice,
  });

  /// Tính thành tiền
  double get subtotal => quantity * costPrice;

  /// Tạo TransferItem từ Map
  factory TransferItem.fromMap(Map<String, dynamic> map) {
    return TransferItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      costPrice: (map['costPrice'] ?? 0).toDouble(),
    );
  }

  /// Chuyển đổi sang Map
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'costPrice': costPrice,
    };
  }

  /// Parse từ JSON string (dùng cho SQLite)
  static List<TransferItem> fromJsonList(String jsonString) {
    try {
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      return decoded
          .map((item) => TransferItem.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Tạo bản copy với các trường được cập nhật
  TransferItem copyWith({
    String? productId,
    String? productName,
    double? quantity,
    double? costPrice,
  }) {
    return TransferItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      costPrice: costPrice ?? this.costPrice,
    );
  }
}
