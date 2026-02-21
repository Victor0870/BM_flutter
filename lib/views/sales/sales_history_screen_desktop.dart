import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/sale_model.dart';
import '../../models/branch_model.dart';
import '../../l10n/app_localizations.dart';
import 'sales_history_screen_data.dart';

/// Màn hình Quản lý hóa đơn - giao diện Desktop.
class SalesHistoryScreenDesktop extends StatelessWidget {
  const SalesHistoryScreenDesktop({
    super.key,
    required this.snapshot,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onShowColumnPicker,
    required this.onCreateNew,
    required this.onImport,
    required this.onExport,
    required this.onSaleSelected,
    required this.onFilterBranchChanged,
    required this.onFilterDateChanged,
    required this.onFilterSellerChanged,
    required this.onFilterStatusChanged,
    required this.onReset,
    required this.onLoadMore,
    required this.onEditSale,
  });

  final SalesHistorySnapshot snapshot;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;
  final VoidCallback onShowColumnPicker;
  final VoidCallback onCreateNew;
  final VoidCallback onImport;
  final VoidCallback onExport;
  final ValueChanged<SaleModel?> onSaleSelected;
  final ValueChanged<String?> onFilterBranchChanged;
  final void Function(DateTime?, DateTime?) onFilterDateChanged;
  final ValueChanged<String?> onFilterSellerChanged;
  final ValueChanged<String?> onFilterStatusChanged;
  final VoidCallback onReset;
  final VoidCallback? onLoadMore;
  final void Function(SaleModel sale) onEditSale;

  static const List<SalesHistoryInvoiceColumnDef> columnDefs = [
    SalesHistoryInvoiceColumnDef('invoiceCode', 'Mã hóa đơn', false),
    SalesHistoryInvoiceColumnDef('time', 'Thời gian', false),
    SalesHistoryInvoiceColumnDef('returnCode', 'Mã trả hàng', false),
    SalesHistoryInvoiceColumnDef('customerCode', 'Mã KH', false),
    SalesHistoryInvoiceColumnDef('customer', 'Khách hàng', false),
    SalesHistoryInvoiceColumnDef('totalGoods', 'Tổng tiền hàng', true),
    SalesHistoryInvoiceColumnDef('discount', 'Giảm giá', true),
    SalesHistoryInvoiceColumnDef('customerPaid', 'Khách đã trả', true),
    SalesHistoryInvoiceColumnDef('branch', 'Chi nhánh', false),
    SalesHistoryInvoiceColumnDef('seller', 'Người bán', false),
    SalesHistoryInvoiceColumnDef('creator', 'Người tạo', false),
    SalesHistoryInvoiceColumnDef('status', 'Trạng thái', false),
    SalesHistoryInvoiceColumnDef('createdAt', 'Thời gian tạo', false),
    SalesHistoryInvoiceColumnDef('notes', 'Ghi chú', false),
    SalesHistoryInvoiceColumnDef('customerNeedsPay', 'Khách cần trả', false),
  ];

