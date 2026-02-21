import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../services/sales_service.dart';
import '../../services/product_service.dart';
import '../../utils/platform_utils.dart';
import 'revenue_report_screen_mobile.dart';
import 'revenue_report_screen_desktop.dart';

/// Một dòng báo cáo doanh thu theo ngày.
class RevenueReportDayItem {
  final DateTime date;
  final double revenue;
  final int orderCount;

  const RevenueReportDayItem({
    required this.date,
    required this.revenue,
    required this.orderCount,
  });
}

/// Dữ liệu snapshot cho màn hình báo cáo doanh thu.
class RevenueReportSnapshot {
  final List<RevenueReportDayItem> byDay;
  final double totalRevenue;
  final int totalOrders;
  final bool isLoading;
  final String? error;

  const RevenueReportSnapshot({
    required this.byDay,
    required this.totalRevenue,
    required this.totalOrders,
    required this.isLoading,
    this.error,
  });
}

/// Màn hình báo cáo doanh thu — điều phối, chọn Mobile hoặc Desktop.
class RevenueReportScreen extends StatefulWidget {
  final bool? forceMobile;

  const RevenueReportScreen({super.key, this.forceMobile});

  @override
  State<RevenueReportScreen> createState() => _RevenueReportScreenState();
}

class _RevenueReportScreenState extends State<RevenueReportScreen> {
  DateTime _startDate = DateTime.now().copyWith(day: 1);
  DateTime _endDate = DateTime.now();
  String? _selectedBranchId;

  List<RevenueReportDayItem> _byDay = [];
  double _totalRevenue = 0.0;
  int _totalOrders = 0;
  bool _isLoading = true;
  String? _error;

  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReport());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final branchId = context.read<BranchProvider>().currentBranchId;
    if (_selectedBranchId != branchId && _selectedBranchId == null) {
      _selectedBranchId = branchId;
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user == null) {
        setState(() {
          _isLoading = false;
          _error = 'Chưa đăng nhập';
        });
        return;
      }
      final productService = ProductService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );
      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
        productService: productService,
      );
      final sales = await salesService.getSales(
        startDate: _startDate,
        endDate: _endDate,
        branchId: _selectedBranchId,
      );

      final map = <String, ({double revenue, int count})>{};
      for (final sale in sales) {
        final key =
            '${sale.timestamp.year}-${sale.timestamp.month.toString().padLeft(2, '0')}-${sale.timestamp.day.toString().padLeft(2, '0')}';
        if (!map.containsKey(key)) map[key] = (revenue: 0.0, count: 0);
        map[key] = (
          revenue: map[key]!.revenue + sale.totalAmount,
          count: map[key]!.count + 1
        );
      }
      final keys = map.keys.toList()..sort();
      final byDay = <RevenueReportDayItem>[];
      for (final key in keys) {
        final parts = key.split('-');
        if (parts.length != 3) continue;
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final cur = map[key]!;
        byDay.add(RevenueReportDayItem(
          date: date,
          revenue: cur.revenue,
          orderCount: cur.count,
        ));
      }
      double totalRevenue = 0.0;
      int totalOrders = 0;
      for (final item in byDay) {
        totalRevenue += item.revenue;
        totalOrders += item.orderCount;
      }

      if (mounted) {
        setState(() {
          _byDay = byDay;
          _totalRevenue = totalRevenue;
          _totalOrders = totalOrders;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _setStartDate(DateTime d) {
    setState(() {
      _startDate = d;
    });
    _loadReport();
  }

  void _setEndDate(DateTime d) {
    setState(() {
      _endDate = d;
    });
    _loadReport();
  }

  void _setBranchId(String? id) {
    setState(() {
      _selectedBranchId = id;
    });
    _loadReport();
  }

  RevenueReportSnapshot get _snapshot => RevenueReportSnapshot(
        byDay: _byDay,
        totalRevenue: _totalRevenue,
        totalOrders: _totalOrders,
        isLoading: _isLoading,
        error: _error,
      );

  @override
  Widget build(BuildContext context) {
    if (_useMobileLayout) {
      return RevenueReportScreenMobile(
        snapshot: _snapshot,
        startDate: _startDate,
        endDate: _endDate,
        selectedBranchId: _selectedBranchId,
        onStartDateChanged: _setStartDate,
        onEndDateChanged: _setEndDate,
        onBranchChanged: _setBranchId,
        onRefresh: _loadReport,
      );
    }
    return RevenueReportScreenDesktop(
      snapshot: _snapshot,
      startDate: _startDate,
      endDate: _endDate,
      selectedBranchId: _selectedBranchId,
      onStartDateChanged: _setStartDate,
      onEndDateChanged: _setEndDate,
      onBranchChanged: _setBranchId,
      onRefresh: _loadReport,
    );
  }
}
