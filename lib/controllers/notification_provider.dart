import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import 'auth_provider.dart';

/// Provider quản lý thông báo real-time từ Firestore.
/// Lọc theo shopId của người dùng hiện tại (từ AuthProvider).
class NotificationProvider with ChangeNotifier {
  final AuthProvider _authProvider;
  StreamSubscription<QuerySnapshot>? _subscription;
  bool _disposed = false;

  List<NotificationModel> _notifications = [];

  NotificationProvider(this._authProvider) {
    _authProvider.addListener(_onAuthChanged);
    _startListeningIfReady();
  }

  /// Danh sách thông báo (mới nhất trước).
  List<NotificationModel> get notifications => List.unmodifiable(_notifications);

  /// Số thông báo chưa đọc (isRead == false).
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  String? get _shopId => _authProvider.shop?.id;

  void _onAuthChanged() {
    _startListeningIfReady();
  }

  void _startListeningIfReady() {
    final shopId = _shopId;
    if (shopId == null || shopId.isEmpty) {
      _cancelSubscription();
      _notifications = [];
      _safeNotifyListeners();
      return;
    }
    _startListening(shopId);
  }

  void _startListening(String shopId) {
    _cancelSubscription();

    final stream = FirebaseFirestore.instance
        .collection('notifications')
        .where('shopId', isEqualTo: shopId)
        .snapshots();

    _subscription = stream.listen(
      (snapshot) {
        if (_disposed) return;
        final list = <NotificationModel>[];
        for (final doc in snapshot.docs) {
          final data = doc.data();
          if (data.isEmpty) continue;
          try {
            list.add(NotificationModel.fromFirestore(data, doc.id));
          } catch (e) {
            if (kDebugMode) {
              debugPrint('NotificationProvider parse error ${doc.id}: $e');
            }
          }
        }
        // Sắp xếp mới nhất trước (theo timestamp).
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _notifications = list;
        _safeNotifyListeners();
      },
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('NotificationProvider stream error: $e');
        }
      },
    );
  }

  void _cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  /// Đánh dấu một thông báo là đã đọc trên Firestore.
  Future<void> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      // Stream sẽ cập nhật _notifications, không cần set local
    } catch (e) {
      if (kDebugMode) {
        debugPrint('NotificationProvider markAsRead error: $e');
      }
      rethrow;
    }
  }

  /// Đánh dấu tất cả thông báo của shop là đã đọc trên Firestore.
  Future<void> markAllAsRead() async {
    final shopId = _shopId;
    if (shopId == null || shopId.isEmpty) return;

    final unreadIds =
        _notifications.where((n) => !n.isRead).map((n) => n.id).toList();
    if (unreadIds.isEmpty) return;

    // Firestore batch tối đa 500 thao tác
    const batchSize = 500;
    for (var i = 0; i < unreadIds.length; i += batchSize) {
      final batch = FirebaseFirestore.instance.batch();
      final end = (i + batchSize).clamp(0, unreadIds.length);
      for (var j = i; j < end; j++) {
        final ref = FirebaseFirestore.instance
            .collection('notifications')
            .doc(unreadIds[j]);
        batch.update(ref, {'isRead': true});
      }
      await batch.commit();
    }
    // Stream sẽ cập nhật _notifications
  }

  @override
  void dispose() {
    _disposed = true;
    _authProvider.removeListener(_onAuthChanged);
    _cancelSubscription();
    super.dispose();
  }
}