  @override
  Widget build(BuildContext context) {
    final branchName = snapshot.selectedSale != null
        ? (snapshot.branches
                .where((b) => b.id == snapshot.selectedSale!.branchId)
                .map((b) => b.name)
                .firstOrNull ??
            '')
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InvoiceFilterSidebar(
          searchController: searchController,
          onSearchChanged: onSearchChanged,
          filterBranchId: snapshot.filterBranchId,
          onBranchChanged: onFilterBranchChanged,
          filterDateFrom: snapshot.filterDateFrom ?? snapshot.customStart,
          filterDateTo: snapshot.filterDateTo ?? snapshot.customEnd,
          onDateChanged: onFilterDateChanged,
          filterSellerId: snapshot.filterSellerId,
          onSellerChanged: onFilterSellerChanged,
          filterStatusValue: snapshot.filterStatusValue,
          onStatusChanged: onFilterStatusChanged,
          branches: snapshot.branches,
          sellers: snapshot.sellers,
          onReset: onReset,
        ),
        Expanded(
          child: Column(
            children: [
              _DesktopInvoiceToolbar(
                onRefresh: onRefresh,
                onShowColumnPicker: onShowColumnPicker,
                onCreateNew: onCreateNew,
                onImport: onImport,
                onExport: onExport,
              ),
              _InvoiceSummaryCards(
                isLoading: snapshot.isLoading,
                errorMessage: snapshot.errorMessage,
                summary: snapshot.invoiceSummary,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (snapshot.selectedSale != null)
                      _InvoiceDetailPanel(
                        sale: snapshot.selectedSale!,
                        branchName: branchName,
                        onClose: () => onSaleSelected(null),
                        onEdit: () => onEditSale(snapshot.selectedSale!),
                      ),
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        elevation: 0,
                        child: _SalesTableDesktop(
                          sales: snapshot.filteredSales,
                          isLoading: snapshot.isLoading,
                          errorMessage: snapshot.errorMessage,
                          onRefresh: onRefresh,
                          hasMore: snapshot.hasMore,
                          isLoadingMore: snapshot.isLoadingMore,
                          onLoadMore: onLoadMore,
                          selectedSale: snapshot.selectedSale,
                          onSaleSelected: onSaleSelected,
                          visibleColumns: snapshot.visibleColumns,
                          columnDefs: columnDefs,
                          branches: snapshot.branches,
                          getOrderId: snapshot.getOrderId,
                          summary: snapshot.invoiceSummary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const Color _invoiceFilterPrimary = Color(0xFF2563EB);
const Color _invoiceFilterText = Color(0xFF1E293B);
const Color _invoiceFilterBorder = Color(0xFFE2E8F0);

/// Dialog chọn cột hiển thị cho bảng hóa đơn.
class SalesHistoryColumnPickerDialog extends StatefulWidget {
  final Map<String, bool> visibleColumns;
  final List<SalesHistoryInvoiceColumnDef> columnDefs;
  final VoidCallback? onClose;

  const SalesHistoryColumnPickerDialog({
    super.key,
    required this.visibleColumns,
    required this.columnDefs,
    this.onClose,
  });

  @override
  State<SalesHistoryColumnPickerDialog> createState() => _SalesHistoryColumnPickerDialogState();
}

class _SalesHistoryColumnPickerDialogState extends State<SalesHistoryColumnPickerDialog> {
  late Map<String, bool> _visible;

  @override
  void initState() {
    super.initState();
    _visible = Map.of(widget.visibleColumns);
  }

  @override
  Widget build(BuildContext context) {
    const splitAt = 8;
    final left = widget.columnDefs.take(splitAt).toList();
    final right = widget.columnDefs.skip(splitAt).toList();
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(AppLocalizations.of(context)!.selectColumns,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(_visible),
                  tooltip: AppLocalizations.of(context)!.close,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: left
                            .map((def) => CheckboxListTile(
                                  value: _visible[def.id] ?? false,
                                  onChanged: (v) => setState(() => _visible[def.id] = v ?? false),
                                  title: Text(def.label, style: const TextStyle(fontSize: 14)),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ))
                            .toList(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: right
                            .map((def) => CheckboxListTile(
                                  value: _visible[def.id] ?? false,
                                  onChanged: (v) => setState(() => _visible[def.id] = v ?? false),
                                  title: Text(def.label, style: const TextStyle(fontSize: 14)),
                                  controlAffinity: ListTileControlAffinity.leading,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                ))
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceFilterSidebar extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String? filterBranchId;
  final ValueChanged<String?> onBranchChanged;
  final DateTime? filterDateFrom;
  final DateTime? filterDateTo;
  final void Function(DateTime?, DateTime?) onDateChanged;
  final String? filterSellerId;
  final ValueChanged<String?> onSellerChanged;
  final String? filterStatusValue;
  final ValueChanged<String?> onStatusChanged;
  final List<BranchModel> branches;
  final List<({String id, String name})> sellers;
  final VoidCallback? onReset;

  const _InvoiceFilterSidebar({
    required this.searchController,
    required this.onSearchChanged,
    required this.filterBranchId,
    required this.onBranchChanged,
    required this.filterDateFrom,
    required this.filterDateTo,
    required this.onDateChanged,
    required this.filterSellerId,
    required this.onSellerChanged,
    required this.filterStatusValue,
    required this.onStatusChanged,
    required this.branches,
    required this.sellers,
    this.onReset,
  });

  static InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500], fontStyle: FontStyle.italic),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _invoiceFilterBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _invoiceFilterBorder)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _section(BuildContext context, String title, {required Widget child}) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: _invoiceFilterPrimary.withValues(alpha: 0.08),
        highlightColor: _invoiceFilterPrimary.withValues(alpha: 0.04),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _invoiceFilterText)),
        iconColor: _invoiceFilterPrimary,
        collapsedIconColor: _invoiceFilterText,
        initiallyExpanded: true,
        children: [child],
      ),
    );
  }

  Widget _dateRow(BuildContext ctx) {
    final isAllTime = filterDateFrom == null && filterDateTo == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => onDateChanged(null, null),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(isAllTime ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20, color: isAllTime ? _invoiceFilterPrimary : _invoiceFilterBorder),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(ctx)!.allTime,
                    style: const TextStyle(fontSize: 13, color: _invoiceFilterText, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDateRangePicker(
              context: ctx,
              firstDate: DateTime(now.year - 2),
              lastDate: now,
              initialDateRange: filterDateFrom != null && filterDateTo != null
                  ? DateTimeRange(start: filterDateFrom!, end: filterDateTo!)
                  : DateTimeRange(start: now.subtract(const Duration(days: 6)), end: now),
              helpText: 'Chọn khoảng thời gian',
            );
            if (picked != null) {
              onDateChanged(
                DateTime(picked.start.year, picked.start.month, picked.start.day),
                DateTime(picked.end.year, picked.end.month, picked.end.day),
              );
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(!isAllTime ? Icons.radio_button_checked : Icons.radio_button_off,
                    size: 20, color: !isAllTime ? _invoiceFilterPrimary : _invoiceFilterBorder),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(ctx)!.customDate,
                    style: const TextStyle(fontSize: 13, color: _invoiceFilterText, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
          border: Border(right: BorderSide(color: _invoiceFilterBorder)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(-2, 0))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: _invoiceFilterPrimary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.advancedFilter,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _invoiceFilterText),
                    ),
                  ),
                  if (onReset != null)
                    IconButton(
                      icon: Icon(Icons.refresh, size: 20, color: _invoiceFilterText),
                      onPressed: onReset,
                      tooltip: AppLocalizations.of(context)!.resetFilter,
                      style: IconButton.styleFrom(foregroundColor: _invoiceFilterText),
                    ),
                ],
              ),
            ),
            const Divider(height: 1, color: _invoiceFilterBorder),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _section(context, 'Mã hóa đơn', child: ListenableBuilder(
                    listenable: searchController,
                    builder: (context, _) {
                      return TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Theo mã hóa đơn',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    searchController.clear();
                                    onSearchChanged('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _invoiceFilterBorder)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          isDense: true,
                        ),
                        onChanged: onSearchChanged,
                      );
                    },
                  )),
                  _section(context, 'Chi nhánh', child: DropdownButtonFormField<String?>(
                  initialValue: filterBranchId,
                  decoration: _inputDeco('Chọn chi nhánh'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tất cả chi nhánh')),
                    ...branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                  ],
                  onChanged: onBranchChanged,
                )),
                _section(context, 'Thời gian', child: _dateRow(context)),
                _section(context, 'Trạng thái hóa đơn', child: DropdownButtonFormField<String?>(
                  initialValue: filterStatusValue,
                  decoration: _inputDeco('Chọn trạng thái'),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tất cả')),
                    DropdownMenuItem(value: kOrderStatusProcessing, child: Text('Đang xử lý')),
                    DropdownMenuItem(value: kOrderStatusDelivered, child: Text('Hoàn thành')),
                    DropdownMenuItem(value: kOrderStatusCancelled, child: Text('Đã hủy')),
                  ],
                  onChanged: onStatusChanged,
                )),
                _section(context, 'Người bán', child: DropdownButtonFormField<String?>(
                  initialValue: filterSellerId,
                  decoration: _inputDeco('Chọn người bán'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tất cả')),
                    ...sellers.map((s) => DropdownMenuItem(value: s.id.isEmpty ? s.name : s.id, child: Text(s.name))),
                  ],
                  onChanged: onSellerChanged,
                )),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _DesktopInvoiceToolbar extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final VoidCallback onShowColumnPicker;
  final VoidCallback onCreateNew;
  final VoidCallback onImport;
  final VoidCallback onExport;

  const _DesktopInvoiceToolbar({
    required this.onRefresh,
    required this.onShowColumnPicker,
    required this.onCreateNew,
    required this.onImport,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: onCreateNew,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tạo mới'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onImport,
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Import file'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: onExport,
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Xuất file'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.view_column),
            onPressed: onShowColumnPicker,
            tooltip: AppLocalizations.of(context)!.selectColumns,
          ),
          IconButton(icon: const Icon(Icons.settings), onPressed: () {}, tooltip: 'Cài đặt'),
          IconButton(icon: const Icon(Icons.refresh), onPressed: onRefresh, tooltip: 'Làm mới'),
        ],
      ),
    );
  }
}

