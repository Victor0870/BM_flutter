import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/locale_provider.dart';
import '../core/routes.dart';
import '../l10n/app_localizations.dart';
import '../controllers/auth_provider.dart';
import '../widgets/branch_selector_widget.dart';
import 'pro_required_dialog.dart';
import 'responsive_container.dart';

/// Navigation Rail cho Tablet (600–1200px): thu gọn, chỉ icon + label.
/// Cùng danh sách đích với [AppSidebar] (Material Design 3).
class AppNavigationRail extends StatelessWidget {
  final String? activeRoute;
  final Function(String route, {String? routeName})? onMenuTap;

  const AppNavigationRail({
    super.key,
    this.activeRoute,
    this.onMenuTap,
  });

  static const List<({String route, IconData icon})> _destinations = [
    (route: AppRoutes.home, icon: Icons.dashboard_rounded),
    (route: AppRoutes.sales, icon: Icons.point_of_sale_rounded),
    (route: AppRoutes.salesHistory, icon: Icons.shopping_cart_rounded),
    (route: AppRoutes.inventory, icon: Icons.inventory_2_rounded),
    (route: AppRoutes.stockOverview, icon: Icons.warehouse_rounded),
    (route: AppRoutes.customerManagement, icon: Icons.people_rounded),
    (route: AppRoutes.employeeManagement, icon: Icons.badge_rounded),
    (route: AppRoutes.salesReport, icon: Icons.bar_chart_rounded),
    (route: AppRoutes.shopSettings, icon: Icons.settings_rounded),
  ];

  String _labelForRoute(BuildContext context, String route) {
    final l10n = AppLocalizations.of(context)!;
    switch (route) {
      case AppRoutes.home: return l10n.home;
      case AppRoutes.sales: return l10n.sales;
      case AppRoutes.salesHistory: return l10n.orders;
      case AppRoutes.inventory: return l10n.products;
      case AppRoutes.stockOverview: return l10n.stockOverview;
      case AppRoutes.customerManagement: return l10n.customers;
      case AppRoutes.employeeManagement: return l10n.employees;
      case AppRoutes.salesReport: return l10n.reports;
      case AppRoutes.shopSettings: return l10n.settings;
      default: return route;
    }
  }

  int _selectedIndex(String? active) {
    if (active == null || active.isEmpty) return 0;
    for (var i = 0; i < _destinations.length; i++) {
      final d = _destinations[i];
      if (active == d.route) return i;
      if (active == AppRoutes.returnInvoice || active == AppRoutes.electronicInvoice) {
        if (d.route == AppRoutes.salesHistory) return i;
      }
      if (active == AppRoutes.productGroup && d.route == AppRoutes.inventory) return i;
      if (active == AppRoutes.branchManagement && d.route == AppRoutes.shopSettings) return i;
      if (active.startsWith('/report') && d.route == AppRoutes.salesReport) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = activeRoute ?? '';
    final selectedIndex = _selectedIndex(active).clamp(0, _destinations.length - 1);

    return Material(
      color: theme.colorScheme.surface,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
        ),
        child: NavigationRail(
          selectedIndex: selectedIndex,
          onDestinationSelected: (index) {
            if (index < 0 || index >= _destinations.length) return;
            final route = _destinations[index].route;
            if (route == AppRoutes.employeeManagement ||
                route == AppRoutes.employeeGroupManagement) {
              final auth = context.read<AuthProvider>();
              if (!auth.isPro) {
                showProRequiredDialog(context, featureName: 'Quản lý nhân viên');
                return;
              }
            }
            onMenuTap?.call(route);
          },
          leading: Padding(
            padding: const EdgeInsets.only(top: kSpacingMd, bottom: kSpacingSm),
            child: Icon(
              Icons.inventory_2_rounded,
              size: 28,
              color: theme.colorScheme.primary,
            ),
          ),
          trailing: Padding(
            padding: const EdgeInsets.only(bottom: kSpacingMd),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Consumer<LocaleProvider>(
                  builder: (context, localeProvider, _) {
                    final l10n = AppLocalizations.of(context)!;
                    final isVi = localeProvider.locale.languageCode == 'vi';
                    return Tooltip(
                      message: l10n.selectLanguage,
                      child: PopupMenuButton<Locale>(
                        padding: EdgeInsets.zero,
                        iconSize: 24,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.public_rounded,
                              size: 22,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isVi ? 'VN' : 'EN',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      onSelected: (locale) => localeProvider.setLocale(locale),
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
                const SizedBox(height: kSpacingSm),
                Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    if (authProvider.user == null) return const SizedBox.shrink();
                    return const BranchSelectorWidget(isCompact: true, showLabel: false);
                  },
                ),
              ],
            ),
          ),
          destinations: _destinations
              .map((d) => NavigationRailDestination(
                    icon: Icon(d.icon, size: 24),
                    label: Text(
                      _labelForRoute(context, d.route),
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
