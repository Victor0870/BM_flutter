import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../controllers/notification_provider.dart';
import '../controllers/sales_provider.dart';
import '../core/routes.dart';
import '../models/notification_model.dart';
import '../views/sales/sale_detail_screen.dart';

/// Popup thông báo dưới icon chuông (desktop): tab Tất cả, Bán hàng, Nhập kho, Tồn kho thấp + list.
class NotificationPopup {
  static const double width = 400;
  static const double maxHeight = 520;

  static void show(BuildContext context, Offset anchorOffset, Size anchorSize) {
    const double popupShiftLeft = 10;
    final overlay = Overlay.of(context);
    final top = anchorOffset.dy + anchorSize.height + 8;
    final left = (anchorOffset.dx + anchorSize.width / 2) - (width / 2) - popupShiftLeft;
    final clampedLeft = left.clamp(8.0, double.infinity);
    final useLeft = left >= 8;
    OverlayEntry? entry;
    void remove() {
      entry?.remove();
    }

    entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: remove,
          ),
          Positioned(
            top: top,
            left: useLeft ? clampedLeft : null,
            right: useLeft ? null : 8 + popupShiftLeft,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                onTap: () {},
                child: Container(
                  width: width,
                  height: maxHeight,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: _NotificationPopupContent(
                    onClose: remove,
                    onItemTap: () {
                      remove();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(entry);
  }
}

class _NotificationPopupContent extends StatefulWidget {
  final VoidCallback onClose;
  final VoidCallback onItemTap;

  const _NotificationPopupContent({
    required this.onClose,
    required this.onItemTap,
  });

  @override
  State<_NotificationPopupContent> createState() =>
      _NotificationPopupContentState();
}

class _NotificationPopupContentState extends State<_NotificationPopupContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      // Defer setState to avoid '!_debugDuringDeviceUpdate' assertion (mouse_tracker.dart)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static String? _typeForTab(int index) {
    switch (index) {
      case 0:
        return null;
      case 1:
        return 'new_sale';
      case 2:
        return 'new_purchase';
      case 3:
        return 'stock_alert';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Row(
            children: [
              const Text(
                'Hộp thư đến',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF334155),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(child: Center(child: Text('Tất cả'))),
            Tab(child: Center(child: Text('Bán hàng'))),
            Tab(child: Center(child: Text('Nhập kho'))),
            Tab(child: Center(child: Text('Tồn kho thấp'))),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Consumer<NotificationProvider>(
            builder: (context, np, _) {
              final typeFilter = _typeForTab(_tabController.index);
              final list = typeFilter == null
                  ? np.notifications
                  : np.notifications
                      .where((n) => n.type == typeFilter)
                      .toList();
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Chưa có thông báo',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final n = list[index];
                  return _PopupNotificationTile(
                    notification: n,
                    onTap: () => _onItemTap(context, np, n),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _onItemTap(
    BuildContext context,
    NotificationProvider np,
    NotificationModel n,
  ) async {
    np.markAsRead(n.id);
    final navigator = Navigator.of(context);
    widget.onItemTap();

    if (n.type == 'new_sale' &&
        n.relatedId != null &&
        n.relatedId!.isNotEmpty) {
      final sale = await context.read<SalesProvider>().getSaleById(n.relatedId!);
      if (context.mounted && sale != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (_) =>
                SaleDetailScreen(sale: sale, forceMobile: false),
          ),
        );
      }
      return;
    }

    if (n.type == 'new_purchase' &&
        n.relatedId != null &&
        n.relatedId!.isNotEmpty &&
        context.mounted) {
      navigator.pushNamed(
        AppRoutes.purchaseHistory,
        arguments: {'highlightPurchaseId': n.relatedId},
      );
      return;
    }

    if (n.type == 'stock_alert' && context.mounted) {
      navigator.pushNamed(AppRoutes.lowStockReport);
    }
  }
}

class _PopupNotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;

  const _PopupNotificationTile({
    required this.notification,
    required this.onTap,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'stock_alert':
        return Icons.warning_amber_rounded;
      case 'new_sale':
        return Icons.shopping_cart_rounded;
      case 'new_purchase':
        return Icons.inventory_2_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays == 1) return 'Hôm qua ${DateFormat.Hm().format(dateTime)}';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return DateFormat('HH:mm dd/MM').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isUnread
                      ? theme.colorScheme.primaryContainer
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _iconForType(notification.type),
                  color: isUnread
                      ? theme.colorScheme.primary
                      : Colors.grey[600],
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isUnread ? FontWeight.w600 : FontWeight.w500,
                        color: isUnread
                            ? const Color(0xFF334155)
                            : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _formatTime(notification.timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const Spacer(),
                        if (isUnread)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.blue,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
