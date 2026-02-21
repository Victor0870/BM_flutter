import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/product_provider.dart';
import '../../models/inventory_report_model.dart';
import '../../utils/platform_utils.dart';
import 'inventory_report_screen_data.dart';
import 'inventory_report_screen_mobile.dart';
import 'inventory_report_screen_desktop.dart';

/// Màn hình báo cáo Xuất - Nhập - Tồn: tệp điều phối — chọn Mobile hoặc Desktop theo [platform_utils].
/// Logic tải dữ liệu (ProductProvider) và state nằm ở đây; UI nằm ở *_mobile.dart và *_desktop.dart.
class InventoryReportScreen extends StatefulWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const InventoryReportScreen({super.key, this.forceMobile});

  @override
  State<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends State<InventoryReportScreen> {
  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;

  DateTime _startDate = DateTime.now().copyWith(day: 1);
  DateTime _endDate = DateTime.now();
  String? _selectedBranchId;
  InventoryReport? _report;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final productProvider = context.read<ProductProvider>();
      final report = await productProvider.getInventoryReport(
        _startDate,
        _endDate,
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
          _errorMessage = 'Lỗi khi tạo báo cáo: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  InventoryReportSnapshot get _snapshot => InventoryReportSnapshot(
        startDate: _startDate,
        endDate: _endDate,
        selectedBranchId: _selectedBranchId,
        report: _report,
        isLoading: _isLoading,
        errorMessage: _errorMessage,
      );

  @override
  Widget build(BuildContext context) {
    if (_useMobileLayout) {
      return InventoryReportScreenMobile(
        snapshot: _snapshot,
        onGenerateReport: _generateReport,
        onStartDateChanged: (date) => setState(() => _startDate = date),
        onEndDateChanged: (date) => setState(() => _endDate = date),
        onBranchChanged: (value) => setState(() => _selectedBranchId = value),
      );
    }
    return InventoryReportScreenDesktop(
      snapshot: _snapshot,
      onGenerateReport: _generateReport,
      onStartDateChanged: (date) => setState(() => _startDate = date),
      onEndDateChanged: (date) => setState(() => _endDate = date),
      onBranchChanged: (value) => setState(() => _selectedBranchId = value),
    );
  }
}
