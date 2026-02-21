import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:intl/intl.dart';
import '../models/notification_model.dart';

/// Service tạo thông báo ghi lên Firestore (đơn hoàn thành, nhập kho, tồn thấp...).
/// [shopId] là ID shop (document id trong collection shops) để NotificationProvider lọc đọc.
class NotificationService {
  NotificationService._();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _logTag = '[NotificationService]';

  /// Tạo một thông báo mới.
  /// [shopId] Bắt buộc — ID shop (owner uid hoặc shop document id).
  static Future<void> create({
    required String shopId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
  }) async {
    if (shopId.isEmpty) return;
    try {
      final ref = _firestore.collection('notifications').doc();
      final model = NotificationModel(
        id: ref.id,
        shopId: shopId,
        title: title,
        body: body,
        type: type,
        isRead: false,
        timestamp: DateTime.now(),
        relatedId: relatedId,
      );
      await ref.set(model.toFirestore());
      if (kDebugMode) {
        debugPrint('$_logTag created: type=$type relatedId=$relatedId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('$_logTag create error: $e');
      }
      rethrow;
    }
  }

  /// Gọi sau khi lưu đơn hàng hoàn thành (paymentStatus = COMPLETED).
  /// [shopId] Thường là userId của SalesService (owner uid = shop doc id).
  static Future<void> notifySaleCompleted({
    required String shopId,
    required String saleId,
    required double totalAmount,
  }) async {
    final body = 'Tổng tiền: ${NumberFormat('#,###', 'vi_VN').format(totalAmount)} ₫';
    await create(
      shopId: shopId,
      title: 'Đơn hàng hoàn thành',
      body: body,
      type: 'new_sale',
      relatedId: saleId,
    );
  }

  /// Gọi sau khi lưu phiếu nhập kho hoàn thành (status = COMPLETED).
  static Future<void> notifyPurchaseCompleted({
    required String shopId,
    required String purchaseId,
    required String supplierName,
    required double totalAmount,
  }) async {
    final body = '$supplierName • ${NumberFormat('#,###', 'vi_VN').format(totalAmount)} ₫';
    await create(
      shopId: shopId,
      title: 'Phiếu nhập kho đã hoàn thành',
      body: body,
      type: 'new_purchase',
      relatedId: purchaseId,
    );
  }

  /// Gọi khi có sản phẩm tồn kho thấp (tạo tối đa 1 thông báo trong 24h để tránh spam).
  static Future<void> notifyLowStockIfNeeded({
    required String shopId,
    required int lowStockCount,
  }) async {
    if (lowStockCount <= 0) return;
    try {
      final since = DateTime.now().subtract(const Duration(hours: 24));
      final snapshot = await _firestore
          .collection('notifications')
          .where('shopId', isEqualTo: shopId)
          .where('type', isEqualTo: 'stock_alert')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
          .limit(1)
          .get();
      if (snapshot.docs.isNotEmpty) return;
      await create(
        shopId: shopId,
        title: 'Cảnh báo tồn kho',
        body: 'Có $lowStockCount sản phẩm sắp hết hàng',
        type: 'stock_alert',
        relatedId: null,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('$_logTag notifyLowStockIfNeeded error: $e');
    }
  }
}