class _InvoiceSummaryCards extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final ({double totalGoods, double totalDiscount, double totalPaid}) summary;

  const _InvoiceSummaryCards({
    required this.isLoading,
    this.errorMessage,
    required this.summary,
  });

  String _fmt(double v) => NumberFormat('#,###', 'vi_VN').format(v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        children: [
          Expanded(child: _SummaryCardItem(label: 'Tổng tiền hàng', value: (isLoading || errorMessage != null) ? '...' : _fmt(summary.totalGoods))),
          const SizedBox(width: 12),
          Expanded(child: _SummaryCardItem(label: 'Giảm giá', value: (isLoading || errorMessage != null) ? '...' : _fmt(summary.totalDiscount))),
          const SizedBox(width: 12),
          Expanded(child: _SummaryCardItem(label: 'Khách đã trả', value: (isLoading || errorMessage != null) ? '...' : _fmt(summary.totalPaid))),
        ],
      ),
    );
  }
}

class _SummaryCardItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryCardItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _InvoiceDetailPanel extends StatelessWidget {
  final SaleModel sale;
  final String branchName;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  const _InvoiceDetailPanel({
    required this.sale,
    required this.branchName,
    required this.onClose,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final subTotal = sale.subTotal ?? sale.totalAmount;
    final discount = sale.totalDiscountAmount ?? 0;
    final paid = sale.totalPayment ?? sale.totalAmount;
    final status = sale.statusValue != null && sale.statusValue!.isNotEmpty
        ? orderStatusDisplayName(sale.statusValue)
        : (sale.paymentStatus == 'COMPLETED' ? 'Hoàn thành' : 'Đang xử lý');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFE3F2FD),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.close), onPressed: onClose, tooltip: 'Đóng'),
                const SizedBox(width: 8),
                Text('HD${sale.id.length > 6 ? sale.id.substring(0, 6).toUpperCase() : sale.id.toUpperCase()}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 16),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp), style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                const SizedBox(width: 16),
                Text(sale.customerId ?? '—', style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                const SizedBox(width: 16),
                Expanded(child: Text(sale.customerName ?? 'Khách lẻ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis)),
                Text('${NumberFormat('#,###', 'vi_VN').format(subTotal)} | ${NumberFormat('#,###', 'vi_VN').format(discount)} | ${NumberFormat('#,###', 'vi_VN').format(paid)}', style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Chip(label: Text(status, style: const TextStyle(fontSize: 12, color: Colors.white)), backgroundColor: status == 'Hoàn thành' ? Colors.green : Colors.orange),
                    const SizedBox(width: 12),
                    const Text('Người tạo:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(width: 4),
                    Text(sale.sellerName ?? '—', style: const TextStyle(fontSize: 13)),
                    const SizedBox(width: 16),
                    const Text('Người bán:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(width: 4),
                    Text(sale.sellerName ?? '—', style: const TextStyle(fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                    columnSpacing: 24,
                    columns: const [
                      DataColumn(label: Text('Mã hàng', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('Tên hàng', style: TextStyle(fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('SL', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('Đơn giá', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('Giảm giá', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                      DataColumn(label: Text('Thành tiền', style: TextStyle(fontWeight: FontWeight.w600)), numeric: true),
                    ],
                    rows: sale.items
                        .map((item) => DataRow(
                              cells: [
                                DataCell(Text(item.productId.length > 12 ? '${item.productId.substring(0, 12)}...' : item.productId)),
                                DataCell(Text(item.productName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                DataCell(Text(item.quantity.toStringAsFixed(0))),
                                DataCell(Text(NumberFormat('#,###', 'vi_VN').format(item.price))),
                                DataCell(Text(NumberFormat('#,###', 'vi_VN').format(item.discountAmount))),
                                DataCell(Text(NumberFormat('#,###', 'vi_VN').format(item.subtotal))),
                              ],
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton.icon(icon: const Icon(Icons.cancel_outlined), label: const Text('Hủy'), onPressed: () {}),
                    const SizedBox(width: 8),
                    TextButton.icon(icon: const Icon(Icons.copy), label: const Text('Sao chép'), onPressed: () {}),
                    const SizedBox(width: 8),
                    TextButton.icon(icon: const Icon(Icons.download), label: const Text('Xuất file'), onPressed: () {}),
                    const Spacer(),
                    FilledButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Chỉnh sửa'),
                      onPressed: onEdit,
                      style: FilledButton.styleFrom(backgroundColor: Colors.blue.shade600, foregroundColor: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(icon: const Icon(Icons.undo), label: const Text('Trả hàng'), onPressed: () {}),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(icon: const Icon(Icons.print), label: const Text('In'), onPressed: () {}),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesTableDesktop extends StatelessWidget {
  final List<SaleModel> sales;
  final bool isLoading;
  final String? errorMessage;
  final Future<void> Function() onRefresh;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final SaleModel? selectedSale;
  final ValueChanged<SaleModel?> onSaleSelected;
  final Map<String, bool> visibleColumns;
  final List<SalesHistoryInvoiceColumnDef> columnDefs;
  final List<BranchModel> branches;
  final String Function(String id) getOrderId;
  final ({double totalGoods, double totalDiscount, double totalPaid}) summary;

  const _SalesTableDesktop({
    required this.sales,
    required this.isLoading,
    this.errorMessage,
    required this.onRefresh,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    required this.selectedSale,
    required this.onSaleSelected,
    required this.visibleColumns,
    required this.columnDefs,
    required this.branches,
    required this.getOrderId,
    required this.summary,
  });

  String _getStatusText(SaleModel sale) {
    if (sale.statusValue != null && sale.statusValue!.isNotEmpty) return orderStatusDisplayName(sale.statusValue);
    if (sale.paymentStatus == 'COMPLETED') return 'Hoàn thành';
    return 'Đang xử lý';
  }

  String _getCellValue(SaleModel sale, String columnId) {
    final branchName = branches.where((b) => b.id == sale.branchId).map((b) => b.name).firstOrNull ?? '';
    switch (columnId) {
      case 'invoiceCode':
        return 'HD${getOrderId(sale.id).replaceAll('ORD-', '')}';
      case 'time':
        return DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp);
      case 'returnCode':
        return '—';
      case 'customerCode':
        return sale.customerId ?? '—';
      case 'customer':
        return sale.customerName ?? 'Khách lẻ';
      case 'totalGoods':
        return NumberFormat('#,###', 'vi_VN').format(sale.subTotal ?? sale.totalAmount);
      case 'discount':
        return NumberFormat('#,###', 'vi_VN').format(sale.totalDiscountAmount ?? 0);
      case 'customerPaid':
        return NumberFormat('#,###', 'vi_VN').format(sale.totalPayment ?? sale.totalAmount);
      case 'branch':
        return branchName;
      case 'seller':
        return sale.sellerName ?? '—';
      case 'creator':
        return sale.sellerName ?? '—';
      case 'status':
        return _getStatusText(sale);
      case 'createdAt':
        return DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp);
      case 'notes':
        return sale.notes ?? '—';
      case 'customerNeedsPay':
        return NumberFormat('#,###', 'vi_VN').format(sale.totalAmount);
      default:
        return '—';
    }
  }

  @override
  Widget build(BuildContext context) {
    final visibleDefs = columnDefs.where((d) => visibleColumns[d.id] == true).toList();
    if (visibleDefs.isEmpty) return const Center(child: Text('Chọn ít nhất một cột hiển thị'));

    return Column(
      children: [
        const Divider(height: 1),
        Expanded(
          child: isLoading && sales.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                          const SizedBox(height: 16),
                          Text(errorMessage!, style: TextStyle(color: Colors.red[700]), textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          ElevatedButton(onPressed: onRefresh, child: const Text('Thử lại')),
                        ],
                      ),
                    )
                  : sales.isEmpty
                      ? RefreshIndicator(
                          onRefresh: onRefresh,
                          child: ListView(
                            children: [
                              const SizedBox(height: 200),
                              Center(
                                child: Column(
                                  children: [
                                    Icon(Icons.receipt_long, size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 16),
                                    Text('Chưa có hóa đơn nào', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: onRefresh,
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              return Column(
                                children: [
                                  Expanded(
                                    child: SingleChildScrollView(
                                      scrollDirection: Axis.vertical,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(minWidth: constraints.maxWidth),
                                          child: DataTable(
                                            showCheckboxColumn: false,
                                            headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                                            columnSpacing: 16,
                                            columns: [
                                        for (final def in visibleDefs)
                                          DataColumn(
                                            label: def.hasTotal
                                                ? Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(def.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                                      if (def.id == 'totalGoods')
                                                        Text(NumberFormat('#,###', 'vi_VN').format(summary.totalGoods), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[800])),
                                                      if (def.id == 'discount')
                                                        Text(NumberFormat('#,###', 'vi_VN').format(summary.totalDiscount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[800])),
                                                      if (def.id == 'customerPaid')
                                                        Text(NumberFormat('#,###', 'vi_VN').format(summary.totalPaid), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey[800])),
                                                    ],
                                                  )
                                                : Text(def.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                            numeric: def.id.contains('total') || def.id.contains('discount') || def.id.contains('Paid'),
                                          ),
                                      ],
                                      rows: sales.map((sale) {
                                        final isSelected = selectedSale?.id == sale.id;
                                        return DataRow(
                                          selected: isSelected,
                                          onSelectChanged: (_) => onSaleSelected(isSelected ? null : sale),
                                          cells: [
                                            for (final def in visibleDefs)
                                              DataCell(
                                                InkWell(onTap: () => onSaleSelected(isSelected ? null : sale), child: Text(_getCellValue(sale, def.id))),
                                              ),
                                          ],
                                        );
                                      }).toList(),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (hasMore && onLoadMore != null)
                                    Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Center(
                                        child: isLoadingMore
                                            ? const SizedBox(height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2))
                                            : TextButton.icon(onPressed: onLoadMore, icon: const Icon(Icons.add_circle_outline, size: 18), label: const Text('Tải thêm')),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}
