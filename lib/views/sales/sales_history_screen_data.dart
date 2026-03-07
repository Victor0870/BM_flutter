import '../../models/sale_model.dart';
import '../../models/branch_model.dart';

/// Kết quả chọn từ màn Bộ lọc (mobile).
class SalesHistoryFilterResult {
  const SalesHistoryFilterResult({
    required this.timeRange,
    this.customStart,
    this.customEnd,
    this.branchId,
    this.sellerId,
    this.statusValue,
  });

  final SalesHistoryTimeRangeKey timeRange;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String? branchId;
  final String? sellerId;
  final String? statusValue;
}

/// Các lựa chọn khoảng thời gian hiển thị
enum SalesHistoryTimeRangeKey {
  today,
  week,
  month,
  all,
  custom,
}

/// Định nghĩa cột có thể hiển thị trong bảng hóa đơn (desktop)
class SalesHistoryInvoiceColumnDef {
  final String id;
  final String label;
  final bool hasTotal;
  const SalesHistoryInvoiceColumnDef(this.id, this.label, this.hasTotal);
}

/// Snapshot dữ liệu cho màn hình Quản lý hóa đơn (dùng chung Mobile/Desktop).
class SalesHistorySnapshot {
  const SalesHistorySnapshot({
    required this.sales,
    required this.filteredSales,
    required this.isLoading,
    this.errorMessage,
    required this.timeRange,
    this.customStart,
    this.customEnd,
    this.filterBranchId,
    this.filterSellerId,
    this.filterStatusValue,
    this.filterCustomerName,
    this.filterEinvoiceStatus,
    this.filterPaymentMethod,
    required this.stats,
    required this.hasMore,
    required this.isLoadingMore,
    this.selectedSale,
    required this.visibleColumns,
    this.filterDateFrom,
    this.filterDateTo,
    required this.invoiceSummary,
    required this.branches,
    required this.sellers,
    required this.getOrderId,
  });

  final List<SaleModel> sales;
  final List<SaleModel> filteredSales;
  final bool isLoading;
  final String? errorMessage;
  final SalesHistoryTimeRangeKey timeRange;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String? filterBranchId;
  final String? filterSellerId;
  final String? filterStatusValue;
  final String? filterCustomerName;
  final String? filterEinvoiceStatus;
  final String? filterPaymentMethod;
  final Map<String, int> stats;
  final bool hasMore;
  final bool isLoadingMore;
  final SaleModel? selectedSale;
  final Map<String, bool> visibleColumns;
  final DateTime? filterDateFrom;
  final DateTime? filterDateTo;
  final ({double totalGoods, double totalDiscount, double totalPaid}) invoiceSummary;
  final List<BranchModel> branches;
  final List<({String id, String name})> sellers;
  final String Function(String id) getOrderId;
}
