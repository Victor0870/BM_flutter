import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/routes.dart';
import '../../l10n/app_localizations.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/notification_provider.dart';
import '../../models/employee_group_model.dart';
import 'notifications/notification_screen.dart';
import '../../widgets/pro_required_dialog.dart';
import 'home_screen_data.dart';
import 'employees/employee_management_hub_screen.dart';

/// Màn hình tổng quan (Dashboard) tối ưu cho điện thoại.
class HomeScreenMobile extends StatelessWidget {
  const HomeScreenMobile({
    super.key,
    required this.snapshot,
    required this.scaffoldKey,
    this.keyQuickActionSales,
    this.keyQuickActionProducts,
    this.keyQuickActionStock,
    this.keyQuickActionPurchase,
    required this.useDrawer,
    required this.activeTab,
    required this.onShowAccountInfo,
    required this.onMenuTap,
  });

  final HomeScreenSnapshot snapshot;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final GlobalKey? keyQuickActionSales;
  final GlobalKey? keyQuickActionProducts;
  final GlobalKey? keyQuickActionStock;
  final GlobalKey? keyQuickActionPurchase;
  final bool useDrawer;
  final String activeTab;
  final void Function(BuildContext context, AuthProvider authProvider) onShowAccountInfo;
  final void Function(String route, {String? routeName}) onMenuTap;

