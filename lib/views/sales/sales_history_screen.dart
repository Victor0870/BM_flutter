import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sale_model.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../services/sales_service.dart';
import '../../services/product_service.dart';
import '../../utils/platform_utils.dart';
import 'sales_history_screen_data.dart';
import 'sales_history_screen_mobile.dart';
import 'sales_history_screen_desktop.dart';
import 'sales_history_filter_screen.dart';
import 'sale_detail_screen.dart';

/// Màn hình hiển thị lịch sử đơn hàng đã bán.
/// Tệp điều phối — chọn giao diện Mobile hoặc Desktop theo platform.
class SalesHistoryScreen extends StatelessWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const SalesHistoryScreen({super.key, this.forceMobile});

  @override
  Widget build(BuildContext context) {
    final useMobileLayout = forceMobile ?? isMobilePlatform;
    return Scaffold(
      body: _SalesHistoryContent(useMobileLayout: useMobileLayout),
    );
  }
}

class _SalesHistoryContent extends StatefulWidget {
  final bool useMobileLayout;

  const _SalesHistoryContent({required this.useMobileLayout});

  @override
  State<_SalesHistoryContent> createState() => _SalesHistoryContentState();
}

class _SalesHistoryContentState extends State<_SalesHistoryContent> {
  List<SaleModel> _sales = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _filterCustomerNameController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  DocumentSnapshot? _lastDoc;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  static const int _pageSize = 20;

  SaleModel? _selectedSale;
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;

  SalesHistoryTimeRangeKey _timeRange = SalesHistoryTimeRangeKey.week;
  DateTime? _customStart;
  DateTime? _customEnd;

  String? _filterBranchId;
  String? _filterSellerId;
  String? _filterStatusValue;
  String _filterCustomerName = '';
  String? _filterEinvoiceStatus;
  String? _filterPaymentMethod;

  late Map<String, bool> _visibleColumns;

  @override
  void initState() {
    super.initState();
    _visibleColumns = {
      for (final def in SalesHistoryScreenDesktop.columnDefs)
        def.id: def.id == 'invoiceCode' || def.id == 'time' || def.id == 'paymentMethod' ||
            def.id == 'customer' || def.id == 'totalGoods' || def.id == 'discount' || def.id == 'customerPaid',
    };
    _loadSales();
  }

