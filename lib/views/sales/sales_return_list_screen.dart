import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/sales_return_model.dart';
import '../../controllers/sales_return_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../utils/platform_utils.dart';
import '../../l10n/app_localizations.dart';
import 'select_return_invoice_dialog.dart';
import 'sales_return_form_screen.dart';

const String kMainStoreBranchId = 'main_store';

/// Định nghĩa cột bảng hóa đơn trả (desktop)
class ReturnInvoiceColumnDef {
  final String id;
  final String label;
  final bool hasTotal;
  const ReturnInvoiceColumnDef(this.id, this.label, this.hasTotal);
}

/// Màn hình danh sách Hóa đơn trả hàng — desktop giống Hóa đơn bán hàng (bộ lọc, toolbar, bảng, ẩn/hiện cột).
/// Nút "Tạo mới" mở popup Chọn hóa đơn trả hàng, chọn xong mở form trả hàng với đơn đã chọn.
class SalesReturnListScreen extends StatefulWidget {
  final bool? forceMobile;

  const SalesReturnListScreen({super.key, this.forceMobile});

  @override
  State<SalesReturnListScreen> createState() => _SalesReturnListScreenState();
}

class _SalesReturnListScreenState extends State<SalesReturnListScreen> {
  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;

  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;
  String? _filterBranchId;
  late Map<String, bool> _visibleColumns;

  static const List<ReturnInvoiceColumnDef> columnDefs = [
    ReturnInvoiceColumnDef('returnCode', 'Mã đơn trả', false),
    ReturnInvoiceColumnDef('originalSaleId', 'Đơn gốc', false),
    ReturnInvoiceColumnDef('time', 'Thời gian', false),
    ReturnInvoiceColumnDef('branch', 'Chi nhánh', false),
    ReturnInvoiceColumnDef('reason', 'Lý do', false),
    ReturnInvoiceColumnDef('totalRefund', 'Số tiền hoàn', true),
    ReturnInvoiceColumnDef('paymentMethod', 'Phương thức', false),
    ReturnInvoiceColumnDef('user', 'Người tạo', false),
  ];

  @override
  void initState() {
    super.initState();
    _visibleColumns = {
      for (final def in columnDefs)
        def.id: def.id == 'returnCode' || def.id == 'time' || def.id == 'reason' || def.id == 'totalRefund',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReturns());
  }

  Future<void> _loadReturns() async {
    final now = DateTime.now();
    final start = _filterDateFrom ?? now.subtract(const Duration(days: 30));
    final end = _filterDateTo ?? now;
    await context.read<SalesReturnProvider>().loadSalesReturnReport(
      startDate: start,
      endDate: end,
      branchId: _filterBranchId,
    );
  }

