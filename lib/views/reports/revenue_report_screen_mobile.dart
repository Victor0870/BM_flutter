import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../controllers/branch_provider.dart';
import '../../widgets/date_range_filter.dart';
import 'revenue_report_screen.dart';

/// Báo cáo doanh thu — giao diện mobile.
class RevenueReportScreenMobile extends StatelessWidget {
  const RevenueReportScreenMobile({
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo doanh thu'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: snapshot.isLoading ? null : onRefresh,
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
                    final branchIds = branches.map((b) => b.id).toSet();
                    final effectiveValue = selectedBranchId != null && branchIds.contains(selectedBranchId)
                        ? selectedBranchId
                        : null;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButton<String?>(
                        value: effectiveValue,
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
                const SizedBox(height: 16),
                if (snapshot.isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (snapshot.error != null)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          snapshot.error!,
                          style: TextStyle(color: Colors.red.shade700),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: onRefresh,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                else ...[
                  _SummaryCards(
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
                          Icon(Icons.trending_up,
                              size: 64, color: Colors.grey.shade300),
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
                      itemCount: snapshot.byDay.length,
                      itemBuilder: (context, i) {
                        final item = snapshot.byDay[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(
                              DateFormat('dd/MM/yyyy').format(item.date),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text('${item.orderCount} đơn hàng'),
                            trailing: Text(
                              NumberFormat.currency(
                                locale: 'vi_VN',
                                symbol: '₫',
                              ).format(item.revenue),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0EA5E9),
                              ),
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
  final double totalRevenue;
  final int totalOrders;

  const _SummaryCards({
    required this.totalRevenue,
    required this.totalOrders,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.attach_money,
            label: 'Tổng doanh thu',
            value: NumberFormat.compactCurrency(
              locale: 'vi_VN',
              symbol: '₫',
            ).format(totalRevenue),
            color: const Color(0xFF0EA5E9),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.receipt_long,
            label: 'Số đơn hàng',
            value: totalOrders.toString(),
            color: const Color(0xFF059669),
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
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
