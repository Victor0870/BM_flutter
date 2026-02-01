import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/branch_selector_widget.dart';
import '../controllers/auth_provider.dart';
import '../controllers/notification_provider.dart';
import '../core/routes.dart';
import 'home_screen.dart';
import 'notifications/notification_screen.dart';
import 'sales/sales_screen.dart';
import 'settings/shop_settings_screen.dart';

const String _kMainTabsRoute = '/main-tabs';

class _NestedNavObserver extends NavigatorObserver {
  final VoidCallback onStackChanged;

  _NestedNavObserver({required this.onStackChanged});

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    onStackChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    onStackChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    onStackChanged();
  }
}

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

/// MainScaffold cho Mobile (Android/iOS): BottomNavigationBar + nested Navigator.
class MainScaffoldMobile extends StatefulWidget {
  const MainScaffoldMobile({super.key});

  @override
  State<MainScaffoldMobile> createState() => _MainScaffoldMobileState();
}

class _MainScaffoldMobileState extends State<MainScaffoldMobile> {
  int _currentIndex = 0;

  final GlobalKey<NavigatorState> _nestedNavKey = GlobalKey<NavigatorState>();
  bool _hasPushedRoute = false;

  late final NavigatorObserver _nestedNavObserver;

  @override
  void initState() {
    super.initState();
    _nestedNavObserver = _NestedNavObserver(onStackChanged: _onNestedStackChanged);
  }

  void _onNestedStackChanged() {
    final state = _nestedNavKey.currentState;
    final canPop = state != null && state.canPop();
    if (_hasPushedRoute != canPop) {
      setState(() {
        _hasPushedRoute = canPop;
      });
    }
  }

  final List<Widget> _screens = [
    const HomeScreen(forceMobile: true),
    const SalesScreen(forceMobile: true),
    const _PlaceholderScreen(
      title: 'Báo cáo',
      message: 'Tính năng đang phát triển',
    ),
    const NotificationScreen(forceMobile: true),
    const ShopSettingsScreen(forceMobile: true),
  ];

  void _onTabTapped(int index) {
    if (index == 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tính năng đang phát triển'),
          duration: Duration(seconds: 2),
        ),
      );
      _switchToTab(index);
      return;
    }
    _switchToTab(index);
  }

  void _switchToTab(int index) {
    final nav = _nestedNavKey.currentState;
    if (nav != null && nav.canPop()) {
      nav.popUntil((route) => route.settings.name == _kMainTabsRoute);
    }
    setState(() {
      _currentIndex = index;
    });
  }

  Route<dynamic>? _nestedOnGenerateRoute(RouteSettings settings) {
    if (settings.name == _kMainTabsRoute ||
        settings.name == '/' ||
        settings.name == null ||
        settings.name!.isEmpty) {
      return MaterialPageRoute<void>(
        settings: const RouteSettings(name: _kMainTabsRoute),
        builder: (_) => IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      );
    }
    return AppRoutes.generateRoute(settings);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    bool showAppBar = _currentIndex != 0 && _currentIndex != 1;
    if (_hasPushedRoute) {
      showAppBar = false;
    }

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const Text('BizMate POS'),
              elevation: 0,
              actions: [
                Builder(
                  builder: (context) {
                    if (authProvider.user == null) {
                      return const SizedBox.shrink();
                    }
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: BranchSelectorWidget(),
                    );
                  },
                ),
              ],
            )
          : null,
      body: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final nav = _nestedNavKey.currentState;
          if (nav != null && nav.canPop()) {
            nav.pop();
          }
        },
        child: Navigator(
          key: _nestedNavKey,
          initialRoute: _kMainTabsRoute,
          onGenerateRoute: _nestedOnGenerateRoute,
          observers: [_nestedNavObserver],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex.clamp(0, 4),
        onTap: _onTabTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.point_of_sale),
            label: 'Bán hàng',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Báo cáo',
          ),
          BottomNavigationBarItem(
            icon: Consumer<NotificationProvider>(
              builder: (context, notificationProvider, _) {
                final count = notificationProvider.unreadCount;
                if (count > 0) {
                  return Badge(
                    label: Text(
                      count > 99 ? '99+' : '$count',
                      style: const TextStyle(fontSize: 10),
                    ),
                    child: const Icon(Icons.notifications),
                  );
                }
                return const Icon(Icons.notifications);
              },
            ),
            label: 'Thông báo',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }
}
