import 'package:flutter/foundation.dart';
import '../models/sales_return_model.dart';
import '../services/sales_return_service.dart';
import '../services/sales_service.dart';
import 'auth_provider.dart';

/// Provider quản lý báo cáo hàng trả
class SalesReturnProvider with ChangeNotifier {
  final AuthProvider authProvider;
  SalesReturnService? _salesReturnService;
  SalesService? _salesService;

  // State
  bool _isLoading = false;
  String? _errorMessage;
  List<SalesReturnModel> _salesReturns = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  List<SalesReturnModel> get salesReturns => _salesReturns;

  SalesReturnProvider(this.authProvider) {
    authProvider.addListener(_onAuthChanged);
    _initializeServices();
  }

  /// Khởi tạo services dựa trên trạng thái auth
  void _initializeServices() {
    final user = authProvider.user;
    final isPro = authProvider.isPro;

    if (user != null) {
      // SalesReturnService chỉ cần ProductService (optional)
      // CustomerService được truyền vào method saveSalesReturn khi cần
      _salesReturnService = SalesReturnService(
        isPro: isPro,
        userId: user.uid,
        productService: null, // Sẽ được inject từ context khi cần
      );
      _salesService = SalesService(
        isPro: isPro,
        userId: user.uid,
      );
    } else {
      _salesReturnService = null;
      _salesService = null;
      _salesReturns.clear();
    }
    notifyListeners();
  }

  /// Xử lý khi auth state thay đổi
  void _onAuthChanged() {
    _initializeServices();
  }

  /// Tải dữ liệu báo cáo hàng trả
  Future<void> loadSalesReturnReport({
    DateTime? startDate,
    DateTime? endDate,
    String? branchId,
  }) async {
    if (_salesReturnService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final salesReturns = await _salesReturnService!.getSalesReturns(
        startDate: startDate,
        endDate: endDate,
        branchId: branchId,
      );

      _salesReturns = salesReturns;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Lỗi khi tải dữ liệu: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Tính tổng số đơn trả
  int get totalReturnCount => _salesReturns.length;

  /// Tính tổng giá trị hoàn
  double get totalRefundAmount {
    return _salesReturns.fold<double>(
      0.0,
      (sum, salesReturn) => sum + salesReturn.totalRefundAmount,
    );
  }

  /// Thống kê lý do trả hàng
  Map<String, int> get reasonStatistics {
    final stats = <String, int>{};
    for (var salesReturn in _salesReturns) {
      stats[salesReturn.reason] = (stats[salesReturn.reason] ?? 0) + 1;
    }
    return stats;
  }

  /// Lý do phổ biến nhất
  String? get mostCommonReason {
    if (_salesReturns.isEmpty) return null;
    final stats = reasonStatistics;
    if (stats.isEmpty) return null;
    return stats.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// Tính tỷ lệ % hàng trả trên tổng doanh thu
  Future<double> getReturnRatePercentage({
    DateTime? startDate,
    DateTime? endDate,
    String? branchId,
  }) async {
    if (_salesService == null) return 0.0;

    try {
      // Lấy tổng doanh thu bán hàng
      final sales = await _salesService!.getSales(
        startDate: startDate,
        endDate: endDate,
        branchId: branchId,
      );
      final totalRevenue = sales.fold<double>(
        0.0,
        (sum, sale) => sum + sale.totalAmount,
      );

      // Tính tỷ lệ
      if (totalRevenue == 0) return 0.0;
      return (totalRefundAmount / totalRevenue) * 100;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error calculating return rate: $e');
      }
      return 0.0;
    }
  }

  /// Lấy tổng số đơn bán trong khoảng thời gian
  Future<int> getTotalSalesCount({
    DateTime? startDate,
    DateTime? endDate,
    String? branchId,
  }) async {
    if (_salesService == null) return 0;

    try {
      final sales = await _salesService!.getSales(
        startDate: startDate,
        endDate: endDate,
        branchId: branchId,
      );
      return sales.length;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting total sales count: $e');
      }
      return 0;
    }
  }


  @override
  void dispose() {
    authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}
