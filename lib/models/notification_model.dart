import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho một thông báo trong hệ thống.
/// Đồng bộ cấu trúc giữa App và Firestore.
class NotificationModel {
  final String id;
  final String shopId;
  final String title;
  final String body;
  final String type; // Ví dụ: 'stock_alert', 'new_sale', 'system'
  final bool isRead;
  final DateTime timestamp;
  final String? relatedId; // ID liên kết đến đơn hàng hoặc sản phẩm (optional)

  NotificationModel({
    required this.id,
    required this.shopId,
    required this.title,
    required this.body,
    required this.type,
    this.isRead = false,
    required this.timestamp,
    this.relatedId,
  });

  /// Parse DateTime từ Firestore (Timestamp hoặc chuỗi ISO).
  static DateTime? _parseFirestoreTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Tạo NotificationModel từ Firestore document.
  factory NotificationModel.fromFirestore(Map<String, dynamic> data, String id) {
    final ts = _parseFirestoreTimestamp(data['timestamp']);
    return NotificationModel(
      id: id,
      shopId: data['shopId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      type: data['type'] ?? 'system',
      isRead: data['isRead'] == true,
      timestamp: ts ?? DateTime.now(),
      relatedId: data['relatedId'] as String?,
    );
  }

  /// Chuyển đổi sang Map để lưu lên Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'title': title,
      'body': body,
      'type': type,
      'isRead': isRead,
      'timestamp': Timestamp.fromDate(timestamp),
      if (relatedId != null) 'relatedId': relatedId,
    };
  }

  /// Bản copy với các trường được cập nhật (dùng khi đánh dấu đã đọc).
  NotificationModel copyWith({
    String? id,
    String? shopId,
    String? title,
    String? body,
    String? type,
    bool? isRead,
    DateTime? timestamp,
    String? relatedId,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
      relatedId: relatedId ?? this.relatedId,
    );
  }
}
