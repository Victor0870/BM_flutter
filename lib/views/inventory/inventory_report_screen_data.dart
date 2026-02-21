import '../../models/inventory_report_model.dart';

/// Dữ liệu snapshot cho màn hình Báo cáo Xuất - Nhập - Tồn (dùng chung Mobile/Desktop).
class InventoryReportSnapshot {
  const InventoryReportSnapshot({
    required this.startDate,
    required this.endDate,
    required this.selectedBranchId,
    required this.report,
    required this.isLoading,
    required this.errorMessage,
  });

  final DateTime startDate;
  final DateTime endDate;
  final String? selectedBranchId;
  final InventoryReport? report;
  final bool isLoading;
  final String? errorMessage;
}
