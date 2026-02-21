import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/tutorial_provider.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/app_navigation_rail.dart';
import '../core/routes.dart';
import 'home_screen.dart';
import 'notifications/notification_screen.dart';
import 'sales/sales_screen.dart';
import 'settings/shop_settings_screen.dart';
import 'reports/reports_hub_screen.dart';

/// MainScaffold cho Desktop/Tablet: Sidebar (≥1200px) hoặc Navigation Rail (600–1200px) + IndexedStack.
class MainScaffoldDesktop extends StatefulWidget {
  /// true = dùng Rail (tablet), false = dùng Sidebar đầy đủ (desktop).
  final bool useRail;

  const MainScaffoldDesktop({super.key, this.useRail = false});

  @override
  State<MainScaffoldDesktop> createState() => _MainScaffoldDesktopState();
}

class _MainScaffoldDesktopState extends State<MainScaffoldDesktop> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(forceMobile: false),
    const SalesScreen(forceMobile: false),
    const ReportsHubScreen(forceMobile: false),
    const NotificationScreen(forceMobile: false),
    const ShopSettingsScreen(forceMobile: false),
  ];

  String _getCurrentRoute() {
    switch (_currentIndex) {
      case 0:
        return AppRoutes.home;
      case 1:
        return AppRoutes.sales;
      case 4:
        return AppRoutes.shopSettings;
      default:
        return '';
    }
  }

  void _handleSidebarNavigation(String route, {String? routeName}) {
    if (route == AppRoutes.home) {
      setState(() => _currentIndex = 0);
    } else if (route == AppRoutes.sales) {
      setState(() => _currentIndex = 1);
    } else if (route == AppRoutes.shopSettings) {
      setState(() => _currentIndex = 4);
    } else {
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tutorialProvider = Provider.of<TutorialProvider>(context, listen: false);
    tutorialProvider.navigateToShopSettingsCallback = () => setState(() => _currentIndex = 4);
    final body = IndexedStack(
      index: _currentIndex,
      children: _screens,
    );

    return Scaffold(
      appBar: null,
      body: Row(
        children: [
          if (widget.useRail)
            AppNavigationRail(
              activeRoute: _getCurrentRoute(),
              onMenuTap: _handleSidebarNavigation,
            )
          else
            AppSidebar(
              activeRoute: _getCurrentRoute(),
              onMenuTap: _handleSidebarNavigation,
            ),
          Expanded(child: body),
        ],
      ),
      bottomNavigationBar: null,
    );
  }
}
