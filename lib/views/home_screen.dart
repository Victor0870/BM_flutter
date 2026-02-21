import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../../core/route_observer.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../controllers/sales_provider.dart';
import '../../controllers/tutorial_provider.dart';
import '../../services/sales_service.dart';
import '../../services/product_service.dart';
import '../../services/notification_service.dart';
import '../../models/sale_model.dart';
import '../../utils/platform_utils.dart';
import 'home_screen_data.dart';
import 'home_screen_mobile.dart';
import 'home_screen_desktop.dart';

/// HomeScreen: tệp điều phối — chọn giao diện theo platform (Mobile / Desktop).
/// Logic tải dữ liệu và state nằm ở đây; UI nằm ở home_screen_mobile.dart và home_screen_desktop.dart.
class HomeScreen extends StatefulWidget {
  /// Nếu null: dùng [isMobilePlatform]. MainScaffold truyền true (mobile) hoặc false (desktop).
  final bool? forceMobile;

  const HomeScreen({super.key, this.forceMobile});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, RouteAware {
  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;

  double _todayRevenue = 0.0;
  int _todaySalesCount = 0;
  double _todayProfit = 0.0;
  bool _isLoadingStats = true;
  DateTime? _lastRefreshTime;
  bool _hasLoadedOnce = false;
  AuthProvider? _authProvider;
  SalesProvider? _salesProvider;
  int? _lastSeenCheckoutNotifyCount;
  Timer? _refreshDebounceTimer;
  bool _needsRefreshOnNextBuild = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  /// Keys cho tutorial quick actions — mỗi HomeScreen có bộ key riêng để tránh lỗi "Multiple widgets used the same GlobalKey" khi có nhiều instance (vd: IndexedStack + route).
  final GlobalKey keyQuickActionSales = GlobalKey();
  final GlobalKey keyQuickActionProducts = GlobalKey();
  final GlobalKey keyQuickActionStock = GlobalKey();
  final GlobalKey keyQuickActionPurchase = GlobalKey();
  final String _activeTab = 'dashboard';

  final int _totalCustomers = 0;
  double _inventoryValue = 0.0;
  List<SaleModel> _recentSales = [];
  bool _isLoadingRecentSales = false;
  List<Map<String, dynamic>> _bestSellingProducts = [];
  bool _isLoadingBestSellers = false;
  List<double> _weeklyRevenue = [];
  bool _isLoadingWeeklyRevenue = false;
  bool _phase1TourRunning = false;

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
        if (mounted) _checkAndLoadStats();
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
    if (_lastSeenCheckoutNotifyCount != null &&
        current != _lastSeenCheckoutNotifyCount) {
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
        if (mounted) _checkAndLoadStats();
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
    _refreshDebounceTimer?.cancel();
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refreshIfNeeded();
      });
    }
  }

  @override
  void didPush() {
    super.didPush();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshIfNeeded(force: true);
    });
  }

  @override
  void didPopNext() {
    super.didPopNext();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshIfNeeded(force: true);
    });
  }

  void _refreshIfNeeded({bool force = false}) {
    final now = DateTime.now();
    if (force ||
        _lastRefreshTime == null ||
        now.difference(_lastRefreshTime!).inSeconds > 2) {
      if (mounted) _loadDashboardStats(force: force);
    }
  }

  Future<void> _loadDashboardStats({bool force = false}) async {
    if (!mounted) return;
    if (!force && _isLoadingStats) return;

    final authProvider = context.read<AuthProvider>();
    final branchId = context.read<BranchProvider>().currentBranchId;
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);

    if (authProvider.user == null || !authProvider.isFirebaseReady) {
      if (kDebugMode) {
        debugPrint(
            '⏳ Waiting for auth state: user=${authProvider.user != null}, firebaseReady=${authProvider.isFirebaseReady}');
      }
      if (mounted) setState(() => _isLoadingStats = false);
      return;
    }

    if (mounted) setState(() => _isLoadingStats = true);

    try {
      final productService = ProductService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );
      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
        productService: productService,
      );

      if (kDebugMode) debugPrint('📊 Loading dashboard stats...');

      final todayRevenue = await salesService.getTodayRevenue();
      final todaySalesCount = await salesService.getTodaySalesCount();
      final nowForRange = DateTime.now();
      final startOfToday = DateTime(nowForRange.year, nowForRange.month, nowForRange.day);
      final endOfToday = startOfToday.add(const Duration(days: 1));
      final grossProfitResult = await salesService.getGrossProfit(
        startDate: startOfToday,
        endDate: endOfToday,
        branchId: branchId,
      );
      if (!mounted) return;

      final products =
          await productService.getProducts(includeInactive: false);
      double totalInventoryValue = 0.0;
      int lowStockCount = 0;
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
        final minStock = product.minStock ?? 0.0;
        if (minStock > 0 && stock > 0 && stock < minStock) lowStockCount++;
      }
      try {
        final shopId = authProvider.shop?.id ?? authProvider.user!.uid;
        await NotificationService.notifyLowStockIfNeeded(
          shopId: shopId,
          lowStockCount: lowStockCount,
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isLoadingRecentSales = true;
          _isLoadingBestSellers = true;
          _isLoadingWeeklyRevenue = true;
        });
      }

      final allSales = await salesService.getSales();
      allSales.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      final recentSales = allSales.take(5).toList();

      final now = DateTime.now();
      final weeklyRevenueList = <double>[];
      for (int i = 6; i >= 0; i--) {
        final targetDate =
            DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
        final nextDate = targetDate.add(const Duration(days: 1));
        final daySales = allSales.where((sale) {
          return sale.timestamp.isAfter(targetDate.subtract(const Duration(microseconds: 1))) &&
              sale.timestamp.isBefore(nextDate);
        }).toList();
        final dayRevenue =
            daySales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount) /
                1000000;
        weeklyRevenueList.add(dayRevenue);
      }

      final Map<String, Map<String, dynamic>> productStats = {};
      for (final sale in allSales) {
        for (final item in sale.items) {
          final productId = item.productId;
          final productName = item.productName;
          if (productStats.containsKey(productId)) {
            productStats[productId]!['salesCount'] =
                (productStats[productId]!['salesCount'] as int) + 1;
            productStats[productId]!['totalQuantity'] =
                (productStats[productId]!['totalQuantity'] as double) +
                    item.quantity;
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

      final bestSellers = productStats.values.toList()
        ..sort((a, b) => (b['salesCount'] as int).compareTo(a['salesCount'] as int));
      final topProducts = bestSellers.take(5).toList();

      if (kDebugMode) {
        debugPrint('✅ Dashboard stats loaded: Revenue: $todayRevenue, Count: $todaySalesCount');
      }

      if (mounted) {
        setState(() {
          _todayRevenue = todayRevenue;
          _todaySalesCount = todaySalesCount;
          _todayProfit = grossProfitResult.profit;
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
      if (mounted) setState(() => _isLoadingStats = false);
      scaffoldMessenger?.showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải thống kê: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _handleMenuTap(String route, {String? routeName}) {
    Navigator.of(context).pop();
    if (routeName == 'dashboard') return;
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
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              SelectableText(
                email,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w500),
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
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              if (shop != null &&
                  shop.packageType == 'PRO' &&
                  !shop.isLicenseValid) ...[
                const SizedBox(height: 6),
                Text(
                  'Bản quyền đã hết hạn.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.red, fontWeight: FontWeight.w600),
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

  HomeScreenSnapshot get _snapshot => HomeScreenSnapshot(
        todayRevenue: _todayRevenue,
        todaySalesCount: _todaySalesCount,
        todayProfit: _todayProfit,
        isLoadingStats: _isLoadingStats,
        totalCustomers: _totalCustomers,
        inventoryValue: _inventoryValue,
        recentSales: _recentSales,
        bestSellingProducts: _bestSellingProducts,
        weeklyRevenue: _weeklyRevenue,
        isLoadingRecentSales: _isLoadingRecentSales,
        isLoadingBestSellers: _isLoadingBestSellers,
        isLoadingWeeklyRevenue: _isLoadingWeeklyRevenue,
      );

  void _runPhase1TourIfRequested(BuildContext context) {
    if (!_useMobileLayout || _phase1TourRunning) return;
    final tutorialProvider = context.read<TutorialProvider>();
    if (!tutorialProvider.shouldRunPhase1Tour) return;
    _phase1TourRunning = true;
    final settingsKey = TutorialKeys.instance.keyQuickActionSettings;
    final targets = [
      TargetFocus(
        identify: 'sales',
        keyTarget: keyQuickActionSales,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: const Text('Bán hàng: Tạo đơn và thanh toán nhanh.', textAlign: TextAlign.center),
          ),
        ],
        enableTargetTab: true,
      ),
      TargetFocus(
        identify: 'products',
        keyTarget: keyQuickActionProducts,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: const Text('Sản phẩm: Quản lý danh mục hàng.', textAlign: TextAlign.center),
          ),
        ],
        enableTargetTab: true,
      ),
      TargetFocus(
        identify: 'stock',
        keyTarget: keyQuickActionStock,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: const Text('Tồn kho: Xem tổng quan tồn kho.', textAlign: TextAlign.center),
          ),
        ],
        enableTargetTab: true,
      ),
      TargetFocus(
        identify: 'purchase',
        keyTarget: keyQuickActionPurchase,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            child: const Text('Nhập kho: Tạo phiếu nhập hàng.', textAlign: TextAlign.center),
          ),
        ],
        enableTargetTab: true,
      ),
      TargetFocus(
        identify: 'settings',
        keyTarget: settingsKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            child: const Text('Cài đặt: Chạm vào đây để mở Cài đặt và xem menu Hướng dẫn.', textAlign: TextAlign.center),
          ),
        ],
        enableTargetTab: true,
      ),
    ];
    final tutorial = TutorialCoachMark(
      targets: targets,
      onClickTarget: (target) {
        if (target.identify == 'settings') {
          tutorialProvider.setHasCompletedOverviewTour(true);
          tutorialProvider.clearPhase1TourRequest();
          tutorialProvider.requestHighlightGuideInSettings();
          tutorialProvider.navigateToShopSettingsCallback?.call();
        }
      },
      onFinish: () {
        if (mounted) {
          _phase1TourRunning = false;
          tutorialProvider.clearPhase1TourRequest();
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      tutorial.show(context: context);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_needsRefreshOnNextBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _needsRefreshOnNextBuild = false;
          _refreshIfNeeded(force: true);
        }
      });
    }

    final useMobileLayout = _useMobileLayout;
    final useDrawer = useMobileLayout && !isAndroidPlatform;

    if (useMobileLayout) {
      final tutorialProvider = context.watch<TutorialProvider>();
      final needTourKeys = tutorialProvider.shouldRunPhase1Tour && !_phase1TourRunning;
      if (needTourKeys) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _runPhase1TourIfRequested(context);
        });
      }
      return HomeScreenMobile(
        snapshot: _snapshot,
        scaffoldKey: _scaffoldKey,
        keyQuickActionSales: needTourKeys ? keyQuickActionSales : null,
        keyQuickActionProducts: needTourKeys ? keyQuickActionProducts : null,
        keyQuickActionStock: needTourKeys ? keyQuickActionStock : null,
        keyQuickActionPurchase: needTourKeys ? keyQuickActionPurchase : null,
        useDrawer: useDrawer,
        activeTab: _activeTab,
        onShowAccountInfo: _showAccountInfoDialog,
        onMenuTap: _handleMenuTap,
      );
    }
    return HomeScreenDesktop(snapshot: _snapshot);
  }
}
