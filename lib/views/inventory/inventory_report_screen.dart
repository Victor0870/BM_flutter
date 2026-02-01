import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/product_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../models/inventory_report_model.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/ad_banner_widget.dart';

/// Màn hình báo cáo Xuất - Nhập - Tồn (mobile/desktop theo platform).
class InventoryReportScreen extends StatefulWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const InventoryReportScreen({super.key, this.forceMobile});

  @override
  State<InventoryReportScreen> createState() => _InventoryReportScreenState();
}

class _InventoryReportScreenState extends State<InventoryReportScreen> {
  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;
  DateTime _startDate = DateTime.now().copyWith(day: 1); // Ngày đầu tháng
  DateTime _endDate = DateTime.now(); // Hôm nay
  String? _selectedBranchId;
  InventoryReport? _report;
  bool _isLoading = false;
  String? _errorMessage;

  void _showDateRangeBottomSheet() {
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
                subtitle: Text(dateFormat.format(_startDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_today, color: Color(0xFF64748B)),
                title: const Text('Đến ngày'),
                subtitle: Text(dateFormat.format(_endDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _endDate = picked);
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

  @override
  Widget build(BuildContext context) {
    final isMobile = _useMobileLayout;
    final double maxWidth = isDesktopPlatform ? kBreakpointTablet : kContentMaxWidth;

    return Scaffold(
      appBar: isDesktopPlatform
          ? null
          : AppBar(
              title: const Text('Báo cáo Xuất - Nhập - Tồn'),
            ),
      body: Column(
        children: [
          // Header và Filters
          ResponsiveContainer(
            maxWidth: maxWidth,
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
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _generateReport,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(isMobile ? 'Tạo báo cáo' : 'Tạo báo cáo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filters: Desktop = Row, Mobile = Column + nút mở BottomSheet cho ngày
                if (isMobile)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _showDateRangeBottomSheet,
                        icon: const Icon(Icons.date_range, size: 18),
                        label: Text(
                          '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
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
                              value: _selectedBranchId,
                              isExpanded: true,
                              underline: const SizedBox(),
                              items: items,
                              onChanged: (value) {
                                setState(() {
                                  _selectedBranchId = value;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _DateRangeFilter(
                          startDate: _startDate,
                          endDate: _endDate,
                          onStartDateChanged: (date) {
                            setState(() {
                              _startDate = date;
                            });
                          },
                          onEndDateChanged: (date) {
                            setState(() {
                              _endDate = date;
                            });
                          },
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
                                value: _selectedBranchId,
                                isExpanded: true,
                                underline: const SizedBox(),
                                items: items,
                                onChanged: (value) {
                                  setState(() {
                                    _selectedBranchId = value;
                                  });
                                },
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
          const AdBannerWidget(),
          const Divider(height: 1),
          // Data Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
                            const SizedBox(height: 16),
                            Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _generateReport,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : _report == null
                        ? Center(
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
                          )
                        : _buildReportTable(),
          ),
        ],
      ),
    );
  }

  Future<void> _generateReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final productProvider = context.read<ProductProvider>();
      final report = await productProvider.getInventoryReport(
        _startDate,
        _endDate,
        branchId: _selectedBranchId,
      );

      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tạo báo cáo: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Widget _buildReportTable() {
    if (_report == null || _report!.items.isEmpty) {
      return const Center(
        child: Text('Không có dữ liệu trong kỳ báo cáo'),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 600),
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
            ..._report!.items.map((item) {
              final unit = item.product.units.isNotEmpty
                  ? item.product.units.first.unitName
                  : (item.product.unit.isNotEmpty ? item.product.unit : '');
              final closingValue = item.closingStock * item.product.importPrice;

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      item.product.name,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
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
                      item.closingStock.toStringAsFixed(0),
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
            // Tổng hợp
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
                    _report!.totalOpeningStock.toStringAsFixed(0),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _report!.totalIncomingStock.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade700,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _report!.totalOutgoingStock.toStringAsFixed(0),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade700,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    _report!.totalClosingStock.toStringAsFixed(0),
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
                      _report!.items.fold(
                        0.0,
                        (sum, item) => sum + (item.closingStock * item.product.importPrice),
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

/// Widget để chọn khoảng thời gian
class _DateRangeFilter extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;

  const _DateRangeFilter({
    required this.startDate,
    required this.endDate,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

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
                  const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
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
                  const Icon(Icons.calendar_today, size: 18, color: Color(0xFF64748B)),
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
