import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/branch_provider.dart';
import '../../models/inventory_report_model.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/inventory_report_print_widget.dart';
import 'inventory_report_screen_data.dart';

/// Giao diện Báo cáo Xuất - Nhập - Tồn tối ưu cho điện thoại (ListView / Card rút gọn).
class InventoryReportScreenMobile extends StatelessWidget {
  const InventoryReportScreenMobile({
    super.key,
    required this.snapshot,
    required this.onGenerateReport,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onBranchChanged,
  });

  final InventoryReportSnapshot snapshot;
  final VoidCallback onGenerateReport;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;
  final ValueChanged<String?> onBranchChanged;

  void _showDateRangeBottomSheet(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Chọn khoảng thời gian',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Color(0xFF64748B)),
                title: const Text('Từ ngày'),
                subtitle: Text(dateFormat.format(snapshot.startDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: snapshot.startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) onStartDateChanged(picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Color(0xFF64748B)),
                title: const Text('Đến ngày'),
                subtitle: Text(dateFormat.format(snapshot.endDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: snapshot.endDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) onEndDateChanged(picked);
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Xong'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrintDialog(BuildContext context) {
    final report = snapshot.report;
    if (report == null || report.items.isEmpty) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xem trước / In báo cáo'),
        content: SingleChildScrollView(
          child: InventoryReportPrintWidget(
            report: report,
            startDate: snapshot.startDate,
            endDate: snapshot.endDate,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Dùng chức năng In của thiết bị (hoặc chia sẻ lưu PDF) để in báo cáo.',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('In báo cáo'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo cáo Xuất - Nhập - Tồn'),
        actions: [
          if (snapshot.report != null && snapshot.report!.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () => _showPrintDialog(context),
              tooltip: 'In báo cáo',
            ),
        ],
      ),
      body: Column(
        children: [
          ResponsiveContainer(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        'Báo cáo Xuất - Nhập - Tồn',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: snapshot.isLoading ? null : onGenerateReport,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Tạo báo cáo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => _showDateRangeBottomSheet(context),
                  icon: const Icon(Icons.date_range, size: 18),
                  label: Text(
                    '${DateFormat('dd/MM/yyyy').format(snapshot.startDate)} - ${DateFormat('dd/MM/yyyy').format(snapshot.endDate)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.centerLeft,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Consumer<BranchProvider>(
                  builder: (context, branchProvider, child) {
                    final branches =
                        branchProvider.branches.where((b) => b.isActive).toList();
                    final items = <DropdownMenuItem<String?>>[
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
                    ];
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButton<String?>(
                        value: snapshot.selectedBranchId,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: items,
                        onChanged: (value) => onBranchChanged(value),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _buildBody(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (snapshot.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              snapshot.errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onGenerateReport,
              child: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }
    if (snapshot.report == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              'Chưa có dữ liệu báo cáo',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Nhấn "Tạo báo cáo" để xem dữ liệu',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    return _buildReportList(context);
  }

  Widget _buildReportList(BuildContext context) {
    final report = snapshot.report!;
    if (report.items.isEmpty) {
      return const Center(
        child: Text('Không có dữ liệu trong kỳ báo cáo'),
      );
    }

    final daysInPeriod = snapshot.endDate.difference(snapshot.startDate).inDays + 1;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: report.items.length + 1,
      itemBuilder: (context, index) {
        if (index == report.items.length) {
          return _buildTotalCard(report, daysInPeriod);
        }
        return _BuildReportItemCard(
          item: report.items[index],
          daysInPeriod: daysInPeriod,
        );
      },
    );
  }

  Widget _buildTotalCard(InventoryReport report, int daysInPeriod) {
    final totalValue = report.items.fold(
      0.0,
      (sum, item) => sum + (item.closingStock * item.product.importPrice),
    );
    final totalVelocity = daysInPeriod > 0
        ? report.totalOutgoingStock / daysInPeriod
        : 0.0;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'TỔNG CỘNG',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tồn đầu', style: TextStyle(fontSize: 13)),
                Text(
                  report.totalOpeningStock.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Nhập', style: TextStyle(fontSize: 13, color: Colors.green.shade700)),
                Text(
                  report.totalIncomingStock.toStringAsFixed(0),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.green.shade700),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Xuất', style: TextStyle(fontSize: 13, color: Colors.red.shade700)),
                Text(
                  report.totalOutgoingStock.toStringAsFixed(0),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.red.shade700),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tốc độ bán/ngày', style: TextStyle(fontSize: 13)),
                Text(
                  totalVelocity.toStringAsFixed(2),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tồn cuối', style: TextStyle(fontSize: 13)),
                Text(
                  report.totalClosingStock.toStringAsFixed(0),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Giá trị cuối', style: TextStyle(fontSize: 13)),
                Text(
                  NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalValue),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BuildReportItemCard extends StatelessWidget {
  const _BuildReportItemCard({
    required this.item,
    required this.daysInPeriod,
  });

  final InventoryReportItem item;
  final int daysInPeriod;

  @override
  Widget build(BuildContext context) {
    final unit = item.product.units.isNotEmpty
        ? item.product.units.first.unitName
        : (item.product.unit.isNotEmpty ? item.product.unit : '');
    final closingValue = item.closingStock * item.product.importPrice;
    final salesVelocity = daysInPeriod > 0
        ? item.outgoingStock / daysInPeriod
        : 0.0;
    final minStock = item.product.minStock ?? 0.0;
    final isLowStock = minStock > 0 && item.closingStock < minStock;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isLowStock ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.product.name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isLowStock ? Colors.red.shade800 : null,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isLowStock)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Tồn cuối dưới ngưỡng tối thiểu',
                  style: TextStyle(fontSize: 11, color: Colors.red.shade700),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ĐVT: $unit', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                Text(
                  'Tồn cuối: ${item.closingStock.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isLowStock ? Colors.red.shade700 : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Tồn đầu: ${item.openingStock.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
                Text(
                  'Nhập: ${item.incomingStock.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: Colors.green.shade700),
                ),
                Text(
                  'Xuất: ${item.outgoingStock.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Tốc độ bán/ngày: ${salesVelocity.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(closingValue),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
