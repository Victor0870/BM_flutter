import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:provider/provider.dart';
import '../../core/routes.dart';
import '../../core/route_observer.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../controllers/sales_provider.dart';
import '../../services/sales_service.dart';
import '../../services/product_service.dart';
import '../../models/sale_model.dart';
import 'package:intl/intl.dart';
import '../widgets/responsive_container.dart';

/// Padding và spacing theo breakpoint chuẩn (responsive_container)
double _contentPadding(BuildContext c) {
  if (isMobile(c)) return 16;
  if (isTablet(c)) return 20;
  return 32;
}

double _sectionSpacing(BuildContext c) {
  if (isMobile(c)) return 20;
  return 32;
}

/// Màn hình chính — Adaptive Dashboard (thích ứng mobile / tablet / desktop)
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
  SalesProvider? _salesProvider;
  int? _lastSeenCheckoutNotifyCount;
  Timer? _refreshDebounceTimer;
  bool _needsRefreshOnNextBuild = false;
  StreamSubscription<List<SaleModel>>? _salesStreamSubscription;
  bool _salesStreamStarted = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _activeTab = 'dashboard';

  // Dữ liệu giả lập cho stats (sẽ được thay thế bằng dữ liệu thật)
  final int _totalCustomers = 0; // Có thể lấy từ service sau
  double _inventoryValue = 0.0; // Tổng giá trị kho (importPrice × stock), cập nhật trong _loadDashboardStats
  
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

    if (_salesProvider == null) {
      _salesProvider = context.read<SalesProvider>();
      _lastSeenCheckoutNotifyCount = _salesProvider!.checkoutSuccessNotifyCount;
      _salesProvider!.addListener(_onSalesProviderChanged);
    }
  }

  void _onSalesProviderChanged() {
    if (!mounted || _salesProvider == null) return;
    final current = _salesProvider!.checkoutSuccessNotifyCount;
    if (_lastSeenCheckoutNotifyCount != null && current != _lastSeenCheckoutNotifyCount) {
      _needsRefreshOnNextBuild = true;
      _refreshDebounceTimer?.cancel();
      _refreshDebounceTimer = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          _refreshIfNeeded(force: true);
          _needsRefreshOnNextBuild = false;
        }
      });
    }
    _lastSeenCheckoutNotifyCount = current;
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
      _startSalesStreamListener();
    }
  }

  /// Lắng nghe thay đổi sales real-time từ Firestore (PRO/Web).
  /// Khi có đơn hàng mới từ thiết bị khác, tự động refresh dashboard.
  void _startSalesStreamListener() {
    if (_salesStreamStarted || !mounted) return;
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null || !authProvider.isFirebaseReady) return;
    if (!authProvider.isPro && !kIsWeb) return;

    _salesStreamStarted = true;
    final productService = ProductService(
      isPro: authProvider.isPro,
      userId: authProvider.user!.uid,
    );
    final salesService = SalesService(
      isPro: authProvider.isPro,
      userId: authProvider.user!.uid,
      productService: productService,
    );
    final stream = salesService.watchSales();
    if (stream == null) return;

    _salesStreamSubscription = stream.listen(
      (_) {
        if (!mounted) return;
        _loadDashboardStats(force: true);
      },
      onError: (e) {
        if (kDebugMode) debugPrint('HomeScreen sales stream error: $e');
      },
    );
  }

  @override
  void dispose() {
    _refreshDebounceTimer?.cancel();
    _salesStreamSubscription?.cancel();
    _salesProvider?.removeListener(_onSalesProviderChanged);
    _salesProvider = null;
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

      // Giá trị tồn kho thực tế: tổng (importPrice * stock) theo chi nhánh hiện tại hoặc toàn bộ
      if (!mounted) return;
      final branchId = context.read<BranchProvider>().currentBranchId;
      final products = await productService.getProducts(includeInactive: false);
      double totalInventoryValue = 0.0;
      for (final product in products) {
        double stock = 0.0;
        if (branchId != null && branchId.isNotEmpty) {
          if (product.variants.isNotEmpty) {
            for (final variant in product.variants) {
              stock += variant.branchStock[branchId] ?? 0.0;
            }
          } else {
            stock = product.branchStock[branchId] ?? 0.0;
          }
        } else {
          stock = product.stock;
        }
        totalInventoryValue += product.importPrice * stock;
      }
      
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
          _inventoryValue = totalInventoryValue;
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
    Navigator.of(context).pop();
    if (routeName == 'analytics') {
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

  static String _orderIdFrom(String id) {
    final s = id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
    return 'ORD-$s';
  }

  static String _statusText(SaleModel s) {
    return s.paymentStatus == 'COMPLETED' ? 'Hoàn thành' : 'Đang xử lý';
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'Hoàn thành':
        return const Color(0xFF059669);
      case 'Đã hủy':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nếu có đơn hàng mới khi widget đang ẩn (IndexedStack), refresh khi build lại (khi tab Home được chọn)
    if (_needsRefreshOnNextBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _needsRefreshOnNextBuild = false;
          _refreshIfNeeded(force: true);
        }
      });
    }

    final authProvider = context.watch<AuthProvider>();
    final bool isAndroid = !kIsWeb && Platform.isAndroid;
    final bool useDrawer = isMobile(context) &&
        !isAndroid; // Drawer chỉ trên mobile không phải Android (web/iOS)
    final bool useMobileLayout = isMobile(context);

    return Scaffold(
      key: _scaffoldKey,
      appBar: useMobileLayout ? _buildMobileAppBar(context, authProvider) : null,
      drawer: useDrawer ? _buildDrawer(context) : null,
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                if (!useMobileLayout) _buildHeader(context, authProvider),
                Expanded(
                  child: useMobileLayout
                      ? SingleChildScrollView(
                          child: _buildMobileDashboard(context),
                        )
                      : SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.all(
                                _contentPadding(context)),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1400),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildDashboardHeader(context),
                                  SizedBox(
                                      height: _sectionSpacing(context)),
                                  _buildStatsGrid(context),
                                  SizedBox(
                                      height: _sectionSpacing(context)),
                                  _buildChartAndBestSellers(context),
                                  SizedBox(
                                      height: _sectionSpacing(context)),
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

  /// Dashboard tối giản cho Mobile (width < 600px): Top Cards + Quick Actions.
  /// Không hiển thị biểu đồ và bảng giao dịch.
  Widget _buildMobileDashboard(BuildContext context) {
    final pad = _contentPadding(context);

    return Padding(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMobileTopCards(context, horizontalPad: pad),
          SizedBox(height: _sectionSpacing(context)),
          _buildMobileQuickActions(context),
        ],
      ),
    );
  }

  /// Dải thông số tối giản cho Mobile: Doanh thu + Số đơn hàng, nền #65A30D, chữ/icon sáng cho tương phản, tràn full chiều rộng, không bo góc.
  Widget _buildMobileTopCards(BuildContext context, {double horizontalPad = 0}) {
    final revenueText = _isLoadingStats
        ? '...'
        : NumberFormat.currency(
            locale: 'vi_VN',
            symbol: '₫',
          ).format(_todayRevenue);
    final ordersText = _isLoadingStats ? '...' : _todaySalesCount.toString();

    const Color cardBackground = Color(0xFF65A30D);
    const Color iconColor = Color(0xFFFFFFFF);
    const Color labelColor = Color(0xE6FFFFFF);
    const Color valueColor = Color(0xFFFFFFFF);

    return Container(
      margin: EdgeInsets.only(
        left: -horizontalPad,
        right: -horizontalPad,
        bottom: 20,
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: const BoxDecoration(
        color: cardBackground,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.trending_up,
                  size: 20,
                  color: iconColor,
                ),
                const SizedBox(height: 6),
                Text(
                  'Doanh thu hôm nay',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
                Icon(
                  Icons.shopping_cart,
                  size: 20,
                  color: iconColor,
                ),
                const SizedBox(height: 6),
                Text(
                  'Số đơn hàng',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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

  /// Lưới thao tác nhanh Mobile: Bán hàng nổi bật (gradient, icon lớn) + Quản lý kho, Nhập kho, Hóa đơn, ...
  Widget _buildMobileQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Thao tác nhanh',
          style: const TextStyle(
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
          children: [
            _QuickActionButton(
              icon: Icons.point_of_sale,
              label: 'Bán hàng',
              color: const Color(0xFFF97316),
              onTap: () => Navigator.pushNamed(context, AppRoutes.sales),
              isPrimary: true,
            ),
            _QuickActionButton(
              icon: Icons.warehouse,
              label: 'Quản lý kho',
              color: const Color(0xFF0EA5E9),
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.stockOverview),
            ),
            _QuickActionButton(
              icon: Icons.inventory_2,
              label: 'Sản phẩm',
              color: Colors.green,
              onTap: () => Navigator.pushNamed(context, AppRoutes.inventory),
            ),
            _QuickActionButton(
              icon: Icons.add_shopping_cart,
              label: 'Nhập kho',
              color: const Color(0xFF8B5CF6),
              onTap: () => Navigator.pushNamed(context, AppRoutes.purchase),
            ),
            _QuickActionButton(
              icon: Icons.receipt_long,
              label: 'Hóa đơn',
              color: const Color(0xFF059669),
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.salesHistory),
            ),
            _QuickActionButton(
              icon: Icons.people,
              label: 'Khách hàng',
              color: Colors.blue,
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.customerManagement),
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
          ],
        ),
      ],
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

  /// AppBar mobile: tiêu đề "Trang Tổng Quan" cố định khi cuộn, giống ShopSettingsScreen.
  PreferredSizeWidget _buildMobileAppBar(BuildContext context, AuthProvider authProvider) {
    return AppBar(
      title: const Text('Trang Tổng Quan'),
      actions: [
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
        const SizedBox(width: 4),
        InkWell(
          onTap: () => _showAccountInfoDialog(context, authProvider),
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

  /// Dialog "Thông tin tài khoản" trên Mobile: gói dịch vụ, trạng thái bản quyền, nút Đăng xuất đỏ.
  void _showAccountInfoDialog(BuildContext context, AuthProvider authProvider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPro = authProvider.isPro;
    final shop = authProvider.shop;
    final email = authProvider.user?.email ?? '—';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Thông tin tài khoản'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Email đăng nhập',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              SelectableText(
                email,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isPro
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isPro ? 'Gói dịch vụ: PRO' : 'Gói dịch vụ: BASIC',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isPro
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isPro
                    ? 'Đã mở khóa đồng bộ Cloud và tính năng Real-time.'
                    : 'Chế độ Offline-only.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (shop != null &&
                  shop.packageType == 'PRO' &&
                  !shop.isLicenseValid) ...[
                const SizedBox(height: 6),
                Text(
                  'Bản quyền đã hết hạn.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Nếu bạn vừa được gia hạn/nâng cấp gói, hãy đăng xuất rồi đăng nhập lại để áp dụng.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await authProvider.signOut();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Đăng xuất'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider authProvider) {
    final useMobileLayout = isMobile(context);
    final pad = _contentPadding(context);
    final bool useDrawer = !kIsWeb &&
        Platform.isAndroid == false &&
        isMobile(context);

    return Container(
      height: useMobileLayout ? 56 : 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: pad),
      child: Row(
        children: [
          if (useDrawer)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          if (!useMobileLayout)
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
          if (!useMobileLayout) SizedBox(width: pad > 20 ? 16 : 12),
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
          SizedBox(width: useMobileLayout ? 4 : 8),
          InkWell(
            onTap: () async {
              await authProvider.signOut();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!useMobileLayout)
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
                if (!useMobileLayout) const SizedBox(width: 12),
                CircleAvatar(
                  radius: useMobileLayout ? 14 : 16,
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    (authProvider.user?.email?.substring(0, 1).toUpperCase() ?? 'U'),
                    style: TextStyle(
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                      fontSize: useMobileLayout ? 12 : 14,
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
    final useMobileLayout = isMobile(context);

    final titleSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tổng hợp báo cáo và hoạt động kinh doanh hôm nay.',
          style: TextStyle(
            fontSize: useMobileLayout ? 13 : 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );

    final ctaButton = SizedBox(
      width: useMobileLayout ? double.infinity : null,
      child: ElevatedButton(
        onPressed: () => Navigator.pushNamed(context, AppRoutes.sales),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange.shade500,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: useMobileLayout ? 24 : 40,
            vertical: useMobileLayout ? 16 : 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(useMobileLayout ? 12 : 20),
          ),
          elevation: useMobileLayout ? 4 : 8,
        ).copyWith(
          backgroundColor: WidgetStateProperty.resolveWith<Color>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.hovered)) {
                return Colors.orange.shade600;
              }
              return Colors.orange.shade500;
            },
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flash_on, size: useMobileLayout ? 18 : 22),
            SizedBox(width: useMobileLayout ? 6 : 8),
            const Text(
              'BÁN HÀNG NGAY',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );

    if (useMobileLayout) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          titleSection,
          const SizedBox(height: 16),
          ctaButton,
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        titleSection,
        ctaButton,
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final useMobileLayout = isMobile(context);
    final crossAxisCount = useMobileLayout ? 2 : 4;
    final spacing = useMobileLayout ? 12.0 : 16.0;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      childAspectRatio: useMobileLayout ? 2.0 : 2.25,
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
  }

  Widget _buildChartAndBestSellers(BuildContext context) {
    final useRow = isDesktop(context);
    final gap = isMobile(context) ? 16.0 : 24.0;

    if (useRow) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: _buildChartSection(context)),
          SizedBox(width: gap),
          Expanded(child: _buildBestSellers(context)),
        ],
      );
    }
    return Column(
      children: [
        _buildChartSection(context),
        SizedBox(height: gap),
        _buildBestSellers(context),
      ],
    );
  }

  Widget _buildChartSection(BuildContext context) {
    final pad = isMobile(context) ? 16.0 : 24.0;
    final chartHeight = isMobile(context) ? 200.0 : 280.0;

    return Container(
      padding: EdgeInsets.all(pad),
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
          SizedBox(height: pad),
          SizedBox(
            height: chartHeight,
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
                        builder: (ctx) {
                          final maxRevenue = _weeklyRevenue.isEmpty
                              ? 100.0
                              : (_weeklyRevenue.reduce((a, b) => a > b ? a : b) * 1.1).clamp(10.0, double.infinity);
                          final now = DateTime.now();
                          final weekDays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
                          final barMax = chartHeight - 40.0;

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: _weeklyRevenue.asMap().entries.map((entry) {
                              final revenue = entry.value;
                              final index = entry.key;
                              final dayIndex = (now.weekday - 6 + index) % 7;
                              final dayLabel = weekDays[dayIndex < 0 ? dayIndex + 7 : dayIndex];
                              final h = maxRevenue > 0 ? (revenue / maxRevenue) * barMax : 0.0;

                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Tooltip(
                                        message: revenue > 0 ? '${revenue.toStringAsFixed(1)}tr' : '0đ',
                                        child: Container(
                                          height: h.clamp(2.0, barMax),
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

  Widget _buildBestSellers(BuildContext context) {
    final pad = isMobile(context) ? 16.0 : 24.0;

    return Container(
      padding: EdgeInsets.all(pad),
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
          SizedBox(height: pad),
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
                          priceText = '${NumberFormat('#,###').format(price)}đ';
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
    final useMobileLayout = isMobile(context);
    final pad = isMobile(context) ? 16.0 : 24.0;

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
            padding: EdgeInsets.all(pad),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Giao dịch gần đây',
                      style: TextStyle(
                        fontSize: useMobileLayout ? 15 : 16,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0F172A),
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
                if (!useMobileLayout)
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
            padding: EdgeInsets.all(useMobileLayout ? 12 : 8),
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
                    : useMobileLayout
                        ? _buildRecentSalesCardList(context)
                        : _buildRecentSalesTable(context),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSalesCardList(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentSales.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final sale = _recentSales[i];
        final status = _statusText(sale);
        return _recentSaleCard(
          sale: sale,
          orderId: _orderIdFrom(sale.id),
          statusText: status,
          statusColor: _statusColor(status),
          onTap: () => Navigator.pushNamed(
            context,
            AppRoutes.saleDetail,
            arguments: sale,
          ),
        );
      },
    );
  }

  Widget _buildRecentSalesTable(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Consumer<BranchProvider>(
        builder: (context, branchProvider, _) {
          String getBranchName(String? branchId) {
            if (branchId == null || branchId.isEmpty) return '';
            try {
              final b = branchProvider.branches.firstWhere((e) => e.id == branchId);
              return b.name;
            } catch (_) {
              return '';
            }
          }

          return DataTable(
                                  showCheckboxColumn: false,
                                  headingRowColor:
                                      WidgetStateProperty.all(Colors.grey.shade50),
                                  columnSpacing: 16,
                                  columns: [
                                    DataColumn(
                                      label: SizedBox(
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
                                      label: SizedBox(
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
                                      label: SizedBox(
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
                                      label: SizedBox(
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
                                      label: SizedBox(
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
                                      label: SizedBox(
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
                                      label: SizedBox(
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
                                    final status = _statusText(sale);
                                    final statusColor = _statusColor(status);
                                    final orderId = _orderIdFrom(sale.id);
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
                                                color: statusColor.withValues(alpha: 0.08),
                                                borderRadius: BorderRadius.circular(999),
                                                border: Border.all(
                                                  color: statusColor.withValues(alpha: 0.3),
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
  }

  /// Thẻ giao dịch dùng trên mobile (adaptive)
  Widget _recentSaleCard({
    required SaleModel sale,
    required String orderId,
    required String statusText,
    required Color statusColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderId,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sale.customerName ?? 'Khách lẻ',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: '₫',
                    ).format(sale.totalAmount),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Nút chức năng lớn cho Quick Actions (Mobile). [isPrimary] true = nút Bán hàng (gradient, icon lớn).
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

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
                colors: [
                  Color(0xFFFB923C),
                  Color(0xFFF97316),
                ],
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
                  color: color.withValues(alpha: 0.1),
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
