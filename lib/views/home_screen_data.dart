import 'package:flutter/material.dart';
import '../models/sale_model.dart';

/// Dữ liệu snapshot cho HomeScreen (dùng chung cho Mobile và Desktop).
class HomeScreenSnapshot {
  const HomeScreenSnapshot({
    required this.todayRevenue,
    required this.todaySalesCount,
    required this.todayProfit,
    required this.isLoadingStats,
    required this.totalCustomers,
    required this.inventoryValue,
    required this.recentSales,
    required this.bestSellingProducts,
    required this.weeklyRevenue,
    required this.isLoadingRecentSales,
    required this.isLoadingBestSellers,
    required this.isLoadingWeeklyRevenue,
  });

  final double todayRevenue;
  final int todaySalesCount;
  /// Lợi nhuận gộp hôm nay (doanh thu - giá vốn).
  final double todayProfit;
  final bool isLoadingStats;
  final int totalCustomers;
  final double inventoryValue;
  final List<SaleModel> recentSales;
  final List<Map<String, dynamic>> bestSellingProducts;
  final List<double> weeklyRevenue;
  final bool isLoadingRecentSales;
  final bool isLoadingBestSellers;
  final bool isLoadingWeeklyRevenue;
}

String homeOrderIdFrom(String id) {
  final s = id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  return 'ORD-$s';
}

String homeStatusText(SaleModel s) {
  return s.paymentStatus == 'COMPLETED' ? 'Hoàn thành' : 'Đang xử lý';
}

Color homeStatusColor(String status) {
  switch (status) {
    case 'Hoàn thành':
      return const Color(0xFF059669);
    case 'Đã hủy':
      return const Color(0xFF64748B);
    default:
      return const Color(0xFFF59E0B);
  }
}
