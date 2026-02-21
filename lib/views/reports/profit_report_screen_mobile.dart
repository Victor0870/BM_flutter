import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/branch_provider.dart';
import '../../models/profit_report_model.dart';
import '../../widgets/date_range_filter.dart';

/// Báo cáo lợi nhuận — giao diện mobile.
class ProfitReportScreenMobile extends StatelessWidget {
  const ProfitReportScreenMobile({
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo lợi nhuận'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading ? null : onRefresh,
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DateRangeFilter(
                  startDate: startDate,
                  endDate: endDate,
                  onStartDateChanged: onStartDateChanged,
                  onEndDateChanged: onEndDateChanged,
                ),
                const SizedBox(height: 12),
                Consumer<BranchProvider>(
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Nhóm theo:', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 12),
                    ChoiceChip(
                      label: const Text('Ngày'),
                      selected: !byMonth,
                      onSelected: (v) => onByMonthChanged(false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Tháng'),
                      selected: byMonth,
                      onSelected: (v) => onByMonthChanged(true),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (error != null)
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(error!, style: TextStyle(color: Colors.red.shade700), textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: onRefresh, child: const Text('Thử lại')),
                      ],
                    ),
                  )
                else if (report != null) ...[
                  _SummaryCards(report: report!),
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
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: report!.items.length,
                      itemBuilder: (context, i) {
                        final item = report!.items[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              byMonth
                                  ? DateFormat('MM/yyyy').format(item.date)
                                  : DateFormat('dd/MM/yyyy').format(item.date),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              'DT: ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(item.revenue)}',
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  NumberFormat.currency(
                                    locale: 'vi_VN',
                                    symbol: '₫',
                                  ).format(item.profit),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: item.profit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                                Text(
                                  '${item.profitMarginPercent.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final ProfitReport report;

  const _SummaryCards({required this.report});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.attach_money,
            label: 'Tổng doanh thu',
            value: NumberFormat.compactCurrency(locale: 'vi_VN', symbol: '₫').format(report.totalRevenue),
            color: const Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.savings,
            label: 'Tổng lợi nhuận',
            value: NumberFormat.compactCurrency(locale: 'vi_VN', symbol: '₫').format(report.totalProfit),
            color: report.totalProfit >= 0 ? const Color(0xFF059669) : Colors.red,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
