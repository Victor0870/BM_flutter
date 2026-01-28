import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/ad_banner_widget.dart';
import '../widgets/app_sidebar.dart';
import '../widgets/branch_selector_widget.dart';
import '../controllers/auth_provider.dart';
import '../core/routes.dart';
import 'home_screen.dart';
import 'sales/sales_screen.dart';
import 'settings/shop_settings_screen.dart';

/// MainScaffold với BottomNavigationBar và IndexedStack
/// Quản lý navigation chính của ứng dụng
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;

  // Danh sách các màn hình chính
  final List<Widget> _screens = [
    const HomeScreen(),
    const SalesScreen(),
    // Báo cáo - placeholder
    const _PlaceholderScreen(
      title: 'Báo cáo',
      message: 'Tính năng đang phát triển',
    ),
    // Thông báo - placeholder
    const _PlaceholderScreen(
      title: 'Thông báo',
      message: 'Tính năng đang phát triển',
    ),
    const ShopSettingsScreen(),
  ];

  void _onTabTapped(int index) {
    // Xử lý các tab đặc biệt
    if (index == 2) {
      // Báo cáo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tính năng đang phát triển'),
          duration: Duration(seconds: 2),
        ),
      );
      // Vẫn chuyển tab để hiển thị placeholder screen
      setState(() {
        _currentIndex = index;
      });
      return;
    }
    
    if (index == 3) {
      // Thông báo
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tính năng đang phát triển'),
          duration: Duration(seconds: 2),
        ),
      );
      // Vẫn chuyển tab để hiển thị placeholder screen
      setState(() {
        _currentIndex = index;
      });
      return;
    }

    setState(() {
      _currentIndex = index;
    });
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
    
    // Detect platform
    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    final bool isDesktop = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    
    // Ẩn AppBar khi ở màn hình Bán hàng (index 1) hoặc HomeScreen (index 0) để tránh trùng lặp
    // SalesScreen và HomeScreen đều có AppBar/sidebar riêng
    final bool showAppBar = _currentIndex != 0 && _currentIndex != 1 && !isDesktop;
    
    // Chỉ hiển thị bottom bar trên Android
    // Trên Windows/Desktop sẽ dùng sidebar thay thế
    final bool showBottomBar = isAndroid;
    
    Widget body = IndexedStack(
      index: _currentIndex,
      children: _screens,
    );

    // Wrap với sidebar trên desktop, trừ màn hình Bán hàng (POS) để POS full-screen
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
      bottomNavigationBar: showBottomBar ? Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // AdBannerWidget phía trên BottomNavigationBar
          const AdBannerWidget(),
          // BottomNavigationBar
          BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentIndex.clamp(0, 4), // Đảm bảo index hợp lệ
            onTap: _onTabTapped,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Trang chủ',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.point_of_sale),
                label: 'Bán hàng',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart),
                label: 'Báo cáo',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.notifications),
                label: 'Thông báo',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Cài đặt',
              ),
            ],
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

