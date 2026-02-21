import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../models/profit_report_model.dart';
import '../../services/sales_service.dart';
import '../../services/product_service.dart';
import '../../utils/platform_utils.dart';
import 'profit_report_screen_mobile.dart';
import 'profit_report_screen_desktop.dart';

/// Màn hình báo cáo lợi nhuận — điều phối, chọn Mobile hoặc Desktop.
class ProfitReportScreen extends StatefulWidget {
  final bool? forceMobile;

  const ProfitReportScreen({super.key, this.forceMobile});

  @override
  State<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends State<ProfitReportScreen> {
  DateTime _startDate = DateTime.now().copyWith(day: 1);
  DateTime _endDate = DateTime.now();
  String? _selectedBranchId;
  bool _byMonth = false;

  ProfitReport? _report;
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
      final report = _byMonth
          ? await salesService.getProfitByMonth(
              startDate: _startDate,
              endDate: _endDate,
              branchId: _selectedBranchId,
            )
          : await salesService.getProfitByDay(
              startDate: _startDate,
              endDate: _endDate,
              branchId: _selectedBranchId,
            );

      if (mounted) {
        setState(() {
          _report = report;
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
    setState(() => _startDate = d);
    _loadReport();
  }

  void _setEndDate(DateTime d) {
    setState(() => _endDate = d);
    _loadReport();
  }

  void _setBranchId(String? id) {
    setState(() => _selectedBranchId = id);
    _loadReport();
  }

  void _setByMonth(bool v) {
    setState(() => _byMonth = v);
    _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    if (_useMobileLayout) {
      return ProfitReportScreenMobile(
        report: _report,
        isLoading: _isLoading,
        error: _error,
        startDate: _startDate,
        endDate: _endDate,
        selectedBranchId: _selectedBranchId,
        byMonth: _byMonth,
        onStartDateChanged: _setStartDate,
        onEndDateChanged: _setEndDate,
        onBranchChanged: _setBranchId,
        onByMonthChanged: _setByMonth,
        onRefresh: _loadReport,
      );
    }
    return ProfitReportScreenDesktop(
      report: _report,
      isLoading: _isLoading,
      error: _error,
      startDate: _startDate,
      endDate: _endDate,
      selectedBranchId: _selectedBranchId,
      byMonth: _byMonth,
      onStartDateChanged: _setStartDate,
      onEndDateChanged: _setEndDate,
      onBranchChanged: _setBranchId,
      onByMonthChanged: _setByMonth,
      onRefresh: _loadReport,
    );
  }
}
