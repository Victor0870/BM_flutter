import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/branch_provider.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/inventory_report_print_widget.dart';
import 'inventory_report_screen_data.dart';

/// Giao diện Báo cáo Xuất - Nhập - Tồn tối ưu cho màn hình rộng (DataTable).
class InventoryReportScreenDesktop extends StatelessWidget {
  const InventoryReportScreenDesktop({
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

  @override
  Widget build(BuildContext context) {
    final maxWidth = isDesktopPlatform ? kBreakpointTablet : kContentMaxWidth;

    return Scaffold(
      body: Column(
        children: [
          ResponsiveContainer(
            maxWidth: maxWidth,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Báo cáo Xuất - Nhập - Tồn',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (snapshot.report != null && snapshot.report!.items.isNotEmpty)
                          OutlinedButton.icon(
                            onPressed: () => _showPrintDialog(context),
                            icon: const Icon(Icons.print, size: 18),
                            label: const Text('In báo cáo'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue.shade700,
                            ),
                          ),
                        if (snapshot.report != null && snapshot.report!.items.isNotEmpty)
                          const SizedBox(width: 8),
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
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DateRangeFilter(
                        startDate: snapshot.startDate,
                        endDate: snapshot.endDate,
                        onStartDateChanged: onStartDateChanged,
                        onEndDateChanged: onEndDateChanged,
                      ),
                    ),
                    const SizedBox(width: 16),
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
                        return SizedBox(
                          width: 200,
                          child: Container(
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
                          ),
                        );
                      },
                    ),
                  ],
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
                    'Dùng Ctrl+P (hoặc Cmd+P) để in trang. Chọn in nội dung báo cáo hoặc "Lưu dưới dạng PDF".',
                  ),
                  duration: Duration(seconds: 4),
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
    return _buildReportTable(context);
  }

  Widget _buildReportTable(BuildContext context) {
    final report = snapshot.report!;
    if (report.items.isEmpty) {
      return const Center(
        child: Text('Không có dữ liệu trong kỳ báo cáo'),
      );
    }

    final daysInPeriod = snapshot.endDate.difference(snapshot.startDate).inDays + 1;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 700),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
            columnSpacing: 16,
            columns: const [
              DataColumn(
                label: Text(
                  'Tên sản phẩm',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'ĐVT',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              DataColumn(
                label: Text(
                  'Tồn đầu',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                numeric: true,
              ),
              DataColumn(
                label: Text(
                  'Nhập',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                numeric: true,
              ),
              DataColumn(
                label: Text(
                  'Xuất',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                numeric: true,
              ),
              DataColumn(
                label: Text(
                  'Tốc độ bán/ngày',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                numeric: true,
              ),
              DataColumn(
                label: Text(
                  'Tồn cuối',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                numeric: true,
              ),
              DataColumn(
                label: Text(
                  'Giá trị cuối',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF94A3B8),
                    letterSpacing: 0.5,
                  ),
                ),
                numeric: true,
              ),
            ],
            rows: [
              ...report.items.map((item) {
                final unit = item.product.units.isNotEmpty
                    ? item.product.units.first.unitName
                    : (item.product.unit.isNotEmpty ? item.product.unit : '');
                final closingValue = item.closingStock * item.product.importPrice;
                final salesVelocity = daysInPeriod > 0
                    ? item.outgoingStock / daysInPeriod
                    : 0.0;
                final minStock = item.product.minStock ?? 0.0;
                final isLowStock = minStock > 0 && item.closingStock < minStock;

                return DataRow(
                  color: WidgetStateProperty.all(
                    isLowStock ? Colors.red.shade50 : null,
                  ),
                  cells: [
                    DataCell(
                      Text(
                        item.product.name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isLowStock ? Colors.red.shade800 : null,
                        ),
                      ),
                    ),
                    DataCell(Text(unit, style: const TextStyle(fontSize: 13))),
                    DataCell(
                      Text(
                        item.openingStock.toStringAsFixed(0),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Text(
                        item.incomingStock.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        item.outgoingStock.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        salesVelocity.toStringAsFixed(2),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    DataCell(
                      Text(
                        item.closingStock.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isLowStock ? Colors.red.shade700 : null,
                        ),
                      ),
                    ),
                    DataCell(
                      Text(
                        NumberFormat.currency(
                          locale: 'vi_VN',
                          symbol: '₫',
                        ).format(closingValue),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              }),
              DataRow(
                color: WidgetStateProperty.all(Colors.blue.shade50),
                cells: [
                  const DataCell(
                    Text(
                      'TỔNG CỘNG',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const DataCell(Text('')),
                  DataCell(
                    Text(
                      report.totalOpeningStock.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      report.totalIncomingStock.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      report.totalOutgoingStock.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      daysInPeriod > 0
                          ? (report.totalOutgoingStock / daysInPeriod)
                              .toStringAsFixed(2)
                          : '-',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      report.totalClosingStock.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      NumberFormat.currency(
                        locale: 'vi_VN',
                        symbol: '₫',
                      ).format(
                        report.items.fold(
                          0.0,
                          (sum, item) =>
                              sum + (item.closingStock * item.product.importPrice),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget chọn khoảng thời gian (dùng trên Desktop).
class _DateRangeFilter extends StatelessWidget {
  const _DateRangeFilter({
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;

  Future<void> _selectDate(
    BuildContext context,
    DateTime initialDate,
    ValueChanged<DateTime> onDateSelected,
  ) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onDateSelected(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _selectDate(context, startDate, onStartDateChanged),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    'Từ: ${dateFormat.format(startDate)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: InkWell(
            onTap: () => _selectDate(context, endDate, onEndDateChanged),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today,
                      size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  Text(
                    'Đến: ${dateFormat.format(endDate)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
