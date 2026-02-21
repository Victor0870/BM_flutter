/// Một dòng trong báo cáo lợi nhuận theo ngày/tháng.
/// Dựa trên cost (giá vốn) và basePrice/price (giá bán) trong ProductModel.
class ProfitReportItem {
  /// Ngày hoặc đầu tháng (tùy groupBy)
  final DateTime date;
  /// Doanh thu (tổng item.subtotal)
  final double revenue;
  /// Giá vốn (tổng quantity * product.cost/importPrice)
  final double cost;
  /// Lợi nhuận gộp = revenue - cost
  final double profit;

  const ProfitReportItem({
    required this.date,
    required this.revenue,
    required this.cost,
    required this.profit,
  });

  double get profitMarginPercent =>
      revenue > 0 ? (profit / revenue) * 100 : 0.0;
}

/// Báo cáo lợi nhuận gộp theo ngày hoặc tháng.
class ProfitReport {
  final DateTime startDate;
  final DateTime endDate;
  final String? branchId;
  final bool byMonth;
  final List<ProfitReportItem> items;

  const ProfitReport({
    required this.startDate,
    required this.endDate,
    this.branchId,
    this.byMonth = false,
    required this.items,
  });

  double get totalRevenue =>
      items.fold(0.0, (sum, item) => sum + item.revenue);
  double get totalCost => items.fold(0.0, (sum, item) => sum + item.cost);
  double get totalProfit => items.fold(0.0, (sum, item) => sum + item.profit);
  double get profitMarginPercent =>
      totalRevenue > 0 ? (totalProfit / totalRevenue) * 100 : 0.0;
}
