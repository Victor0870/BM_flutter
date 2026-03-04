import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/feedback_model.dart';
import 'notification_service.dart';

/// Service góp ý: tạo góp ý, kiểm tra rate limit, admin phản hồi.
/// Collection root: `feedback`.
class FeedbackService {
  FeedbackService._();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _logTag = '[FeedbackService]';

  /// Khoảng thời gian tối thiểu giữa 2 lần gửi (phút).
  static const int minMinutesBetweenSubmissions = 30;
  /// Số góp ý tối đa mỗi tài khoản mỗi ngày.
  static const int maxPerDayPerUser = 10;

  /// Kiểm tra có thể gửi góp ý không (rate limit).
  /// Trả về null nếu được phép; chuỗi lỗi nếu bị chặn.
  static Future<String?> canSubmitFeedback(String userId) async {
    if (userId.isEmpty) return 'Vui lòng đăng nhập.';
    try {
      final now = DateTime.now();
      final startOfToday = DateTime(now.year, now.month, now.day);
      final minTime = now.subtract(const Duration(minutes: minMinutesBetweenSubmissions));

      final recentSnap = await _firestore
          .collection('feedback')
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(maxPerDayPerUser + 1)
          .get();

      if (recentSnap.docs.isEmpty) return null;

      final docs = recentSnap.docs;
      final last = docs.first;
      final lastData = last.data();
      final lastCreated = (lastData['createdAt'] as Timestamp?)?.toDate();
      if (lastCreated != null && lastCreated.isAfter(minTime)) {
        final waitMin = minMinutesBetweenSubmissions - (now.difference(lastCreated).inMinutes);
        return 'Vui lòng chờ $waitMin phút nữa trước khi gửi góp ý tiếp.';
      }

      int countToday = 0;
      for (final d in docs) {
        final createdAt = (d.data()['createdAt'] as Timestamp?)?.toDate();
        if (createdAt != null && !createdAt.isBefore(startOfToday)) countToday++;
      }
      if (countToday >= maxPerDayPerUser) {
        return 'Bạn đã gửi tối đa $maxPerDayPerUser góp ý trong ngày. Vui lòng thử lại vào ngày mai.';
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('$_logTag canSubmitFeedback error: $e');
      return 'Không thể kiểm tra. Vui lòng thử lại.';
    }
  }

  /// Gửi góp ý mới. Gọi sau khi [canSubmitFeedback] trả về null.
  static Future<FeedbackModel?> submitFeedback({
    required String shopId,
    required String userId,
    required String content,
  }) async {
    if (shopId.isEmpty || userId.isEmpty || content.trim().isEmpty) return null;
    try {
      final ref = _firestore.collection('feedback').doc();
      final model = FeedbackModel(
        id: ref.id,
        shopId: shopId,
        userId: userId,
        content: content.trim(),
        createdAt: DateTime.now(),
      );
      await ref.set(model.toFirestore());
      if (kDebugMode) debugPrint('$_logTag submitted: ${ref.id}');
      return model;
    } catch (e) {
      if (kDebugMode) debugPrint('$_logTag submitFeedback error: $e');
      rethrow;
    }
  }

  /// Stream danh sách góp ý theo shop (cho user app).
  static Stream<QuerySnapshot> streamByShop(String shopId) {
    if (shopId.isEmpty) {
      return const Stream.empty();
    }
    return _firestore
        .collection('feedback')
        .where('shopId', isEqualTo: shopId)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  /// Stream tất cả góp ý (cho admin). Có thể lọc isResponded.
  static Stream<QuerySnapshot> streamForAdmin({bool? isResponded}) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('feedback')
        .orderBy('createdAt', descending: true);
    if (isResponded != null) {
      q = q.where('isResponded', isEqualTo: isResponded);
    }
    return q.snapshots();
  }

  /// Stream số góp ý chưa phản hồi (cho badge admin).
  static Stream<int> streamUnrespondedCount() {
    return _firestore
        .collection('feedback')
        .where('isResponded', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  /// Admin phản hồi góp ý và gửi thông báo cho user (shop).
  static Future<void> respondToFeedback({
    required String feedbackId,
    required String responseText,
  }) async {
    if (feedbackId.isEmpty || responseText.trim().isEmpty) return;
    try {
      final ref = _firestore.collection('feedback').doc(feedbackId);
      final doc = await ref.get();
      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!;
      final shopId = data['shopId'] as String? ?? '';
      if (shopId.isEmpty) return;

      final now = DateTime.now();
      await ref.update({
        'response': responseText.trim(),
        'isResponded': true,
        'respondedAt': Timestamp.fromDate(now),
      });

      await NotificationService.create(
        shopId: shopId,
        title: 'Phản hồi góp ý',
        body: 'Góp ý của bạn đã được phản hồi. Nhấn để xem.',
        type: 'feedback_response',
        relatedId: feedbackId,
      );
      if (kDebugMode) debugPrint('$_logTag responded: $feedbackId, notified shopId=$shopId');
    } catch (e) {
      if (kDebugMode) debugPrint('$_logTag respondToFeedback error: $e');
      rethrow;
    }
  }

  /// Lấy một document feedback theo id (cho màn chi tiết).
  static Future<FeedbackModel?> getById(String feedbackId) async {
    if (feedbackId.isEmpty) return null;
    try {
      final doc = await _firestore.collection('feedback').doc(feedbackId).get();
      if (!doc.exists || doc.data() == null) return null;
      return FeedbackModel.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      if (kDebugMode) debugPrint('$_logTag getById error: $e');
      return null;
    }
  }
}
