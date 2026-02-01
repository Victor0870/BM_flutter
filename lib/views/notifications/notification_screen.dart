import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/notification_provider.dart';
import '../../controllers/sales_provider.dart';
import '../../models/notification_model.dart';
import '../../utils/platform_utils.dart';
import '../sales/sale_detail_screen.dart';

/// Màn hình danh sách thông báo (tab Thông báo trong MainScaffold). (mobile/desktop theo platform)
class NotificationScreen extends StatelessWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const NotificationScreen({super.key, this.forceMobile});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, np, _) {
              if (np.unreadCount == 0) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () => np.markAllAsRead(),
                icon: const Icon(Icons.done_all, size: 20),
                label: const Text('Đánh dấu tất cả đã đọc'),
              );
            },
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, np, _) {
          final list = np.notifications;
          if (list.isEmpty) {
            return _EmptyState();
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final n = list[index];
              final useMobile = forceMobile ?? isMobilePlatform;
              return _NotificationTile(
                notification: n,
                onTap: () => _onNotificationTap(context, np, n, useMobile),
              );
            },
          );
        },
      ),
    );
  }

  /// Khi nhấn item: đánh dấu đã đọc và điều hướng nếu có màn hình liên quan.
  void _onNotificationTap(
    BuildContext context,
    NotificationProvider np,
    NotificationModel n,
    bool forceMobile,
  ) async {
    np.markAsRead(n.id);

    if (n.type == 'new_sale' && n.relatedId != null && n.relatedId!.isNotEmpty) {
      final sale = await context.read<SalesProvider>().getSaleById(n.relatedId!);
      if (context.mounted && sale != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SaleDetailScreen(sale: sale, forceMobile: forceMobile),
          ),
        );
      }
    }
  }
}

/// Empty state: hình ảnh minh họa trống khi không có thông báo.
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 96,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có thông báo',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Các thông báo về đơn hàng, cảnh báo kho sẽ hiển thị tại đây.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUnread = !notification.isRead;

    return ListTile(
      onTap: onTap,
      leading: _leadingIcon(theme, isUnread),
      title: Text(
        notification.title,
        style: TextStyle(
          fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
          color: isUnread ? theme.colorScheme.onSurface : Colors.grey[700],
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              notification.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(notification.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
      trailing: isUnread
          ? Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }

  Widget _leadingIcon(ThemeData theme, bool isUnread) {
    final iconData = _iconForType(notification.type);
    return CircleAvatar(
      backgroundColor: isUnread
          ? theme.colorScheme.primaryContainer
          : Colors.grey.shade200,
      child: Icon(
        iconData,
        color: isUnread ? theme.colorScheme.primary : Colors.grey[600],
        size: 22,
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'stock_alert':
        return Icons.warning_amber_rounded;
      case 'new_sale':
        return Icons.shopping_cart_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  /// Format thời gian: "5 phút trước" / "2 giờ trước" hoặc "10:30 20/10".
  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'Vừa xong';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    }
    if (diff.inDays == 1) {
      return 'Hôm qua ${DateFormat.Hm().format(dateTime)}';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    }
    return DateFormat('HH:mm dd/MM').format(dateTime);
  }
}
