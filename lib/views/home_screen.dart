import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:provider/provider.dart';
import '../../core/routes.dart';
import '../../core/route_observer.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../services/sales_service.dart';
import '../../services/product_service.dart';
import '../../models/sale_model.dart';
import 'package:intl/intl.dart';

/// Màn hình chính của ứng dụng với layout mới
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, RouteAware {
  double _todayRevenue = 0.0;
  int _todaySalesCount = 0;
  bool _isLoadingStats = true;
  DateTime? _lastRefreshTime;
  bool _hasLoadedOnce = false;
  AuthProvider? _authProvider;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _activeTab = 'dashboard';

  // Dữ liệu giả lập cho stats (sẽ được thay thế bằng dữ liệu thật)
  int _totalCustomers = 0; // Có thể lấy từ service sau
  double _inventoryValue = 0.0; // Có thể lấy từ service sau
  
  // Danh sách hóa đơn gần đây
  List<SaleModel> _recentSales = [];
  bool _isLoadingRecentSales = false;
  
  // Danh sách sản phẩm bán chạy
  List<Map<String, dynamic>> _bestSellingProducts = [];
  bool _isLoadingBestSellers = false;
  
  // Dữ liệu doanh thu theo tuần (7 ngày gần nhất)
  List<double> _weeklyRevenue = [];
  bool _isLoadingWeeklyRevenue = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context) as PageRoute);
    
    final authProvider = context.read<AuthProvider>();
    
    if (_authProvider == null) {
      _authProvider = authProvider;
      authProvider.addListener(_onAuthStateChanged);
    }
    
    if (!_hasLoadedOnce) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndLoadStats();
        }
      });
    }
  }
  
  void _onAuthStateChanged() {
    if (!_hasLoadedOnce && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _checkAndLoadStats();
        }
      });
    }
  }
  
  void _checkAndLoadStats() {
    if (_hasLoadedOnce) return;
    
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null && authProvider.isFirebaseReady) {
      _hasLoadedOnce = true;
      _loadDashboardStats(force: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    _authProvider?.removeListener(_onAuthStateChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _refreshIfNeeded();
    }
  }

  @override
  void didPush() {
    super.didPush();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshIfNeeded(force: true);
      }
    });
  }

  @override
  void didPopNext() {
    super.didPopNext();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _refreshIfNeeded(force: true);
      }
    });
  }

  void _refreshIfNeeded({bool force = false}) {
    final now = DateTime.now();
    if (force || 
        _lastRefreshTime == null || 
        now.difference(_lastRefreshTime!).inSeconds > 2) {
      if (mounted) {
        _loadDashboardStats(force: force);
      }
    }
  }

  Future<void> _loadDashboardStats({bool force = false}) async {
    if (!mounted) return;
    
    if (!force && _isLoadingStats) return;

    try {
      final authProvider = context.read<AuthProvider>();
      
      if (authProvider.user == null || !authProvider.isFirebaseReady) {
        if (kDebugMode) {
          debugPrint('⏳ Waiting for auth state: user=${authProvider.user != null}, firebaseReady=${authProvider.isFirebaseReady}');
        }
        setState(() {
          _isLoadingStats = false;
        });
        return;
      }

      setState(() {
        _isLoadingStats = true;
      });

      final productService = ProductService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );
      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
        productService: productService,
      );

      if (kDebugMode) {
        debugPrint('📊 Loading dashboard stats...');
      }

      final todayRevenue = await salesService.getTodayRevenue();
      final todaySalesCount = await salesService.getTodaySalesCount();
      
      // Load danh sách hóa đơn gần đây (5 hóa đơn mới nhất)
      setState(() {
        _isLoadingRecentSales = true;
        _isLoadingBestSellers = true;
        _isLoadingWeeklyRevenue = true;
      });
      
      final allSales = await salesService.getSales();
      // Sắp xếp theo thời gian mới nhất và lấy 5 hóa đơn đầu tiên
      allSales.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final recentSales = allSales.take(5).toList();
      
      // Tính toán doanh thu cho 7 ngày gần nhất
      final now = DateTime.now();
      final weeklyRevenueList = <double>[];
      
      for (int i = 6; i >= 0; i--) {
        final targetDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final nextDate = targetDate.add(const Duration(days: 1));
        
        // Lọc sales trong ngày
        final daySales = allSales.where((sale) {
          return sale.timestamp.isAfter(targetDate.subtract(const Duration(microseconds: 1))) &&
                 sale.timestamp.isBefore(nextDate);
        }).toList();
        
        // Tính tổng doanh thu trong ngày (triệu đồng)
        final dayRevenue = daySales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount) / 1000000;
        weeklyRevenueList.add(dayRevenue);
      }
      
      // Tính toán sản phẩm bán chạy
      final Map<String, Map<String, dynamic>> productStats = {};
      
      for (final sale in allSales) {
        for (final item in sale.items) {
          final productId = item.productId;
          final productName = item.productName;
          
          if (productStats.containsKey(productId)) {
            productStats[productId]!['salesCount'] = (productStats[productId]!['salesCount'] as int) + 1;
            productStats[productId]!['totalQuantity'] = (productStats[productId]!['totalQuantity'] as double) + item.quantity;
            // Cập nhật giá nếu giá mới hơn (hoặc giữ giá cao nhất)
            if (item.price > (productStats[productId]!['price'] as double)) {
              productStats[productId]!['price'] = item.price;
            }
          } else {
            productStats[productId] = {
              'productId': productId,
              'productName': productName,
              'salesCount': 1,
              'totalQuantity': item.quantity,
              'price': item.price,
            };
          }
        }
      }
      
      // Sắp xếp theo số đơn bán (salesCount) giảm dần và lấy top 4
      final bestSellers = productStats.values.toList()
        ..sort((a, b) => (b['salesCount'] as int).compareTo(a['salesCount'] as int));
      final topProducts = bestSellers.take(4).toList();

      if (kDebugMode) {
        debugPrint('✅ Dashboard stats loaded: Revenue: $todayRevenue, Count: $todaySalesCount');
        debugPrint('✅ Recent sales loaded: ${recentSales.length} sales');
        debugPrint('✅ Best sellers loaded: ${topProducts.length} products');
      }

      if (mounted) {
        setState(() {
          _todayRevenue = todayRevenue;
          _todaySalesCount = todaySalesCount;
          _recentSales = recentSales;
          _bestSellingProducts = topProducts;
          _weeklyRevenue = weeklyRevenueList;
          _isLoadingStats = false;
          _isLoadingRecentSales = false;
          _isLoadingBestSellers = false;
          _isLoadingWeeklyRevenue = false;
          _lastRefreshTime = DateTime.now();
        });
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error loading dashboard stats: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tải thống kê: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleMenuTap(String route, {String? routeName}) {
    // Đóng drawer nếu đang mở
    Navigator.of(context).pop();
    
    if (routeName == 'analytics') {
      // Hiển thị thông báo "đang phát triển"
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tính năng đang được phát triển'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    // Detect platform
    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    
    // Trên Android: ẩn sidebar, dùng bottom bar
    // Trên Windows/Desktop: MainScaffold đã có sidebar chung, nên HomeScreen không hiển thị sidebar riêng
    final bool isMobile = MediaQuery.of(context).size.width < 768 || isAndroid;

    return Scaffold(
      key: _scaffoldKey,
      drawer: (isMobile && !isAndroid) ? _buildDrawer(context) : null, // Chỉ drawer trên mobile không phải Android
      body: Row(
        children: [
          // Sidebar không hiển thị ở đây vì MainScaffold đã có sidebar chung cho desktop
          // Main Content
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, authProvider),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDashboardHeader(context),
                            const SizedBox(height: 32),
                            _buildStatsGrid(),
                            const SizedBox(height: 32),
                            _buildChartAndBestSellers(context),
                            const SizedBox(height: 32),
                            _buildRecentTransactions(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
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
          // Logo
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
          // Menu Items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildSidebarItem(
                    context,
                    icon: Icons.dashboard,
                    label: 'Tổng quan',
                    isActive: _activeTab == 'dashboard',
                    onTap: () {
                      setState(() => _activeTab = 'dashboard');
                    },
                  ),
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    context,
                    icon: Icons.shopping_cart,
                    label: 'Đơn hàng',
                    isActive: false,
                    onTap: () => _handleMenuTap(AppRoutes.salesHistory),
                  ),
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    context,
                    icon: Icons.inventory_2,
                    label: 'Sản phẩm',
                    isActive: false,
                    onTap: () => _handleMenuTap(AppRoutes.inventory),
                  ),
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    context,
                    icon: Icons.people,
                    label: 'Khách hàng',
                    isActive: false,
                    onTap: () => _handleMenuTap(AppRoutes.customerManagement),
                  ),
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    context,
                    icon: Icons.bar_chart,
                    label: 'Báo cáo',
                    isActive: false,
                    onTap: () => _handleMenuTap('', routeName: 'analytics'),
                  ),
                  const SizedBox(height: 4),
                  _buildSidebarItem(
                    context,
                    icon: Icons.settings,
                    label: 'Cài đặt',
                    isActive: false,
                    onTap: () => _handleMenuTap(AppRoutes.shopSettings),
                  ),
                ],
              ),
            ),
          ),
          // Support Card
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
                        const SnackBar(content: Text('Tính năng đang được phát triển')),
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

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: _buildSidebar(context),
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

  Widget _buildHeader(BuildContext context, AuthProvider authProvider) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Row(
        children: [
          // Menu button (mobile only)
          if (MediaQuery.of(context).size.width < 768)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          // Search Bar
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 384),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm nhanh...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Notifications
          IconButton(
            icon: Stack(
              children: [
                Icon(Icons.notifications_outlined, color: Colors.grey.shade400),
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade600,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tính năng đang được phát triển')),
              );
            },
          ),
          const SizedBox(width: 8),
          // User Info
          InkWell(
            onTap: () async {
              await authProvider.signOut();
            },
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      authProvider.user?.email?.split('@').first ?? 'User',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const Text(
                      'Chi nhánh',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    (authProvider.user?.email?.substring(0, 1).toUpperCase() ?? 'U'),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Trang Tổng Quan',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tổng hợp báo cáo và hoạt động kinh doanh hôm nay.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        // Nút Bán hàng Nổi bật
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.sales),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade500,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
          ).copyWith(
            backgroundColor: MaterialStateProperty.resolveWith<Color>(
              (Set<MaterialState> states) {
                if (states.contains(MaterialState.hovered)) {
                  return Colors.orange.shade600;
                }
                return Colors.orange.shade500;
              },
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.flash_on, size: 22),
              const SizedBox(width: 8),
              const Text(
                'BÁN HÀNG NGAY',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final crossAxisCount = isMobile ? 2 : 4;
        
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.25,
          children: [
            _StatsCard(
              title: 'Tổng doanh thu',
              value: _isLoadingStats
                  ? '...'
                  : NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(_todayRevenue),
              trend: '+12.5%',
              isUp: true,
              icon: Icons.bar_chart,
              color: Colors.blue,
            ),
            _StatsCard(
              title: 'Đơn hàng mới',
              value: _isLoadingStats ? '...' : _todaySalesCount.toString(),
              trend: '+8.2%',
              isUp: true,
              icon: Icons.shopping_cart,
              color: Colors.purple,
            ),
            _StatsCard(
              title: 'Khách hàng',
              value: _totalCustomers.toString(),
              trend: '-2.4%',
              isUp: false,
              icon: Icons.people,
              color: Colors.orange,
            ),
            _StatsCard(
              title: 'Giá trị tồn kho',
              value: NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(_inventoryValue),
              trend: '+5.4%',
              isUp: true,
              icon: Icons.inventory_2,
              color: Colors.green,
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartAndBestSellers(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 1024;
        
        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _buildChartSection(),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildBestSellers(),
              ),
            ],
          );
        } else {
          return Column(
            children: [
              _buildChartSection(),
              const SizedBox(height: 24),
              _buildBestSellers(),
            ],
          );
        }
      },
    );
  }

  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hiệu suất doanh thu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Tháng',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: const Text(
                        'Tuần',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 280,
            child: _isLoadingWeeklyRevenue
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : _weeklyRevenue.isEmpty
                    ? Center(
                        child: Text(
                          'Chưa có dữ liệu doanh thu',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          // Tính giá trị lớn nhất để scale chart
                          final maxRevenue = _weeklyRevenue.isEmpty
                              ? 100.0
                              : (_weeklyRevenue.reduce((a, b) => a > b ? a : b) * 1.1).clamp(10.0, double.infinity);
                          
                          // Lấy ngày hiện tại để tính thứ trong tuần
                          final now = DateTime.now();
                          final weekDays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
                          
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: _weeklyRevenue.asMap().entries.map((entry) {
                              final revenue = entry.value;
                              final index = entry.key;
                              
                              // Tính thứ trong tuần (0 = CN, 1 = T2, ...)
                              final dayIndex = (now.weekday - 6 + index) % 7;
                              final dayLabel = weekDays[dayIndex < 0 ? dayIndex + 7 : dayIndex];
                              
                              // Tính chiều cao cột (tỷ lệ với maxRevenue)
                              final height = maxRevenue > 0 ? (revenue / maxRevenue) * 240 : 0.0;
                              
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Tooltip(
                                        message: revenue > 0 
                                            ? '${revenue.toStringAsFixed(1)}tr' 
                                            : '0đ',
                                        child: Container(
                                          height: height.clamp(2.0, 240.0),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        dayLabel,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Color(0xFF94A3B8),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildBestSellers() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sản phẩm tiêu biểu',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          _isLoadingBestSellers
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : _bestSellingProducts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Chưa có dữ liệu sản phẩm bán chạy',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    )
                  : Column(
                      children: _bestSellingProducts.map((product) {
                        final productName = product['productName'] as String;
                        final salesCount = product['salesCount'] as int;
                        final price = product['price'] as double;
                        
                        // Format giá
                        String priceText;
                        if (price >= 1000000) {
                          priceText = '${(price / 1000000).toStringAsFixed(1)}tr';
                        } else if (price >= 1000) {
                          priceText = '${(price / 1000).toStringAsFixed(0)}k';
                        } else {
                          priceText = NumberFormat('#,###').format(price) + 'đ';
                        }
                        
                        // Icon mặc định (có thể thay bằng hình ảnh sản phẩm sau)
                        final emoji = '📦';
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFFF1F5F9)),
                                ),
                                child: Center(
                                  child: Text(emoji, style: const TextStyle(fontSize: 20)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$salesCount đơn',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                priceText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Giao dịch gần đây',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hoạt động kinh doanh trong ngày.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Tính năng đang được phát triển')),
                    );
                  },
                  icon: const Icon(Icons.filter_list, size: 14),
                  label: const Text(
                    'Lọc kết quả',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: _isLoadingRecentSales
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(),
                  ))
                : _recentSales.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Chưa có giao dịch nào',
                                style: TextStyle(fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Consumer<BranchProvider>(
                              builder: (context, branchProvider, _) {
                                String getBranchName(String? branchId) {
                                  if (branchId == null || branchId.isEmpty) {
                                    return '';
                                  }
                                  try {
                                    final branch = branchProvider.branches.firstWhere(
                                      (b) => b.id == branchId,
                                    );
                                    return branch.name;
                                  } catch (e) {
                                    return '';
                                  }
                                }

                                String _getOrderId(String id) {
                                  final shortId = id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
                                  return 'ORD-$shortId';
                                }

                                String _getStatusText(SaleModel sale) {
                                  if (sale.paymentStatus == 'COMPLETED') {
                                    return 'Hoàn thành';
                                  } else if (sale.paymentStatus == 'PENDING') {
                                    return 'Đang xử lý';
                                  }
                                  return 'Đang xử lý';
                                }

                                Color _getStatusColor(String status) {
                                  switch (status) {
                                    case 'Hoàn thành':
                                      return const Color(0xFF059669);
                                    case 'Đang xử lý':
                                      return const Color(0xFFF59E0B);
                                    case 'Đã hủy':
                                      return const Color(0xFF64748B);
                                    default:
                                      return const Color(0xFFF59E0B);
                                  }
                                }

                                return DataTable(
                                  showCheckboxColumn: false,
                                  headingRowColor:
                                      MaterialStateProperty.all(Colors.grey.shade50),
                                  columnSpacing: 16,
                                  columns: [
                                    DataColumn(
                                      label: Container(
                                        width: 80,
                                        child: const Text(
                                          'NGÀY BÁN',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                            letterSpacing: 0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Container(
                                        width: 110,
                                        child: const Text(
                                          'MÃ ĐƠN',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                            letterSpacing: 0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Container(
                                        width: 120,
                                        child: const Text(
                                          'KHÁCH HÀNG',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                            letterSpacing: 0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Container(
                                        width: 110,
                                        child: const Text(
                                          'TỔNG CỘNG',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                            letterSpacing: 0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      numeric: true,
                                    ),
                                    DataColumn(
                                      label: Container(
                                        width: 100,
                                        child: const Text(
                                          'NHÂN VIÊN',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                            letterSpacing: 0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Container(
                                        width: 110,
                                        child: const Text(
                                          'CHI NHÁNH',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                            letterSpacing: 0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    DataColumn(
                                      label: Container(
                                        width: 120,
                                        child: const Text(
                                          'TRẠNG THÁI',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF94A3B8),
                                            letterSpacing: 0.5,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                  rows: _recentSales.map((sale) {
                                    final status = _getStatusText(sale);
                                    final statusColor = _getStatusColor(status);
                                    final orderId = _getOrderId(sale.id);
                                    final sellerName = sale.sellerName ?? '';
                                    final branchName = getBranchName(sale.branchId);

                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          SizedBox(
                                            width: 80,
                                            child: Text(
                                              DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF0F172A),
                                              ),
                                              textAlign: TextAlign.left,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              orderId,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF3B82F6),
                                              ),
                                              textAlign: TextAlign.left,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 120,
                                            child: Text(
                                              sale.customerName ?? 'Khách lẻ',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0F172A),
                                              ),
                                              textAlign: TextAlign.left,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              NumberFormat.currency(
                                                locale: 'vi_VN',
                                                symbol: '₫',
                                              ).format(sale.totalAmount),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                              textAlign: TextAlign.left,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 100,
                                            child: Text(
                                              sellerName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF0F172A),
                                              ),
                                              textAlign: TextAlign.left,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 110,
                                            child: Text(
                                              branchName,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF0F172A),
                                              ),
                                              textAlign: TextAlign.left,
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 1,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          SizedBox(
                                            width: 120,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: statusColor.withOpacity(0.3),
                                                ),
                                              ),
                                              child: Text(
                                                status,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: statusColor,
                                                ),
                                                textAlign: TextAlign.left,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                );
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

}

class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final String trend;
  final bool isUp;
  final IconData icon;
  final Color color;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.isUp,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUp ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUp ? Icons.trending_up : Icons.trending_down,
                      size: 12,
                      color: isUp ? Colors.green.shade600 : Colors.red.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      trend,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isUp ? Colors.green.shade600 : Colors.red.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                height: 1.0,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
