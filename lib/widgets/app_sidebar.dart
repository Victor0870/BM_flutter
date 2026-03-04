import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/locale_provider.dart';
import '../core/routes.dart';
import '../l10n/app_localizations.dart';
import '../core/permission_routes.dart';
import '../controllers/auth_provider.dart';
import '../controllers/branch_provider.dart';
import '../utils/platform_utils.dart';
import '../widgets/branch_selector_widget.dart';
import 'pro_required_dialog.dart';

/// Sidebar widget dùng chung cho desktop
class AppSidebar extends StatefulWidget {
  final String? activeRoute;
  final Function(String route, {String? routeName})? onMenuTap;

  const AppSidebar({
    super.key,
    this.activeRoute,
    this.onMenuTap,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  bool _isOrdersExpanded = false;
  bool _isProductsExpanded = false;
  bool _isInventoryExpanded = false;
  bool _isSettingsExpanded = false;
  bool _isCustomersExpanded = false;
  bool _isStaffExpanded = false;
  bool _isReportsExpanded = false;

  @override
  void initState() {
    super.initState();
    _updateExpandedStates();
  }

  @override
  void didUpdateWidget(AppSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeRoute != widget.activeRoute) {
      _updateExpandedStates();
    }
  }

  void _updateExpandedStates() {
    final activeRoute = widget.activeRoute ?? '';

    // Reset tất cả, sau đó set đúng 1 nhóm tương ứng route hiện tại
    _isOrdersExpanded = false;
    _isProductsExpanded = false;
    _isInventoryExpanded = false;
    _isSettingsExpanded = false;
    _isCustomersExpanded = false;
    _isStaffExpanded = false;
    _isReportsExpanded = false;

    // Nếu đang ở trang home (dashboard), không highlight menu nào
    if (activeRoute == AppRoutes.home) {
      return;
    }
    
    // Tự động mở menu Orders nếu đang ở route của submenu Orders
    if (activeRoute == AppRoutes.salesHistory ||
        activeRoute == AppRoutes.returnInvoice ||
        activeRoute == AppRoutes.cancelInvoice ||
        activeRoute == AppRoutes.electronicInvoice) {
      _isOrdersExpanded = true;
    }
    
    // Tự động mở menu Products nếu đang ở route của submenu Products
    if (activeRoute == AppRoutes.inventory ||
        activeRoute == AppRoutes.productGroup ||
        activeRoute == AppRoutes.serviceList ||
        activeRoute == AppRoutes.serviceGroup) {
      _isProductsExpanded = true;
    }
    
    // Tự động mở menu Inventory nếu đang ở route của submenu Inventory
    if (activeRoute == AppRoutes.stockOverview ||
        activeRoute == AppRoutes.purchase ||
        activeRoute == AppRoutes.transferStock ||
        activeRoute == AppRoutes.adjustStock) {
      _isInventoryExpanded = true;
    }

    // Tự động mở menu Khách hàng nếu đang ở route tương ứng
    if (activeRoute == AppRoutes.customerManagement ||
        activeRoute == AppRoutes.customerGroupManagement) {
      _isCustomersExpanded = true;
    }

    // Tự động mở menu Nhân viên nếu đang ở route tương ứng
    if (activeRoute == AppRoutes.employeeManagement ||
        activeRoute == AppRoutes.employeeGroupManagement) {
      _isStaffExpanded = true;
    }

    // Tự động mở menu Báo cáo nếu đang ở route tương ứng
    if (activeRoute == AppRoutes.reports ||
        activeRoute == AppRoutes.salesReport ||
        activeRoute == AppRoutes.profitReport ||
        activeRoute == AppRoutes.stockMovementReport ||
        activeRoute == AppRoutes.debtReport ||
        activeRoute == AppRoutes.salesReturnReport) {
      _isReportsExpanded = true;
    }

    // Tự động mở menu Cài đặt nếu đang ở route của submenu Settings
    if (activeRoute == AppRoutes.shopSettings ||
        activeRoute == AppRoutes.branchManagement ||
        activeRoute == AppRoutes.electronicInvoice ||
        activeRoute == AppRoutes.kiotVietLookup ||
        activeRoute == AppRoutes.kiotVietDataGoc ||
        activeRoute == AppRoutes.advancedSettings ||
        activeRoute == AppRoutes.appAccountSettings) {
      _isSettingsExpanded = true;
    }
  }

  void _collapseAllExcept(String menu) {
    _isOrdersExpanded = menu == 'orders' ? _isOrdersExpanded : false;
    _isProductsExpanded = menu == 'products' ? _isProductsExpanded : false;
    _isInventoryExpanded = menu == 'inventory' ? _isInventoryExpanded : false;
    _isSettingsExpanded = menu == 'settings' ? _isSettingsExpanded : false;
    _isCustomersExpanded = menu == 'customers' ? _isCustomersExpanded : false;
    _isStaffExpanded = menu == 'staff' ? _isStaffExpanded : false;
    _isReportsExpanded = menu == 'reports' ? _isReportsExpanded : false;
  }

  void _handleMenuTap(String route, {String? routeName}) {
    if (route == AppRoutes.employeeManagement ||
        route == AppRoutes.employeeGroupManagement) {
      final auth = context.read<AuthProvider>();
      if (!auth.isPro) {
        showProRequiredDialog(context, featureName: 'Quản lý nhân viên');
        return;
      }
    }
    if (widget.onMenuTap != null) {
      widget.onMenuTap!(route, routeName: routeName);
    } else {
      if (route.isEmpty) return;
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: colorScheme.surface,
      child: Container(
        width: 320,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: Column(
          children: [
          // Logo và Branch Selector
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.inventory_2_rounded,
                          color: colorScheme.onPrimary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        AppLocalizations.of(context)!.bizmate,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  // Branch Selector cho desktop
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      if (authProvider.user == null) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          child: const BranchSelectorWidget(
                            isCompact: false,
                            showLabel: true,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          // Menu Items (ẩn theo quyền)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Consumer<AuthProvider>(
                  builder: (context, auth, child) {
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          _buildSidebarItem(
                            context,
                            icon: Icons.dashboard,
                            label: AppLocalizations.of(context)!.overview,
                            isActive: widget.activeRoute == AppRoutes.home,
                            onTap: () => _handleMenuTap(AppRoutes.home),
                          ),
                          const SizedBox(height: 4),
                          _buildOrdersMenu(context, auth),
                          const SizedBox(height: 4),
                          _buildProductsMenu(context, auth),
                          const SizedBox(height: 4),
                          _buildInventoryMenu(context, auth),
                          const SizedBox(height: 4),
                          _buildCustomersMenu(context, auth),
                          const SizedBox(height: 4),
                          _buildStaffMenu(context, auth),
                          const SizedBox(height: 4),
                          _buildReportsMenu(context, auth),
                          const SizedBox(height: 4),
                          _buildSettingsMenu(context, auth),
                          if (isDesktopPlatform && auth.shop?.isKiotVietEnabled == true) ...[
                            const SizedBox(height: 4),
                            _buildTraDuLieuButton(context),
                            const SizedBox(height: 4),
                            _buildBangDuLieuButton(context),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          // Nút Góp ý cố định phía dưới (luôn thấy, không cần cuộn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
              child: _buildFeedbackButton(context),
            ),
          // Language quick switch
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
              child: Consumer<LocaleProvider>(
                builder: (context, localeProvider, _) {
                  final l10n = AppLocalizations.of(context)!;
                  final isVi = localeProvider.locale.languageCode == 'vi';
                  return Material(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    child: PopupMenuButton<Locale>(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      offset: const Offset(0, -80),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onSelected: (locale) => localeProvider.setLocale(locale),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.public_rounded,
                              size: 18,
                              color: colorScheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isVi ? 'VN' : 'EN',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_drop_down_rounded,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: const Locale('vi'),
                          child: Row(
                            children: [
                              Text('🇻🇳', style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 12),
                              Text(l10n.vietnamese),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: const Locale('en'),
                          child: Row(
                            children: [
                              Text('🇬🇧', style: const TextStyle(fontSize: 18)),
                              const SizedBox(width: 12),
                              Text(l10n.english),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nút Tra dữ liệu (màu cam) nằm dưới Cài đặt trong sidebar.
  Widget _buildTraDuLieuButton(BuildContext context) {
    final theme = Theme.of(context);
    final activeRoute = widget.activeRoute ?? '';
    const orange = Colors.orange;
    final isActive = activeRoute == AppRoutes.kiotVietLookup;
    return InkWell(
      onTap: () => _handleMenuTap(AppRoutes.kiotVietLookup),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? orange.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 20,
              color: isActive ? orange : orange,
            ),
            const SizedBox(width: 12),
            Text(
              'Tra dữ liệu',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.orange.shade800 : orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nút Bảng dữ liệu (màu cam) nằm dưới Tra dữ liệu trong sidebar.
  Widget _buildBangDuLieuButton(BuildContext context) {
    final theme = Theme.of(context);
    final activeRoute = widget.activeRoute ?? '';
    const orange = Colors.orange;
    final isActive = activeRoute == AppRoutes.kiotVietDataGoc;
    return InkWell(
      onTap: () => _handleMenuTap(AppRoutes.kiotVietDataGoc),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? orange.withValues(alpha: 0.25) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              Icons.table_chart_rounded,
              size: 20,
              color: isActive ? orange : orange,
            ),
            const SizedBox(width: 12),
            Text(
              'Bảng dữ liệu',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.orange.shade800 : orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Nút Góp ý cho phần mềm ở phía dưới sidebar.
  Widget _buildFeedbackButton(BuildContext context) {
    final activeRoute = widget.activeRoute ?? '';
    final isActive = activeRoute == AppRoutes.feedback;
    return _buildSidebarItem(
      context,
      icon: Icons.feedback_outlined,
      label: 'Góp ý cho phần mềm',
      isActive: isActive,
      onTap: () => _handleMenuTap(AppRoutes.feedback),
    );
  }

  Widget _buildOrdersMenu(BuildContext context, AuthProvider auth) {
    final l10n = AppLocalizations.of(context)!;
    final subItems = [
      (l10n.salesInvoice, AppRoutes.salesHistory),
      (l10n.returnInvoice, AppRoutes.returnInvoice),
      (l10n.cancelInvoice, AppRoutes.cancelInvoice),
      (l10n.eInvoice, AppRoutes.electronicInvoice),
    ];
    final visible = subItems.where((e) {
      final perm = PermissionRoutes.requiredPermissionForRoute(e.$2);
      return perm == null || auth.hasPermission(perm);
    }).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeRoute = widget.activeRoute ?? '';
    final bool isOrdersActive = visible.any((e) => e.$2 == activeRoute);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (!_isOrdersExpanded) {
                _isOrdersExpanded = true;
                _collapseAllExcept('orders');
                _handleMenuTap(visible.first.$2);
              } else {
                _isOrdersExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isOrdersActive ? colorScheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart_rounded,
                  size: 20,
                  color: isOrdersActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.orders,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isOrdersActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  _isOrdersExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: isOrdersActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_isOrdersExpanded) ...[
          const SizedBox(height: 4),
          ...visible.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildSubMenuItem(
              context,
              label: e.$1,
              isActive: activeRoute == e.$2,
              onTap: () => _handleMenuTap(e.$2),
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildSubMenuItem(
    BuildContext context, {
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? colorScheme.primaryContainer.withValues(alpha: 0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsMenu(BuildContext context, AuthProvider auth) {
    final l10n = AppLocalizations.of(context)!;
    final subItems = [
      (l10n.productList, AppRoutes.inventory),
      (l10n.productGroup, AppRoutes.productGroup),
      (l10n.serviceList, AppRoutes.serviceList),
      (l10n.serviceGroup, AppRoutes.serviceGroup),
    ];
    final visible = subItems.where((e) {
      final perm = PermissionRoutes.requiredPermissionForRoute(e.$2);
      return perm == null || auth.hasPermission(perm);
    }).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeRoute = widget.activeRoute ?? '';
    final bool isProductsActive = visible.any((e) => e.$2 == activeRoute);

    return Column(
      children: [
        InkWell(
          onTap: () {
setState(() {
                if (!_isProductsExpanded) {
                _isProductsExpanded = true;
                _collapseAllExcept('products');
                _handleMenuTap(visible.first.$2);
              } else {
                _isProductsExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isProductsActive ? colorScheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2_rounded,
                  size: 20,
                  color: isProductsActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.products,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isProductsActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  _isProductsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: isProductsActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_isProductsExpanded) ...[
          const SizedBox(height: 4),
          ...visible.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildSubMenuItem(
              context,
              label: e.$1,
              isActive: activeRoute == e.$2,
              onTap: () => _handleMenuTap(e.$2),
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildInventoryMenu(BuildContext context, AuthProvider auth) {
    final l10n = AppLocalizations.of(context)!;
    final branchProvider = context.watch<BranchProvider>();
    final branches = branchProvider.branches.where((b) => b.isActive).toList();
    final showTransferStock = auth.isPro && branches.length >= 2;
    final subItems = [
      (l10n.stockOverview, AppRoutes.stockOverview),
      (l10n.purchase, AppRoutes.purchase),
      if (showTransferStock) (l10n.transferStock, AppRoutes.transferStock),
      (l10n.adjustStock, AppRoutes.adjustStock),
    ];
    final visible = subItems.where((e) {
      final perm = PermissionRoutes.requiredPermissionForRoute(e.$2);
      return perm == null || auth.hasPermission(perm);
    }).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeRoute = widget.activeRoute ?? '';
    final bool isInventoryActive = visible.any((e) => e.$2 == activeRoute);
    
    return Column(
      children: [
        InkWell(
            onTap: () {
              setState(() {
                if (!_isInventoryExpanded) {
                  _isInventoryExpanded = true;
                  _collapseAllExcept('inventory');
                  _handleMenuTap(visible.first.$2);
                } else {
                  _isInventoryExpanded = false;
                }
              });
            },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isInventoryActive ? colorScheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warehouse_rounded,
                  size: 20,
                  color: isInventoryActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.inventoryManagement,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isInventoryActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  _isInventoryExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: isInventoryActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_isInventoryExpanded) ...[
          const SizedBox(height: 4),
          ...visible.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildSubMenuItem(
              context,
              label: e.$1,
              isActive: activeRoute == e.$2,
              onTap: () => _handleMenuTap(e.$2),
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildCustomersMenu(BuildContext context, AuthProvider auth) {
    final l10n = AppLocalizations.of(context)!;
    final subItems = [
      (l10n.customerList, AppRoutes.customerManagement),
      (l10n.customerGroup, AppRoutes.customerGroupManagement),
    ];
    final visible = subItems.where((e) {
      final perm = PermissionRoutes.requiredPermissionForRoute(e.$2);
      return perm == null || auth.hasPermission(perm);
    }).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeRoute = widget.activeRoute ?? '';
    final bool isCustomersActive = visible.any((e) => e.$2 == activeRoute);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (!_isCustomersExpanded) {
                _isCustomersExpanded = true;
                _collapseAllExcept('customers');
                _handleMenuTap(visible.first.$2);
              } else {
                _isCustomersExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCustomersActive ? colorScheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people_rounded,
                  size: 20,
                  color: isCustomersActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.customers,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isCustomersActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  _isCustomersExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: isCustomersActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_isCustomersExpanded) ...[
          const SizedBox(height: 4),
          ...visible.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildSubMenuItem(
              context,
              label: e.$1,
              isActive: activeRoute == e.$2,
              onTap: () => _handleMenuTap(e.$2),
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildStaffMenu(BuildContext context, AuthProvider auth) {
    final l10n = AppLocalizations.of(context)!;
    final subItems = [
      (l10n.employeeList, AppRoutes.employeeManagement),
      (l10n.employeeGroup, AppRoutes.employeeGroupManagement),
    ];
    final visible = subItems.where((e) {
      final perm = PermissionRoutes.requiredPermissionForRoute(e.$2);
      return perm == null || auth.hasPermission(perm);
    }).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeRoute = widget.activeRoute ?? '';
    final bool isStaffActive = visible.any((e) => e.$2 == activeRoute);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (!_isStaffExpanded) {
                _isStaffExpanded = true;
                _collapseAllExcept('staff');
                _handleMenuTap(visible.first.$2);
              } else {
                _isStaffExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isStaffActive ? colorScheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.badge_rounded,
                  size: 20,
                  color: isStaffActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.staffManagement,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isStaffActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  _isStaffExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: isStaffActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_isStaffExpanded) ...[
          const SizedBox(height: 4),
          ...visible.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildSubMenuItem(
              context,
              label: e.$1,
              isActive: activeRoute == e.$2,
              onTap: () => _handleMenuTap(e.$2),
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildReportsMenu(BuildContext context, AuthProvider auth) {
    final l10n = AppLocalizations.of(context)!;
    final subItems = [
      (l10n.salesReport, AppRoutes.salesReport),
      (l10n.profitReport, AppRoutes.profitReport),
      (l10n.stockMovementReport, AppRoutes.stockMovementReport),
      (l10n.debtReport, AppRoutes.debtReport),
      (l10n.salesReturnReport, AppRoutes.salesReturnReport),
      (l10n.lowStockReport, AppRoutes.lowStockReport),
      (l10n.expiryReport, AppRoutes.expiryReport),
    ];
    final visible = subItems.where((e) {
      final perm = PermissionRoutes.requiredPermissionForRoute(e.$2);
      return perm == null || auth.hasPermission(perm);
    }).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeRoute = widget.activeRoute ?? '';
    final bool isReportsActive = visible.any((e) => e.$2 == activeRoute);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (!_isReportsExpanded) {
                _isReportsExpanded = true;
                _collapseAllExcept('reports');
                _handleMenuTap(visible.first.$2);
              } else {
                _isReportsExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isReportsActive ? colorScheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bar_chart_rounded,
                  size: 20,
                  color: isReportsActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.reports,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isReportsActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  _isReportsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: isReportsActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_isReportsExpanded) ...[
          const SizedBox(height: 4),
          ...visible.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildSubMenuItem(
              context,
              label: e.$1,
              isActive: activeRoute == e.$2,
              onTap: () => _handleMenuTap(e.$2),
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildSettingsMenu(BuildContext context, AuthProvider auth) {
    final l10n = AppLocalizations.of(context)!;
    final subItems = [
      (l10n.shopInfo, AppRoutes.shopSettings),
      (l10n.branchManagement, AppRoutes.branchManagement),
      (l10n.eInvoice, AppRoutes.electronicInvoice),
      if (isDesktopPlatform && auth.shop?.isKiotVietEnabled == true) ...[
        ('Tra dữ liệu', AppRoutes.kiotVietLookup),
        ('Bảng dữ liệu', AppRoutes.kiotVietDataGoc),
      ],
      (l10n.advancedFeatures, AppRoutes.advancedSettings),
      (l10n.appAccount, AppRoutes.appAccountSettings),
    ];
    final visible = subItems.where((e) {
      final perm = PermissionRoutes.requiredPermissionForRoute(e.$2);
      return perm == null || auth.hasPermission(perm);
    }).toList();
    if (visible.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeRoute = widget.activeRoute ?? '';
    final bool isSettingsActive = visible.any((e) => e.$2 == activeRoute);

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              if (!_isSettingsExpanded) {
                _isSettingsExpanded = true;
                _collapseAllExcept('settings');
                _handleMenuTap(visible.first.$2);
              } else {
                _isSettingsExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSettingsActive ? colorScheme.primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.settings_rounded,
                  size: 20,
                  color: isSettingsActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.settings,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isSettingsActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Icon(
                  _isSettingsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: isSettingsActive ? colorScheme.onPrimaryContainer : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (_isSettingsExpanded) ...[
          const SizedBox(height: 4),
          ...visible.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: _buildSubMenuItem(
              context,
              label: e.$1,
              isActive: activeRoute == e.$2,
              onTap: () => _handleMenuTap(e.$2),
            ),
          )),
        ],
      ],
    );
  }
}
