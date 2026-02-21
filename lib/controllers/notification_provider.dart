import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/notification_model.dart';
import 'auth_provider.dart';

/// Provider quản lý thông báo real-time từ Firestore.
/// Lọc theo shopId của người dùng hiện tại (từ AuthProvider).
/// Firestore Stream hoạt động trên mọi nền tảng (mobile, web, desktop) với cloud_firestore 5.x.
class NotificationProvider with ChangeNotifier {
  static const String _logTag = '[NotificationProvider]';

  final AuthProvider _authProvider;
  StreamSubscription<QuerySnapshot>? _subscription;
  bool _disposed = false;
  String? _listeningShopId; // Theo dõi shopId đang listen để tránh listen trùng

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
      if (kDebugMode && _listeningShopId != null) {
        debugPrint('$_logTag shopId rỗng -> dừng listen (trước đó: $_listeningShopId)');
      }
      _cancelSubscription();
      _listeningShopId = null;
      _notifications = [];
      _safeNotifyListeners();
      return;
    }
    // Chỉ start lại nếu shopId thay đổi hoặc chưa từng listen
    if (_listeningShopId == shopId && _subscription != null) return;
    _startListening(shopId);
  }

  void _startListening(String shopId) {
    _cancelSubscription();
    _listeningShopId = shopId;
    if (kDebugMode) {
      debugPrint('$_logTag _startListening shopId=$shopId');
    }

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
              debugPrint('$_logTag parse error doc=${doc.id}: $e');
            }
          }
        }
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _notifications = list;
        if (kDebugMode) {
          debugPrint('$_logTag stream data: ${list.length} notification(s)');
        }
        _safeNotifyListeners();
      },
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('$_logTag stream error: $e');
          debugPrint('$_logTag stackTrace: $st');
        }
      },
      cancelOnError: false,
    );
  }

  void _cancelSubscription() {
    final sub = _subscription;
    _subscription = null;
    _listeningShopId = null;
    sub?.cancel();
    if (kDebugMode && sub != null) {
      debugPrint('$_logTag _cancelSubscription done');
    }
  }

  void _safeNotifyListeners() {
    if (!_disposed) notifyListeners();
  }

  // ---------- Push Notification (Firebase Cloud Messaging) ----------

  /// Yêu cầu quyền thông báo: Android 13+ (POST_NOTIFICATIONS) và iOS.
  /// Gọi sau khi đăng nhập (ví dụ từ màn hình chính hoặc sau khi init app).
  Future<bool> requestPermission() async {
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      if (kDebugMode) {
        debugPrint('$_logTag requestPermission: ${settings.authorizationStatus} -> granted=$granted');
      }
      return granted;
    } catch (e) {
      if (kDebugMode) debugPrint('$_logTag requestPermission error: $e');
      return false;
    }
  }

  /// Khởi tạo xử lý push: foreground (onMessage), mở app từ thông báo (onMessageOpenedApp, getInitialMessage).
  /// Gọi một lần sau khi Firebase đã init (vd. trong main.dart hoặc sau khi auth xong).
  ///
  /// Thông báo khi app ở background/terminated: trong main.dart (trước runApp) cần đăng ký:
  ///   FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  /// với _firebaseMessagingBackgroundHandler là top-level function (static).
  void initPushHandlers({
    void Function(RemoteMessage message)? onForegroundMessage,
    void Function(RemoteMessage message)? onMessageOpenedApp,
    void Function(RemoteMessage message)? onInitialMessage,
  }) {
    // App đang mở: nhận FCM data/notification tại đây
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (_disposed) return;
      if (kDebugMode) {
        debugPrint('$_logTag onMessage: ${message.notification?.title}');
      }
      onForegroundMessage?.call(message);
    });

    // User bấm vào thông báo khi app ở background -> mở app
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (_disposed) return;
      if (kDebugMode) debugPrint('$_logTag onMessageOpenedApp');
      onMessageOpenedApp?.call(message);
    });

    // App mở từ trạng thái terminated bởi thông báo
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && kDebugMode) debugPrint('$_logTag getInitialMessage');
      if (message != null) onInitialMessage?.call(message);
    });
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
    if (_disposed) return;
    _disposed = true;
    _authProvider.removeListener(_onAuthChanged);
    _cancelSubscription();
    _notifications = [];
    super.dispose();
    if (kDebugMode) debugPrint('$_logTag dispose done');
  }
}
