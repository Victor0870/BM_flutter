import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../controllers/branch_provider.dart';
import '../../services/export_service.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/responsive_container.dart';
import 'revenue_report_screen.dart';

/// Báo cáo doanh thu — giao diện desktop.
class RevenueReportScreenDesktop extends StatelessWidget {
  const RevenueReportScreenDesktop({
    super.key,
    required this.snapshot,
    required this.startDate,
    required this.endDate,
    required this.selectedBranchId,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onBranchChanged,
    required this.onRefresh,
  });

  final RevenueReportSnapshot snapshot;
  final DateTime startDate;
  final DateTime endDate;
  final String? selectedBranchId;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback onRefresh;

  Future<void> _exportExcel(BuildContext context) async {
    if (snapshot.byDay.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có dữ liệu để xuất Excel'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      final rows = snapshot.byDay.map((e) {
        return <Object?>[
          DateFormat('dd/MM/yyyy').format(e.date),
          e.orderCount,
          e.revenue.toInt(),
        ];
      }).toList();
      final result = await ExportService.instance.exportToExcelFromRows(
        fileName: 'Bao_cao_doanh_thu_${DateFormat('yyyyMMdd').format(DateTime.now())}',
        sheetName: 'Doanh thu',
        headers: const ['Ngày', 'Số đơn', 'Doanh thu (₫)'],
        rows: rows,
        summaryRow: [
          'TỔNG',
          snapshot.totalOrders,
          snapshot.totalRevenue.toInt(),
        ],
      );
      if (!context.mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      if (result.savedFilePath != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Đã xuất Excel: ${result.suggestedFileName}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('File: ${result.suggestedFileName}. Trên web dùng tải về nếu có.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xuất Excel: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ResponsiveContainer(
            maxWidth: 1200,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Báo cáo doanh thu',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: snapshot.isLoading ? null : onRefresh,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Tải lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: snapshot.byDay.isEmpty ? null : () => _exportExcel(context),
                          icon: const Icon(Icons.file_download, size: 18),
                          label: const Text('Xuất Excel'),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DateRangeFilter(
                        startDate: startDate,
                        endDate: endDate,
                        onStartDateChanged: onStartDateChanged,
                        onEndDateChanged: onEndDateChanged,
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 220,
                      child: Consumer<BranchProvider>(
                        builder: (context, branchProvider, _) {
                          final branches =
                              branchProvider.branches.where((b) => b.isActive).toList();
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButton<String?>(
                              value: selectedBranchId,
                              isExpanded: true,
                              underline: const SizedBox(),
                              hint: const Text('Tất cả chi nhánh'),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Tất cả chi nhánh'),
                                ),
                                ...branches.map(
                                  (b) => DropdownMenuItem<String?>(
                                    value: b.id,
                                    child: Text(b.name),
                                  ),
                                ),
                              ],
                              onChanged: (v) => onBranchChanged(v),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (snapshot.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snapshot.error != null)
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(snapshot.error!, style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: onRefresh, child: const Text('Thử lại')),
                      ],
                    ),
                  )
                else ...[
                  _SummaryRow(
                    totalRevenue: snapshot.totalRevenue,
                    totalOrders: snapshot.totalOrders,
                  ),
                ],
              ],
            ),
          ),
          if (!snapshot.isLoading && snapshot.error == null) ...[
            const Divider(height: 1),
            Expanded(
              child: snapshot.byDay.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.trending_up, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Không có dữ liệu trong kỳ báo cáo',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  : ResponsiveContainer(
                      maxWidth: 1200,
                      padding: const EdgeInsets.all(24),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (snapshot.byDay.isNotEmpty) ...[
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Biểu đồ doanh thu theo ngày',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        height: 280,
                                        child: _RevenueBarChart(items: snapshot.byDay),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                            Card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'Chi tiết theo ngày',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Ngày')),
                                        DataColumn(label: Text('Số đơn'), numeric: true),
                                        DataColumn(label: Text('Doanh thu (₫)'), numeric: true),
                                      ],
                                      rows: snapshot.byDay.map((e) {
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(
                                                DateFormat('dd/MM/yyyy').format(e.date))),
                                            DataCell(Text('${e.orderCount}')),
                                            DataCell(Text(
                                              NumberFormat.currency(
                                                locale: 'vi_VN',
                                                symbol: '₫',
                                              ).format(e.revenue),
                                            )),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final double totalRevenue;
  final int totalOrders;

  const _SummaryRow({
    required this.totalRevenue,
    required this.totalOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.attach_money, color: Colors.blue.shade700, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tổng doanh thu',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.currency(
                        locale: 'vi_VN',
                        symbol: '₫',
                      ).format(totalRevenue),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0EA5E9),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.green.shade700, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Số đơn hàng',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      totalOrders.toString(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RevenueBarChart extends StatelessWidget {
  final List<RevenueReportDayItem> items;

  const _RevenueBarChart({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final maxY = items.map((e) => e.revenue).reduce((a, b) => a > b ? a : b);
    final maxVal = (maxY * 1.15).clamp(10.0, double.infinity);
    final barGroups = items.asMap().entries.map((e) {
      final v = e.value.revenue;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: v,
            color: Colors.blue.shade400,
            width: 20,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: maxVal,
              color: Colors.blue.shade50,
            ),
          ),
        ],
      );
    }).toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(rod.toY),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                if (i < 0 || i >= items.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    DateFormat('dd/MM').format(items[i].date),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                );
              },
              reservedSize: 28,
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value >= 1000000) {
                  return Text(
                    '${(value / 1000000).toStringAsFixed(0)}tr',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  );
                }
                return Text(
                  value.toStringAsFixed(0),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                );
              },
              interval: maxVal / 4,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => const FlLine(
            color: Color(0xFFE2E8F0),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
      duration: const Duration(milliseconds: 250),
    );
  }
}
