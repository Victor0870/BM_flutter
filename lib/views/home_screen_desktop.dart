import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/routes.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../controllers/notification_provider.dart';
import '../../widgets/notification_popup.dart';
import 'home_screen_data.dart';

/// Màn hình tổng quan (Dashboard) tối ưu cho màn hình rộng.
class HomeScreenDesktop extends StatelessWidget {
  const HomeScreenDesktop({
    super.key,
    required this.snapshot,
  });

  final HomeScreenSnapshot snapshot;

  static const double _contentPadding = 32;
  static const double _sectionSpacing = 32;
  static final GlobalKey _bellKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    return Scaffold(
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, authProvider),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(_contentPadding),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1400),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildDashboardHeader(context),
                            const SizedBox(height: _sectionSpacing),
                            _buildStatsGrid(context),
                            const SizedBox(height: _sectionSpacing),
                            _buildChartAndBestSellers(context),
                            const SizedBox(height: _sectionSpacing),
                            _buildRecentTransactions(context),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthProvider authProvider) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: _contentPadding),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 384),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: Colors.grey.shade400),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Tìm kiếm nhanh...',
                        hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Consumer<NotificationProvider>(
            builder: (context, np, _) {
              final hasUnread = np.unreadCount > 0;
              return IconButton(
                key: _bellKey,
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(Icons.notifications_outlined, color: Colors.grey.shade400),
                    if (hasUnread)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  final box = _bellKey.currentContext?.findRenderObject() as RenderBox?;
                  if (box != null) {
                    final offset = box.localToGlobal(Offset.zero);
                    NotificationPopup.show(context, offset, box.size);
                  }
                },
              );
            },
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () async {
              await authProvider.signOut();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      authProvider.user?.email?.split('@').first ?? 'User',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const Text(
                      'Chi nhánh',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.grey.shade200,
                  child: Text(
                    (authProvider.user?.email?.substring(0, 1).toUpperCase() ?? 'U'),
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          'Tổng hợp báo cáo và hoạt động kinh doanh hôm nay.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pushNamed(context, AppRoutes.sales),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade500,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 8,
          ).copyWith(
            backgroundColor: WidgetStateProperty.resolveWith<Color>(
              (Set<WidgetState> states) {
                if (states.contains(WidgetState.hovered)) return Colors.orange.shade600;
                return Colors.orange.shade500;
              },
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.flash_on, size: 22),
              SizedBox(width: 8),
              Text(
                'BÁN HÀNG NGAY',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 2.0,
      children: [
        _StatsCard(
          title: 'Tổng doanh thu',
          value: snapshot.isLoadingStats
              ? '...'
              : NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(snapshot.todayRevenue),
          trend: '+12.5%',
          isUp: true,
          icon: Icons.bar_chart,
          color: Colors.blue,
        ),
        _StatsCard(
          title: 'Đơn hàng mới',
          value: snapshot.isLoadingStats ? '...' : snapshot.todaySalesCount.toString(),
          trend: '+8.2%',
          isUp: true,
          icon: Icons.shopping_cart,
          color: Colors.purple,
        ),
        _StatsCard(
          title: 'Lợi nhuận',
          value: snapshot.isLoadingStats
              ? '...'
              : NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(snapshot.todayProfit),
          trend: snapshot.todayRevenue > 0 && snapshot.todayProfit >= 0
              ? '${(snapshot.todayProfit / snapshot.todayRevenue * 100).toStringAsFixed(1)}%'
              : '—',
          isUp: snapshot.todayProfit >= 0,
          icon: Icons.trending_up,
          color: Colors.teal,
        ),
        _StatsCard(
          title: 'Giá trị tồn kho',
          value: NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(snapshot.inventoryValue),
          trend: '+5.4%',
          isUp: true,
          icon: Icons.inventory_2,
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildChartAndBestSellers(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 2, child: _buildChartSection(context)),
        const SizedBox(width: 24),
        Expanded(child: _buildBestSellers(context)),
      ],
    );
  }

  Widget _buildChartSection(BuildContext context) {
    const double pad = 24;
    const double chartHeight = 280;

    return Container(
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Hiệu suất doanh thu',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Tháng',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: const Text(
                        'Tuần',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: pad),
          SizedBox(
            height: chartHeight,
            child: snapshot.isLoadingWeeklyRevenue
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : snapshot.weeklyRevenue.isEmpty
                    ? Center(
                        child: Text(
                          'Chưa có dữ liệu doanh thu',
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                        ),
                      )
                    : _buildRevenueBarChart(context, chartHeight),
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueBarChart(BuildContext context, double chartHeight) {
    final data = snapshot.weeklyRevenue;
    final maxY = data.isEmpty
        ? 100.0
        : (data.reduce((a, b) => a > b ? a : b) * 1.15).clamp(10.0, double.infinity);
    final now = DateTime.now();
    final weekDays = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];

    final barGroups = data.asMap().entries.map((entry) {
      final i = entry.key;
      final value = entry.value;
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: value,
            color: Colors.blue.shade400,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxY,
              color: Colors.blue.shade50,
            ),
          ),
        ],
        showingTooltipIndicators: [0],
      );
    }).toList();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final value = rod.toY;
              return BarTooltipItem(
                value > 0 ? '${value.toStringAsFixed(1)} tr' : '0',
                TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= data.length) return const SizedBox.shrink();
                final dayIndex = (now.weekday - 6 + i) % 7;
                final dayLabel = weekDays[dayIndex < 0 ? dayIndex + 7 : dayIndex];
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    dayLabel,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
              reservedSize: 24,
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return Text(
                  value >= 1000 ? '${(value / 1000).toStringAsFixed(0)}k' : value.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
              interval: maxY / 4,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFE2E8F0),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
      duration: const Duration(milliseconds: 250),
    );
  }

  Widget _buildBestSellers(BuildContext context) {
    const double pad = 24;

    return Container(
      padding: const EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 5 sản phẩm bán chạy',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: pad),
          snapshot.isLoadingBestSellers
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : snapshot.bestSellingProducts.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Chưa có dữ liệu sản phẩm bán chạy',
                        style: TextStyle(
                            fontSize: 14, color: Colors.grey.shade500),
                      ),
                    )
                  : Column(
                      children:
                          snapshot.bestSellingProducts.map((product) {
                        final productName =
                            product['productName'] as String;
                        final salesCount =
                            product['salesCount'] as int;
                        final price = product['price'] as double;
                        String priceText;
                        if (price >= 1000000) {
                          priceText =
                              '${(price / 1000000).toStringAsFixed(1)}tr';
                        } else if (price >= 1000) {
                          priceText =
                              '${(price / 1000).toStringAsFixed(0)}k';
                        } else {
                          priceText =
                              '${NumberFormat('#,###').format(price)}đ';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: const Color(0xFFF1F5F9)),
                                ),
                                child: const Center(
                                    child: Text('📦',
                                        style:
                                            TextStyle(fontSize: 20))),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      productName,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$salesCount đơn',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                priceText,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Giao dịch gần đây',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hoạt động kinh doanh trong ngày.',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Tính năng đang được phát triển')),
                    );
                  },
                  icon: const Icon(Icons.filter_list, size: 14),
                  label: const Text(
                    'Lọc kết quả',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: snapshot.isLoadingRecentSales
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : snapshot.recentSales.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              Icon(Icons.receipt_long,
                                  size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Chưa có giao dịch nào',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _buildRecentSalesTable(context),
          ),
        ],
      ),
    );
  }

  static const double _columnSpacing = 16;
  static const double _tablePaddingH = 16;
  static const int _columnCount = 7;

  Widget _buildRecentSalesTable(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth - _tablePaddingH - _columnSpacing * (_columnCount - 1);
        final colWidth = (totalWidth / _columnCount).clamp(70.0, 200.0);

        return Consumer<BranchProvider>(
          builder: (context, branchProvider, _) {
            String getBranchName(String? branchId) {
              if (branchId == null || branchId.isEmpty) return '';
              try {
                final b = branchProvider.branches
                    .firstWhere((e) => e.id == branchId);
                return b.name;
              } catch (_) {
                return '';
              }
            }

            return DataTable(
              showCheckboxColumn: false,
              headingRowColor:
                  WidgetStateProperty.all(Colors.grey.shade50),
              columnSpacing: _columnSpacing,
              columns: [
                DataColumn(
                  label: SizedBox(
                    width: colWidth,
                    child: const Text(
                      'NGÀY BÁN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: colWidth,
                    child: const Text(
                      'MÃ ĐƠN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: colWidth,
                    child: const Text(
                      'KHÁCH HÀNG',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: colWidth,
                    child: const Text(
                      'TỔNG CỘNG',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: SizedBox(
                    width: colWidth,
                    child: const Text(
                      'NHÂN VIÊN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: colWidth,
                    child: const Text(
                      'CHI NHÁNH',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: colWidth,
                    child: const Text(
                      'TRẠNG THÁI',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            rows: snapshot.recentSales.map((sale) {
              final status = homeStatusText(sale);
              final statusColor = homeStatusColor(status);
              final orderId = homeOrderIdFrom(sale.id);
              final sellerName = sale.sellerName ?? '';
              final branchName = getBranchName(sale.branchId);

              return DataRow(
                cells: [
                  DataCell(
                    SizedBox(
                      width: colWidth,
                      child: Text(
                        DateFormat('dd/MM/yyyy HH:mm')
                            .format(sale.timestamp),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: colWidth,
                      child: Text(
                        orderId,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B82F6),
                        ),
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: colWidth,
                      child: Text(
                        sale.customerName ?? 'Khách lẻ',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: colWidth,
                      child: Text(
                        NumberFormat.currency(
                                locale: 'vi_VN', symbol: '₫')
                            .format(sale.totalAmount),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: colWidth,
                      child: Text(
                        sellerName,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF0F172A)),
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: colWidth,
                      child: Text(
                        branchName,
                        style: const TextStyle(
                            fontSize: 14, color: Color(0xFF0F172A)),
                        textAlign: TextAlign.left,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                  DataCell(
                    SizedBox(
                      width: colWidth,
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.08),
                            borderRadius:
                                BorderRadius.circular(999),
                            border: Border.all(
                                color: statusColor
                                    .withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          );
          },
        );
      },
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.title,
    required this.value,
    required this.trend,
    required this.isUp,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final String trend;
  final bool isUp;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(icon, color: color, size: 18),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: isUp
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isUp
                                    ? Icons.trending_up
                                    : Icons.trending_down,
                                size: 10,
                                color: isUp
                                    ? Colors.green.shade600
                                    : Colors.red.shade600,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                trend,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isUp
                                      ? Colors.green.shade600
                                      : Colors.red.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title.toUpperCase(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text(
                        value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          height: 1.0,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
