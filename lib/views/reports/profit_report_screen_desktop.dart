import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../controllers/branch_provider.dart';
import '../../models/profit_report_model.dart';
import '../../services/export_service.dart';
import '../../widgets/date_range_filter.dart';
import '../../widgets/responsive_container.dart';

/// Báo cáo lợi nhuận — giao diện desktop.
class ProfitReportScreenDesktop extends StatelessWidget {
  const ProfitReportScreenDesktop({
    super.key,
    required this.report,
    required this.isLoading,
    required this.error,
    required this.startDate,
    required this.endDate,
    required this.selectedBranchId,
    required this.byMonth,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onBranchChanged,
    required this.onByMonthChanged,
    required this.onRefresh,
  });

  final ProfitReport? report;
  final bool isLoading;
  final String? error;
  final DateTime startDate;
  final DateTime endDate;
  final String? selectedBranchId;
  final bool byMonth;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<bool> onByMonthChanged;
  final VoidCallback onRefresh;

  Future<void> _exportExcel(BuildContext context) async {
    if (report == null || report!.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có dữ liệu để xuất Excel'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    try {
      final r = report!;
      final rows = r.items.map((e) {
        return <Object?>[
          byMonth ? DateFormat('MM/yyyy').format(e.date) : DateFormat('dd/MM/yyyy').format(e.date),
          e.revenue.toInt(),
          e.cost.toInt(),
          e.profit.toInt(),
          e.profitMarginPercent.toStringAsFixed(1),
        ];
      }).toList();
      final result = await ExportService.instance.exportToExcelFromRows(
        fileName: 'Bao_cao_loi_nhuan_${DateFormat('yyyyMMdd').format(DateTime.now())}',
        sheetName: 'Lợi nhuận',
        headers: const ['Kỳ', 'Doanh thu (₫)', 'Giá vốn (₫)', 'Lợi nhuận (₫)', 'Tỷ lệ %'],
        rows: rows,
        summaryRow: [
          'TỔNG',
          r.totalRevenue.toInt(),
          r.totalCost.toInt(),
          r.totalProfit.toInt(),
          r.profitMarginPercent.toStringAsFixed(1),
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
          SnackBar(content: Text('Lỗi xuất Excel: $e'), backgroundColor: Colors.red),
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
                      'Báo cáo lợi nhuận',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: isLoading ? null : onRefresh,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Tải lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.shade600,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: (report != null && report!.items.isNotEmpty)
                              ? () => _exportExcel(context)
                              : null,
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
                    const SizedBox(width: 16),
                    Row(
                      children: [
                        const Text('Nhóm: ', style: TextStyle(fontSize: 14)),
                        ChoiceChip(
                          label: const Text('Theo ngày'),
                          selected: !byMonth,
                          onSelected: (v) => onByMonthChanged(false),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Theo tháng'),
                          selected: byMonth,
                          onSelected: (v) => onByMonthChanged(true),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (error != null)
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(error!, style: TextStyle(color: Colors.red.shade700)),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: onRefresh, child: const Text('Thử lại')),
                      ],
                    ),
                  )
                else if (report != null) ...[
                  _SummaryRow(report: report!),
                ],
              ],
            ),
          ),
          if (!isLoading && error == null && report != null) ...[
            const Divider(height: 1),
            Expanded(
              child: report!.items.isEmpty
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
                            if (report!.items.isNotEmpty) ...[
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Biểu đồ lợi nhuận',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 24),
                                      SizedBox(
                                        height: 280,
                                        child: _ProfitBarChart(
                                          items: report!.items,
                                          byMonth: byMonth,
                                        ),
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
                                      'Chi tiết theo kỳ',
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
                                        DataColumn(label: Text('Kỳ')),
                                        DataColumn(label: Text('Doanh thu (₫)'), numeric: true),
                                        DataColumn(label: Text('Giá vốn (₫)'), numeric: true),
                                        DataColumn(label: Text('Lợi nhuận (₫)'), numeric: true),
                                        DataColumn(label: Text('Tỷ lệ %'), numeric: true),
                                      ],
                                      rows: report!.items.map((e) {
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(
                                              byMonth
                                                  ? DateFormat('MM/yyyy').format(e.date)
                                                  : DateFormat('dd/MM/yyyy').format(e.date),
                                            )),
                                            DataCell(Text(
                                                NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(e.revenue))),
                                            DataCell(Text(
                                                NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(e.cost))),
                                            DataCell(Text(
                                              NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(e.profit),
                                              style: TextStyle(
                                                color: e.profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            )),
                                            DataCell(Text('${e.profitMarginPercent.toStringAsFixed(1)}%')),
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
  final ProfitReport report;

  const _SummaryRow({required this.report});

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
                    Text('Tổng doanh thu', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(report.totalRevenue),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0EA5E9)),
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
              color: (report.totalProfit >= 0 ? const Color(0xFF059669) : Colors.red).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: (report.totalProfit >= 0 ? const Color(0xFF059669) : Colors.red).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.savings,
                  color: report.totalProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tổng lợi nhuận', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(report.totalProfit),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: report.totalProfit >= 0 ? const Color(0xFF059669) : Colors.red,
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
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.percent, color: Colors.amber.shade700, size: 32),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tỷ lệ lợi nhuận', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      '${report.profitMarginPercent.toStringAsFixed(1)}%',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.amber.shade800),
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

class _ProfitBarChart extends StatelessWidget {
  final List<ProfitReportItem> items;
  final bool byMonth;

  const _ProfitBarChart({required this.items, required this.byMonth});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final maxY = items.map((e) => e.profit).reduce((a, b) => a > b ? a : b);
    final minY = items.map((e) => e.profit).reduce((a, b) => a < b ? a : b);
    final maxVal = (maxY * 1.15).clamp(10.0, double.infinity);
    final minVal = (minY * 1.15).clamp(double.negativeInfinity, -10.0);
    final barGroups = items.asMap().entries.map((e) {
      final v = e.value.profit;
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: v,
            color: v >= 0 ? Colors.green.shade400 : Colors.red.shade400,
            width: 20,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(v >= 0 ? 4 : 0),
              bottom: Radius.circular(v >= 0 ? 0 : 4),
            ),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: v >= 0 ? maxVal : minVal,
              color: (v >= 0 ? Colors.green : Colors.red).withValues(alpha: 0.1),
            ),
          ),
        ],
      );
    }).toList();
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal,
        minY: minVal < 0 ? minVal : 0,
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
                    byMonth
                        ? DateFormat('MM/yyyy').format(items[i].date)
                        : DateFormat('dd/MM').format(items[i].date),
                    style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
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
                if (value >= 1000000) return Text('${(value / 1000000).toStringAsFixed(0)}tr', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)));
                if (value <= -1000000) return Text('-${(value.abs() / 1000000).toStringAsFixed(0)}tr', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)));
                return Text(value.toStringAsFixed(0), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)));
              },
              interval: (maxVal - minVal).abs() / 4,
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barGroups: barGroups,
      ),
      duration: const Duration(milliseconds: 250),
    );
  }
}
