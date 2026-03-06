import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/feedback_model.dart';
import 'notification_service.dart';

/// Service góp ý: collection đơn giản — mỗi document: userId, content, isResponded, response.
/// Giới hạn 10 góp ý/ngày theo SharedPreferences (tránh spam, không cần query Firestore).
class FeedbackService {
  FeedbackService._();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _logTag = '[FeedbackService]';

  static const int maxFeedbackPerDay = 10;
  static const String _keyDatePrefix = 'feedback_limit_date_';
  static const String _keyCountPrefix = 'feedback_limit_count_';

  /// Kiểm tra có được gửi thêm góp ý không (tối đa 10/ngày, lưu trong SharedPreferences).
  /// Trả về null nếu được phép; chuỗi lỗi nếu đã đạt giới hạn.
  static Future<String?> canSubmitFeedback(String userId) async {
    if (userId.isEmpty) return 'Vui lòng đăng nhập.';
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayString();
      final dateKey = _keyDatePrefix + userId;
      final countKey = _keyCountPrefix + userId;
      final savedDate = prefs.getString(dateKey);
      final count = prefs.getInt(countKey) ?? 0;
      if (savedDate != today) return null; // ngày mới hoặc chưa gửi lần nào
      if (count >= maxFeedbackPerDay) {
        return 'Bạn đã gửi tối đa $maxFeedbackPerDay góp ý trong ngày. Vui lòng thử lại vào ngày mai.';
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('$_logTag canSubmitFeedback error: $e');
      return null; // lỗi đọc prefs thì vẫn cho gửi
    }
  }

  /// Ghi nhận đã gửi 1 góp ý (gọi sau khi gửi Firestore thành công).
  static Future<void> recordFeedbackSubmitted(String userId) async {
    if (userId.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = _todayString();
      final dateKey = _keyDatePrefix + userId;
      final countKey = _keyCountPrefix + userId;
      final savedDate = prefs.getString(dateKey);
      final count = prefs.getInt(countKey) ?? 0;
      if (savedDate != today) {
        await prefs.setString(dateKey, today);
        await prefs.setInt(countKey, 1);
      } else {
        await prefs.setInt(countKey, count + 1);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('$_logTag recordFeedbackSubmitted error: $e');
    }
  }

  static String _todayString() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  /// Gửi góp ý mới (chỉ cần shopId, userId, content).
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

  /// Stream danh sách góp ý theo shop. Chỉ where shopId, không orderBy để không cần composite index; sort trong app.
  static Stream<QuerySnapshot> streamByShop(String shopId) {
    if (shopId.isEmpty) return const Stream.empty();
    return _firestore
        .collection('feedback')
        .where('shopId', isEqualTo: shopId)
        .limit(200)
        .snapshots();
  }

  /// Stream tất cả góp ý (cho admin). Không orderBy/where phức tạp; sort trong app.
  static Stream<QuerySnapshot> streamForAdmin({bool? isResponded}) {
    if (isResponded != null) {
      return _firestore
          .collection('feedback')
          .where('isResponded', isEqualTo: isResponded)
          .limit(500)
          .snapshots();
    }
    return _firestore.collection('feedback').limit(500).snapshots();
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