  void _showColumnPicker() async {
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (ctx) => _ReturnColumnPickerDialog(
        visibleColumns: _visibleColumns,
        columnDefs: columnDefs,
      ),
    );
    if (result != null && mounted) setState(() => _visibleColumns = result);
  }

  Future<void> _onCreateNew() async {
    final sale = await showSelectReturnInvoiceDialog(context);
    if (!mounted || sale == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalesReturnFormScreen(preSelectedSaleId: sale.id, forceMobile: false),
      ),
    ).then((_) => _loadReturns());
  }

  @override
  Widget build(BuildContext context) {
    if (_useMobileLayout) {
      return Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.returnInvoice),
          actions: [
            IconButton(icon: const Icon(Icons.add), onPressed: _onCreateNew, tooltip: 'Tạo đơn trả'),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.keyboard_return, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text('Hóa đơn trả hàng: dùng giao diện desktop để xem đầy đủ.', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              FilledButton.icon(icon: const Icon(Icons.add), label: const Text('Tạo đơn trả hàng'), onPressed: _onCreateNew),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFilterSidebar(context),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildToolbar(context),
                _buildSummaryCards(context),
                Expanded(
                  child: Consumer<SalesReturnProvider>(
                    builder: (context, provider, _) {
                      return _buildReturnsTable(context, provider);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSidebar(BuildContext context) {
    final branchProvider = context.watch<BranchProvider>();
    final branches = branchProvider.branches.where((b) => b.isActive).toList();
    const borderColor = Color(0xFFE2E8F0);
    const primaryColor = Color(0xFF2563EB);

    return SizedBox(
      width: 300,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
          border: const Border(right: BorderSide(color: borderColor)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(-2, 0))],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Icon(Icons.filter_list, color: primaryColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.advancedFilter,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () {
                      setState(() {
                        _filterDateFrom = null;
                        _filterDateTo = null;
                        _filterBranchId = null;
                      });
                      _loadReturns();
                    },
                    tooltip: AppLocalizations.of(context)!.resetFilter,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: borderColor),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _filterSection(context, 'Chi nhánh', [
                    DropdownButtonFormField<String?>(
                      value: _filterBranchId,
                      decoration: const InputDecoration(
                        hintText: 'Chọn chi nhánh',
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Tất cả chi nhánh')),
                        ...branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.id == kMainStoreBranchId ? 'Cửa hàng chính' : b.name))),
                      ],
                      onChanged: (v) {
                        setState(() => _filterBranchId = v);
                        _loadReturns();
                      },
                    ),
                  ]),
                  _filterSection(context, 'Thời gian', [
                    ListTile(
                      title: const Text('Từ ngày', style: TextStyle(fontSize: 13)),
                      subtitle: Text(_filterDateFrom != null ? DateFormat('dd/MM/yyyy').format(_filterDateFrom!) : 'Tất cả'),
                      trailing: const Icon(Icons.calendar_today, size: 20),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _filterDateFrom ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null && mounted) {
                          setState(() => _filterDateFrom = d);
                          _loadReturns();
                        }
                      },
                    ),
                    ListTile(
                      title: const Text('Đến ngày', style: TextStyle(fontSize: 13)),
                      subtitle: Text(_filterDateTo != null ? DateFormat('dd/MM/yyyy').format(_filterDateTo!) : 'Tất cả'),
                      trailing: const Icon(Icons.calendar_today, size: 20),
                      onTap: () async {
                        final d = await showDatePicker(
                          context: context,
                          initialDate: _filterDateTo ?? _filterDateFrom ?? DateTime.now(),
                          firstDate: _filterDateFrom ?? DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (d != null && mounted) {
                          setState(() => _filterDateTo = d);
                          _loadReturns();
                        }
                      },
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterSection(BuildContext context, String title, List<Widget> children) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
        initiallyExpanded: true,
        children: children,
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ElevatedButton.icon(
            onPressed: _onCreateNew,
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
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng đang phát triển'))),
            icon: const Icon(Icons.upload_file, size: 18),
            label: const Text('Import file'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tính năng đang phát triển'))),
            icon: const Icon(Icons.download, size: 18),
            label: const Text('Xuất file'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          ),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.view_column), onPressed: _showColumnPicker, tooltip: AppLocalizations.of(context)!.selectColumns),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReturns, tooltip: 'Làm mới'),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(BuildContext context) {
    return Consumer<SalesReturnProvider>(
      builder: (context, provider, _) {
        final loading = provider.isLoading && provider.salesReturns.isEmpty;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          child: Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  label: 'Số đơn trả',
                  value: loading ? '...' : '${provider.totalReturnCount}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  label: 'Tổng tiền hoàn',
                  value: loading ? '...' : NumberFormat('#,###', 'vi_VN').format(provider.totalRefundAmount),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReturnsTable(BuildContext context, SalesReturnProvider provider) {
    final branchProvider = context.read<BranchProvider>();
    final branches = branchProvider.branches;
    final visibleDefs = columnDefs.where((d) => _visibleColumns[d.id] == true).toList();
    if (visibleDefs.isEmpty) {
      return const Center(child: Text('Chọn ít nhất một cột hiển thị (nút Ẩn/hiện cột)'));
    }

    if (provider.isLoading && provider.salesReturns.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null && provider.salesReturns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(provider.errorMessage!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadReturns, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    if (provider.salesReturns.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.keyboard_return, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Chưa có hóa đơn trả nào', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    String getCellValue(SalesReturnModel r, String id) {
      final branchList = branches.where((b) => b.id == r.branchId).toList();
      final branchName = branchList.isEmpty ? (r.branchId == kMainStoreBranchId ? 'Cửa hàng chính' : r.branchId) : branchList.first.name;
      switch (id) {
        case 'returnCode':
          return r.id.length > 10 ? '${r.id.substring(0, 10)}...' : r.id;
        case 'originalSaleId':
          return r.originalSaleId.length > 10 ? '${r.originalSaleId.substring(0, 10)}...' : r.originalSaleId;
        case 'time':
          return DateFormat('dd/MM/yyyy HH:mm').format(r.timestamp);
        case 'branch':
          return branchName;
        case 'reason':
          return r.reason;
        case 'totalRefund':
          return NumberFormat('#,###', 'vi_VN').format(r.totalRefundAmount);
        case 'paymentMethod':
          return r.paymentMethod == 'CASH' ? 'Tiền mặt' : r.paymentMethod == 'DEBT' ? 'Trừ công nợ' : 'Chuyển khoản';
        case 'user':
          return r.userId;
        default:
          return '—';
      }
    }

    return Card(
      margin: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
            columnSpacing: 16,
            columns: [
              for (final def in visibleDefs)
                DataColumn(
                  label: Text(def.label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  numeric: def.id == 'totalRefund',
                ),
            ],
            rows: provider.salesReturns.map((r) {
              return DataRow(
                cells: [
                  for (final def in visibleDefs)
                    DataCell(Text(getCellValue(r, def.id), style: const TextStyle(fontSize: 13))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryCard({required this.label, required this.value});

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

class _ReturnColumnPickerDialog extends StatefulWidget {
  final Map<String, bool> visibleColumns;
  final List<ReturnInvoiceColumnDef> columnDefs;

  const _ReturnColumnPickerDialog({required this.visibleColumns, required this.columnDefs});

  @override
  State<_ReturnColumnPickerDialog> createState() => _ReturnColumnPickerDialogState();
}

class _ReturnColumnPickerDialogState extends State<_ReturnColumnPickerDialog> {
  late Map<String, bool> _visible;

  @override
  void initState() {
    super.initState();
    _visible = Map.of(widget.visibleColumns);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(AppLocalizations.of(context)!.selectColumns, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context, _visible)),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: widget.columnDefs
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
            ),
          ],
        ),
      ),
    );
  }
}

