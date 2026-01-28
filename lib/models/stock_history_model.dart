import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum đại diện cho loại thay đổi tồn kho
enum StockHistoryType {
  purchase,    // Nhập hàng
  sale,        // Bán hàng
  adjustment,  // Điều chỉnh tồn kho
  transfer,    // Chuyển kho
}

/// Extension để thêm các method cho StockHistoryType
extension StockHistoryTypeExtension on StockHistoryType {
  /// Lấy string value để lưu vào database
  String get value {
    switch (this) {
      case StockHistoryType.purchase:
        return 'purchase';
      case StockHistoryType.sale:
        return 'sale';
      case StockHistoryType.adjustment:
        return 'adjustment';
      case StockHistoryType.transfer:
        return 'transfer';
    }
  }

  /// Lấy tên hiển thị tiếng Việt
  String get displayName {
    switch (this) {
      case StockHistoryType.purchase:
        return 'Nhập hàng';
      case StockHistoryType.sale:
        return 'Bán hàng';
      case StockHistoryType.adjustment:
        return 'Điều chỉnh';
      case StockHistoryType.transfer:
        return 'Chuyển kho';
    }
  }
}

/// Helper class cho StockHistoryType
class StockHistoryTypeHelper {
  /// Tạo enum từ string value
  static StockHistoryType fromValue(String value) {
    switch (value) {
      case 'purchase':
        return StockHistoryType.purchase;
      case 'sale':
        return StockHistoryType.sale;
      case 'adjustment':
        return StockHistoryType.adjustment;
      case 'transfer':
        return StockHistoryType.transfer;
      default:
        return StockHistoryType.adjustment;
    }
  }
}

/// Model đại diện cho lịch sử thay đổi tồn kho
class StockHistoryModel {
  final String id;
  final String productId;
  final String branchId;
  final StockHistoryType type;
  final double quantityChange;    // Số lượng thay đổi (dương = tăng, âm = giảm)
  final double beforeQuantity;    // Số lượng trước khi thay đổi
  final double afterQuantity;     // Số lượng sau khi thay đổi
  final String note;              // Ghi chú
  final DateTime timestamp;       // Thời điểm thay đổi

  StockHistoryModel({
    required this.id,
    required this.productId,
    required this.branchId,
    required this.type,
    required this.quantityChange,
    required this.beforeQuantity,
    required this.afterQuantity,
    required this.note,
    required this.timestamp,
  });

  /// Tạo StockHistoryModel từ Firestore document
  factory StockHistoryModel.fromFirestore(Map<String, dynamic> data, String id) {
    return StockHistoryModel(
      id: id,
      productId: data['productId'] as String,
      branchId: data['branchId'] as String,
      type: StockHistoryTypeHelper.fromValue(data['type'] as String? ?? 'adjustment'),
      quantityChange: (data['quantityChange'] as num).toDouble(),
      beforeQuantity: (data['beforeQuantity'] as num).toDouble(),
      afterQuantity: (data['afterQuantity'] as num).toDouble(),
      note: data['note'] as String? ?? '',
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Tạo StockHistoryModel từ JSON
  factory StockHistoryModel.fromJson(Map<String, dynamic> json) {
    return StockHistoryModel(
      id: json['id'] as String,
      productId: json['productId'] as String,
      branchId: json['branchId'] as String,
      type: StockHistoryTypeHelper.fromValue(json['type'] as String? ?? 'adjustment'),
      quantityChange: (json['quantityChange'] as num).toDouble(),
      beforeQuantity: (json['beforeQuantity'] as num).toDouble(),
      afterQuantity: (json['afterQuantity'] as num).toDouble(),
      note: json['note'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Tạo StockHistoryModel từ Map (dùng cho SQLite)
  factory StockHistoryModel.fromMap(Map<String, dynamic> map) {
    return StockHistoryModel(
      id: map['id'] as String,
      productId: map['productId'] as String,
      branchId: map['branchId'] as String,
      type: StockHistoryTypeHelper.fromValue(map['type'] as String? ?? 'adjustment'),
      quantityChange: (map['quantityChange'] as num).toDouble(),
      beforeQuantity: (map['beforeQuantity'] as num).toDouble(),
      afterQuantity: (map['afterQuantity'] as num).toDouble(),
      note: map['note'] as String? ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
    );
  }

  /// Chuyển đổi sang JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'productId': productId,
      'branchId': branchId,
      'type': type.value,
      'quantityChange': quantityChange,
      'beforeQuantity': beforeQuantity,
      'afterQuantity': afterQuantity,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Chuyển đổi sang Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'productId': productId,
      'branchId': branchId,
      'type': type.value,
      'quantityChange': quantityChange,
      'beforeQuantity': beforeQuantity,
      'afterQuantity': afterQuantity,
      'note': note,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// Chuyển đổi sang Map (dùng cho SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'productId': productId,
      'branchId': branchId,
      'type': type.value,
      'quantityChange': quantityChange,
      'beforeQuantity': beforeQuantity,
      'afterQuantity': afterQuantity,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Tạo bản copy với các trường được cập nhật
  StockHistoryModel copyWith({
    String? id,
    String? productId,
    String? branchId,
    StockHistoryType? type,
    double? quantityChange,
    double? beforeQuantity,
    double? afterQuantity,
    String? note,
    DateTime? timestamp,
  }) {
    return StockHistoryModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      branchId: branchId ?? this.branchId,
      type: type ?? this.type,
      quantityChange: quantityChange ?? this.quantityChange,
      beforeQuantity: beforeQuantity ?? this.beforeQuantity,
      afterQuantity: afterQuantity ?? this.afterQuantity,
      note: note ?? this.note,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}
