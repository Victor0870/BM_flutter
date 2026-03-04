import 'package:cloud_firestore/cloud_firestore.dart';

/// Model cho một góp ý trong collection `feedback` (root).
/// Mỗi document: content (góp ý), response (phản hồi admin), isResponded.
class FeedbackModel {
  final String id;
  final String shopId;
  final String userId;
  final String content;
  final String? response;
  final bool isResponded;
  final DateTime? respondedAt;
  final DateTime createdAt;

  FeedbackModel({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.content,
    this.response,
    this.isResponded = false,
    this.respondedAt,
    required this.createdAt,
  });

  static DateTime? _parseTimestamp(dynamic value) {
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

  static String _safeString(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    return value.toString();
  }

  factory FeedbackModel.fromFirestore(Map<String, dynamic> data, String id) {
    final createdAt = _parseTimestamp(data['createdAt']) ?? DateTime.now();
    final respondedAt = _parseTimestamp(data['respondedAt']);
    return FeedbackModel(
      id: id,
      shopId: _safeString(data['shopId']),
      userId: _safeString(data['userId']),
      content: _safeString(data['content']),
      response: data['response'] != null ? _safeString(data['response']) : null,
      isResponded: data['isResponded'] == true,
      respondedAt: respondedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'shopId': shopId,
      'userId': userId,
      'content': content,
      'response': response,
      'isResponded': isResponded,
      'respondedAt': respondedAt != null ? Timestamp.fromDate(respondedAt!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  FeedbackModel copyWith({
    String? id,
    String? shopId,
    String? userId,
    String? content,
    String? response,
    bool? isResponded,
    DateTime? respondedAt,
    DateTime? createdAt,
  }) {
    return FeedbackModel(
      id: id ?? this.id,
      shopId: shopId ?? this.shopId,
      userId: userId ?? this.userId,
      content: content ?? this.content,
      response: response ?? this.response,
      isResponded: isResponded ?? this.isResponded,
      respondedAt: respondedAt ?? this.respondedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
