import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/branch_selector_widget.dart';
import '../controllers/auth_provider.dart';
import '../controllers/notification_provider.dart';
import '../core/routes.dart';
import 'home_screen.dart';
import 'notifications/notification_screen.dart';
import 'sales/sales_screen.dart';
import 'settings/shop_settings_screen.dart';

/// Route chứa các tab chính (Trang chủ, Bán hàng, ...) dùng cho nested Navigator trên mobile.
const String _kMainTabsRoute = '/main-tabs';

/// Observer theo dõi stack nested Navigator để ẩn AppBar khi đang xem màn con.
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

/// MainScaffold với BottomNavigationBar và IndexedStack
/// Trên mobile: nested Navigator để BottomNav luôn hiện khi đi sâu vào các màn (Quản lý kho, Hóa đơn, ...).
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
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

  // Danh sách các màn hình chính
  final List<Widget> _screens = [
    const HomeScreen(),
    const SalesScreen(),
    // Báo cáo - placeholder
    const _PlaceholderScreen(
      title: 'Báo cáo',
      message: 'Tính năng đang phát triển',
    ),
    const NotificationScreen(),
    const ShopSettingsScreen(),
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
    // index 3 = Thông báo: chuyển sang NotificationScreen (không SnackBar)
    _switchToTab(index);
  }

  /// Chuyển tab: trên mobile pop nested stack về /main-tabs rồi đổi index.
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
    if (settings.name == _kMainTabsRoute || settings.name == '/' || settings.name == null || settings.name!.isEmpty) {
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
    // Map một số route chính sang tab của MainScaffold để giữ state
    if (route == AppRoutes.home) {
      setState(() => _currentIndex = 0);
    } else if (route == AppRoutes.sales) {
      setState(() => _currentIndex = 1);
    } else if (route == AppRoutes.shopSettings) {
      setState(() => _currentIndex = 4);
    } else {
      // Navigate to other screens
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    final bool isIOS = !kIsWeb && Platform.isIOS;
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final bool isMobile = isAndroid || isIOS;

    final bool showBottomBar = isMobile;
    final bool useNestedNavigator = showBottomBar;

    bool showAppBar = _currentIndex != 0 && _currentIndex != 1 && !isDesktop;
    if (useNestedNavigator && _hasPushedRoute) {
      showAppBar = false;
    }

    Widget body;
    if (useNestedNavigator) {
      body = PopScope(
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
      );
    } else {
      body = IndexedStack(
        index: _currentIndex,
        children: _screens,
      );
      if (isDesktop && _currentIndex != 1) {
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
    }

    return Scaffold(
      appBar: showAppBar ? AppBar(
        title: const Text('BizMate POS'),
        elevation: 0, // Đồng bộ elevation với SalesScreen
        actions: [
          // Widget chọn chi nhánh
          Builder(
            builder: (context) {
              // Kiểm tra nếu user đã đăng nhập
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
      ) : null,
      body: body,
      bottomNavigationBar: showBottomBar ? BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex.clamp(0, 4), // Đảm bảo index hợp lệ
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
          ) : null,
    );
  }
}

/// Widget placeholder cho các tính năng chưa phát triển
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