  void _showColumnPicker() async {
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (ctx) => SalesHistoryColumnPickerDialog(
        visibleColumns: _visibleColumns,
        columnDefs: SalesHistoryScreenDesktop.columnDefs,
      ),
    );
    if (result != null && mounted) setState(() => _visibleColumns = result);
  }

  SalesHistorySnapshot _buildSnapshot() {
    final filteredSales = _getFilteredSales();
    return SalesHistorySnapshot(
      sales: _sales,
      filteredSales: filteredSales,
      isLoading: _isLoading,
      errorMessage: _errorMessage,
      timeRange: _timeRange,
      customStart: _customStart,
      customEnd: _customEnd,
      filterBranchId: _filterBranchId,
      filterSellerId: _filterSellerId,
      filterStatusValue: _filterStatusValue,
      filterCustomerName: _filterCustomerName.isEmpty ? null : _filterCustomerName,
      filterEinvoiceStatus: _filterEinvoiceStatus,
      filterPaymentMethod: _filterPaymentMethod,
      stats: _getOrderStats(),
      hasMore: _hasMore,
      isLoadingMore: _isLoadingMore,
      selectedSale: _selectedSale,
      visibleColumns: _visibleColumns,
      filterDateFrom: _filterDateFrom,
      filterDateTo: _filterDateTo,
      invoiceSummary: _getInvoiceSummary(filteredSales),
      branches: context.watch<BranchProvider>().branches,
      sellers: _getDistinctSellers(),
      getOrderId: _getOrderId,
    );
  }

  ({double totalGoods, double totalDiscount, double totalPaid}) _getInvoiceSummary(List<SaleModel> list) {
    double totalGoods = 0, totalDiscount = 0, totalPaid = 0;
    for (final s in list) {
      totalGoods += s.subTotal ?? s.totalAmount;
      totalDiscount += s.totalDiscountAmount ?? 0;
      totalPaid += s.totalPayment ?? s.totalAmount;
    }
    return (totalGoods: totalGoods, totalDiscount: totalDiscount, totalPaid: totalPaid);
  }

  (DateTime?, DateTime?) _getDateRange() {
    final now = DateTime.now();
    switch (_timeRange) {
      case SalesHistoryTimeRangeKey.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
        return (start, end);
      case SalesHistoryTimeRangeKey.week:
        final start = now.subtract(const Duration(days: 6));
        final startOfStart = DateTime(start.year, start.month, start.day);
        final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
        return (startOfStart, end);
      case SalesHistoryTimeRangeKey.month:
        final start = now.subtract(const Duration(days: 29));
        final startOfStart = DateTime(start.year, start.month, start.day);
        final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
        return (startOfStart, end);
      case SalesHistoryTimeRangeKey.all:
        return (null, null);
      case SalesHistoryTimeRangeKey.custom:
        if (_customStart == null || _customEnd == null) return (null, null);
        final endOfDay = DateTime(_customEnd!.year, _customEnd!.month, _customEnd!.day).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
        return (_customStart, endOfDay);
    }
  }

  Future<void> _pickCustomDateRange() async {
    if (!mounted) return;
    final now = DateTime.now();
    try {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 2),
        lastDate: now,
        initialDateRange: _customStart != null && _customEnd != null
            ? DateTimeRange(start: _customStart!, end: _customEnd!)
            : DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
        helpText: 'Chọn khoảng thời gian',
      );
      if (picked != null && mounted) {
        setState(() {
          _timeRange = SalesHistoryTimeRangeKey.custom;
          _customStart = DateTime(picked.start.year, picked.start.month, picked.start.day);
          _customEnd = DateTime(picked.end.year, picked.end.month, picked.end.day);
        });
        _loadSales();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi chọn khoảng thời gian: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 4)),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterCustomerNameController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _searchQuery = value);
    });
  }

  List<SaleModel> _getFilteredSales() {
    return _sales.where((sale) {
      if (_searchQuery.trim().isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final orderId = _getOrderId(sale.id).toLowerCase();
        final customerName = (sale.customerName ?? 'Khách lẻ').toLowerCase();
        if (!orderId.contains(query) && !customerName.contains(query)) return false;
      }
      if (_filterCustomerName.trim().isNotEmpty) {
        final name = (sale.customerName ?? 'Khách lẻ').toLowerCase();
        if (!name.contains(_filterCustomerName.trim().toLowerCase())) return false;
      }
      if (_filterEinvoiceStatus != null) {
        final issued = sale.invoiceNo != null && sale.invoiceNo!.isNotEmpty &&
            sale.einvoiceUrl != null && sale.einvoiceUrl!.isNotEmpty;
        if (_filterEinvoiceStatus == 'issued' && !issued) return false;
        if (_filterEinvoiceStatus == 'not_issued' && issued) return false;
      }
      if (_filterPaymentMethod != null) {
        final pm = sale.paymentMethod.toUpperCase();
        if (pm != _filterPaymentMethod) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _sales = [];
      _lastDoc = null;
      _hasMore = true;
    });
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user == null) {
        setState(() {
          _errorMessage = 'Chưa đăng nhập';
          _isLoading = false;
        });
        return;
      }
      final productService = ProductService(isPro: authProvider.isPro, userId: authProvider.user!.uid);
      final salesService = SalesService(isPro: authProvider.isPro, userId: authProvider.user!.uid, productService: productService);
      final (startDate, endDate) = _getDateRange();
      final branchId = _filterBranchId ?? context.read<BranchProvider>().currentBranchId;
      final result = await salesService.getSalesPaginated(
        limit: _pageSize,
        startAfterDocument: null,
        startDate: startDate,
        endDate: endDate,
        branchId: branchId,
        sellerId: _filterSellerId,
        statusValue: _filterStatusValue,
      );
      if (!mounted) return;
      setState(() {
        _sales = result.sales;
        _lastDoc = result.lastDoc;
        _hasMore = result.lastDoc != null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Lỗi khi tải lịch sử: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreSales() async {
    if (_isLoadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user == null) return;
      final productService = ProductService(isPro: authProvider.isPro, userId: authProvider.user!.uid);
      final salesService = SalesService(isPro: authProvider.isPro, userId: authProvider.user!.uid, productService: productService);
      final (startDate, endDate) = _getDateRange();
      final branchId = _filterBranchId ?? context.read<BranchProvider>().currentBranchId;
      final result = await salesService.getSalesPaginated(
        limit: _pageSize,
        startAfterDocument: _lastDoc,
        startDate: startDate,
        endDate: endDate,
        branchId: branchId,
        sellerId: _filterSellerId,
        statusValue: _filterStatusValue,
      );
      if (!mounted) return;
      setState(() {
        _sales = [..._sales, ...result.sales];
        _lastDoc = result.lastDoc;
        _hasMore = result.lastDoc != null;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  String _getOrderId(String id) {
    final shortId = id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
    return 'ORD-$shortId';
  }

  Map<String, int> _getOrderStats() {
    int pending = 0, completed = 0, cancelled = 0, delivering = 0;
    for (final sale in _sales) {
      final status = sale.statusValue ?? (sale.paymentStatus == 'COMPLETED' ? kOrderStatusDelivered : kOrderStatusProcessing);
      if (status == kOrderStatusDelivered || sale.paymentStatus == 'COMPLETED') {
        completed++;
      } else if (status == kOrderStatusProcessing || sale.paymentStatus == 'PENDING') {
        pending++;
      } else if (status == kOrderStatusCancelled) {
        cancelled++;
      } else {
        delivering++;
      }
    }
    return {'pending': pending, 'completed': completed, 'cancelled': cancelled, 'delivering': delivering};
  }

  List<({String id, String name})> _getDistinctSellers() {
    final seen = <String>{};
    final list = <({String id, String name})>[];
    for (final s in _sales) {
      final id = s.sellerId ?? '';
      final name = s.sellerName ?? 'Không xác định';
      if (id.isEmpty && name == 'Không xác định') continue;
      final key = id.isEmpty ? name : id;
      if (seen.contains(key)) continue;
      seen.add(key);
      list.add((id: id, name: name));
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.useMobileLayout) {
      final snapshot = _buildSnapshot();
      return SalesHistoryScreenMobile(
        snapshot: snapshot,
        searchController: _searchController,
        onSearchChanged: _onSearchChanged,
        onRefresh: _loadSales,
        onTimeRangeSelected: (key) {
          setState(() => _timeRange = key);
          _loadSales();
        },
        onCustomPick: _pickCustomDateRange,
        onBranchChanged: (id) {
          setState(() {
            _filterBranchId = id;
            _lastDoc = null;
            _hasMore = true;
          });
          _loadSales();
        },
        onSellerChanged: (id) {
          setState(() {
            _filterSellerId = id;
            _lastDoc = null;
            _hasMore = true;
          });
          _loadSales();
        },
        onStatusChanged: (value) {
          setState(() {
            _filterStatusValue = value;
            _lastDoc = null;
            _hasMore = true;
          });
          _loadSales();
        },
        onOpenFilter: () async {
          final result = await Navigator.push<SalesHistoryFilterResult>(
            context,
            MaterialPageRoute(
              builder: (_) => SalesHistoryFilterScreen(
                initialTimeRange: _timeRange,
                initialCustomStart: _customStart,
                initialCustomEnd: _customEnd,
                initialBranchId: _filterBranchId,
                initialSellerId: _filterSellerId,
                initialStatusValue: _filterStatusValue,
                branches: context.read<BranchProvider>().branches,
                sellers: _getDistinctSellers(),
              ),
            ),
          );
          if (result != null && mounted) {
            setState(() {
              _timeRange = result.timeRange;
              _customStart = result.customStart;
              _customEnd = result.customEnd;
              _filterBranchId = result.branchId;
              _filterSellerId = result.sellerId;
              _filterStatusValue = result.statusValue;
              _lastDoc = null;
              _hasMore = true;
            });
            _loadSales();
          }
        },
        onLoadMore: _loadMoreSales,
      );
    }

    return SalesHistoryScreenDesktop(
      snapshot: _buildSnapshot(),
      searchController: _searchController,
      filterCustomerNameController: _filterCustomerNameController,
      onSearchChanged: _onSearchChanged,
      onRefresh: _loadSales,
      onShowColumnPicker: _showColumnPicker,
      onCreateNew: () => Navigator.pushNamed(context, '/sales'),
      onImport: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng Import đang phát triển')));
      },
      onExport: () {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng Xuất file đang phát triển')));
      },
      onSaleSelected: (s) => setState(() => _selectedSale = s),
      onFilterBranchChanged: (id) {
        setState(() {
          _filterBranchId = id;
          _lastDoc = null;
          _hasMore = true;
        });
        _loadSales();
      },
      onFilterDateChanged: (from, to) {
        setState(() {
          _filterDateFrom = from;
          _filterDateTo = to;
          if (from != null && to != null) {
            _timeRange = SalesHistoryTimeRangeKey.custom;
            _customStart = from;
            _customEnd = to;
            _loadSales();
          }
        });
      },
      onFilterSellerChanged: (id) {
        setState(() {
          _filterSellerId = id;
          _lastDoc = null;
          _hasMore = true;
        });
        _loadSales();
      },
      onFilterStatusChanged: (value) {
        setState(() {
          _filterStatusValue = value;
          _lastDoc = null;
          _hasMore = true;
        });
        _loadSales();
      },
      onFilterCustomerNameChanged: (v) => setState(() => _filterCustomerName = v ?? ''),
      onFilterEinvoiceStatusChanged: (v) => setState(() => _filterEinvoiceStatus = v),
      onFilterPaymentMethodChanged: (v) => setState(() => _filterPaymentMethod = v),
      onReset: () {
        setState(() {
          _filterBranchId = null;
          _filterSellerId = null;
          _filterStatusValue = null;
          _filterCustomerName = '';
          _filterCustomerNameController.clear();
          _filterEinvoiceStatus = null;
          _filterPaymentMethod = null;
          _filterDateFrom = null;
          _filterDateTo = null;
          _timeRange = SalesHistoryTimeRangeKey.week;
          _customStart = null;
          _customEnd = null;
          _lastDoc = null;
          _hasMore = true;
        });
        _loadSales();
      },
      onLoadMore: _loadMoreSales,
      onEditSale: (sale) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SaleDetailScreen(sale: sale, forceMobile: false)),
        );
      },
    );
  }
}
