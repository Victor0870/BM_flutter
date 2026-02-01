import 'package:flutter/material.dart';
import '../widgets/app_sidebar.dart';
import '../core/routes.dart';
import 'home_screen.dart';
import 'notifications/notification_screen.dart';
import 'sales/sales_screen.dart';
import 'settings/shop_settings_screen.dart';

class _PlaceholderScreen extends StatelessWidget {
  final String title;
  final String message;

  const _PlaceholderScreen({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.construction,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// MainScaffold cho Desktop (Windows/Mac/Linux/Web): Sidebar + IndexedStack, không BottomNav.
class MainScaffoldDesktop extends StatefulWidget {
  const MainScaffoldDesktop({super.key});

  @override
  State<MainScaffoldDesktop> createState() => _MainScaffoldDesktopState();
}

class _MainScaffoldDesktopState extends State<MainScaffoldDesktop> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(forceMobile: false),
    const SalesScreen(forceMobile: false),
    const _PlaceholderScreen(
      title: 'Báo cáo',
      message: 'Tính năng đang phát triển',
    ),
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
    Widget body = IndexedStack(
      index: _currentIndex,
      children: _screens,
    );

    if (_currentIndex != 1) {
      body = Row(
        children: [
          AppSidebar(
            activeRoute: _getCurrentRoute(),
            onMenuTap: _handleSidebarNavigation,
          ),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: null,
      body: body,
      bottomNavigationBar: null,
    );
  }
}