  static const double _contentPadding = 16;
  static const double _sectionSpacing = 20;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    return Scaffold(
      key: scaffoldKey,
      appBar: _buildAppBar(context, authProvider),
      drawer: useDrawer ? _buildDrawer(context) : null,
      body: SingleChildScrollView(
        child: _buildMobileDashboard(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AuthProvider authProvider) {
    return AppBar(
      title: Text(AppLocalizations.of(context)!.dashboard),
      actions: [
        Consumer<NotificationProvider>(
          builder: (context, notificationProvider, _) {
            final unreadCount = notificationProvider.unreadCount;
            return IconButton(
              icon: unreadCount > 0
                  ? Badge(
                      label: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(fontSize: 10),
                      ),
                      child: Icon(Icons.notifications_outlined, color: Colors.grey.shade400),
                    )
                  : Icon(Icons.notifications_outlined, color: Colors.grey.shade400),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationScreen(forceMobile: true),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(width: 4),
        InkWell(
          onTap: () => onShowAccountInfo(context, authProvider),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey.shade200,
              child: Text(
                (authProvider.user?.email?.substring(0, 1).toUpperCase() ?? 'U'),
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    return Drawer(
      child: _buildSidebar(context, authProvider),
    );
  }

  Widget _buildSidebar(BuildContext context, AuthProvider authProvider) {
    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                const Text(
                  'BizMate',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildSidebarItem(
                    context,
                    icon: Icons.dashboard,
                    label: 'Tổng quan',
                    isActive: activeTab == 'dashboard',
                    onTap: () => onMenuTap('', routeName: 'dashboard'),
                  ),
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    context,
                    icon: Icons.shopping_cart,
                    label: 'Đơn hàng',
                    isActive: false,
                    onTap: () => onMenuTap(AppRoutes.salesHistory),
                  ),
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    context,
                    icon: Icons.inventory_2,
                    label: 'Sản phẩm',
                    isActive: false,
                    onTap: () => onMenuTap(AppRoutes.inventory),
                  ),
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    context,
                    icon: Icons.people,
                    label: 'Khách hàng',
                    isActive: false,
                    onTap: () => onMenuTap(AppRoutes.customerManagement),
                  ),
                  if (authProvider.hasPermission(EmployeePermissions.manageEmployees)) ...[
                    const SizedBox(height: 4),
                    _buildSidebarItem(
                      context,
                      icon: Icons.badge_rounded,
                      label: 'Quản lý nhân viên',
                      isActive: false,
                      onTap: () {
                        if (!authProvider.isPro) {
                          showProRequiredDialog(context, featureName: 'Quản lý nhân viên');
                          return;
                        }
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const EmployeeManagementHubScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    context,
                    icon: Icons.bar_chart,
                    label: 'Báo cáo',
                    isActive: false,
                    onTap: () => onMenuTap('', routeName: 'analytics'),
                  ),
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    context,
                    icon: Icons.settings,
                    label: 'Cài đặt',
                    isActive: false,
                    onTap: () => onMenuTap(AppRoutes.shopSettings),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue.shade100),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CẦN HỖ TRỢ?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Liên hệ đội ngũ kỹ thuật ngay.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(AppLocalizations.of(context)!.featureInDev)),
                      );
                    },
                    child: Row(
                      children: [
                        Text(
                          'Gửi yêu cầu',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: Colors.blue.shade700),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileDashboard(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    return Padding(
      padding: const EdgeInsets.all(_contentPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileTopCards(context),
          const SizedBox(height: _sectionSpacing),
          _buildMobileQuickActions(context, authProvider),
        ],
      ),
    );
  }

  Widget _buildMobileTopCards(BuildContext context) {
    final revenueText = snapshot.isLoadingStats
        ? '...'
        : NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(snapshot.todayRevenue);
    final ordersText = snapshot.isLoadingStats ? '...' : snapshot.todaySalesCount.toString();
    const Color cardBackground = Color(0xFF65A30D);
    const Color iconColor = Color(0xFFFFFFFF);
    const Color labelColor = Color(0xE6FFFFFF);
    const Color valueColor = Color(0xFFFFFFFF);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(color: cardBackground),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.trending_up, size: 20, color: iconColor),
                const SizedBox(height: 6),
                const Text(
                  'Doanh thu hôm nay',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    revenueText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: valueColor,
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          VerticalDivider(
            color: iconColor.withValues(alpha: 0.4),
            thickness: 1,
            indent: 10,
            endIndent: 10,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.shopping_cart, size: 20, color: iconColor),
                const SizedBox(height: 6),
                const Text(
                  'Số đơn hàng',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: labelColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    ordersText,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: valueColor,
                    ),
                    maxLines: 1,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileQuickActions(BuildContext context, AuthProvider authProvider) {
    final quickActions = <Widget>[
      _QuickActionButton(
        key: keyQuickActionSales,
        icon: Icons.point_of_sale,
        label: 'Bán hàng',
        color: const Color(0xFFF97316),
        onTap: () => Navigator.pushNamed(context, AppRoutes.sales),
        isPrimary: true,
      ),
      _QuickActionButton(
        key: keyQuickActionStock,
        icon: Icons.warehouse,
        label: 'Quản lý kho',
        color: const Color(0xFF0EA5E9),
        onTap: () => Navigator.pushNamed(context, AppRoutes.stockOverview),
      ),
      _QuickActionButton(
        key: keyQuickActionProducts,
        icon: Icons.inventory_2,
        label: 'Sản phẩm',
        color: Colors.green,
        onTap: () => Navigator.pushNamed(context, AppRoutes.inventory),
      ),
      _QuickActionButton(
        key: keyQuickActionPurchase,
        icon: Icons.add_shopping_cart,
        label: 'Nhập kho',
        color: const Color(0xFF8B5CF6),
        onTap: () => Navigator.pushNamed(context, AppRoutes.purchase),
      ),
      _QuickActionButton(
        icon: Icons.receipt_long,
        label: 'Hóa đơn',
        color: const Color(0xFF059669),
        onTap: () => Navigator.pushNamed(context, AppRoutes.salesHistory),
      ),
      _QuickActionButton(
        icon: Icons.people,
        label: 'Khách hàng',
        color: Colors.blue,
        onTap: () => Navigator.pushNamed(context, AppRoutes.customerManagement),
      ),
      if (authProvider.hasPermission(EmployeePermissions.manageEmployees))
        _QuickActionButton(
          icon: Icons.badge_rounded,
          label: 'Quản lý nhân viên',
          color: const Color(0xFF6366F1),
          onTap: () {
            if (!authProvider.isPro) {
              showProRequiredDialog(context, featureName: 'Quản lý nhân viên');
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const EmployeeManagementHubScreen(),
              ),
          );
        },
      ),
      _QuickActionButton(
        icon: Icons.bar_chart,
        label: 'Báo cáo',
        color: Colors.purple,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tính năng đang phát triển'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        },
      ),
      _QuickActionButton(
        icon: Icons.feedback_outlined,
        label: 'Góp ý',
        color: const Color(0xFF0D9488),
        onTap: () => Navigator.pushNamed(context, AppRoutes.feedback),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thao tác nhanh',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 12),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.05,
          children: quickActions,
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFB923C), Color(0xFFF97316)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF97316).withValues(alpha: 0.28),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
