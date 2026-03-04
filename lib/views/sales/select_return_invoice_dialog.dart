import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/sale_model.dart';
import '../../controllers/auth_provider.dart';
import '../../services/sales_service.dart';

/// Popup "Chọn hóa đơn trả hàng": bộ lọc trái (tìm kiếm, thời gian), bảng hóa đơn phải, nút Trả nhanh.
/// Trả về [SaleModel] khi user bấm Chọn hoặc Trả nhanh; null khi đóng.
Future<SaleModel?> showSelectReturnInvoiceDialog(BuildContext context) async {
  return showDialog<SaleModel>(
    context: context,
    barrierDismissible: false,
    builder: (context) => const _SelectReturnInvoiceDialog(),
  );
}

class _SelectReturnInvoiceDialog extends StatefulWidget {
  const _SelectReturnInvoiceDialog();

  @override
  State<_SelectReturnInvoiceDialog> createState() => _SelectReturnInvoiceDialogState();
}

class _SelectReturnInvoiceDialogState extends State<_SelectReturnInvoiceDialog> {
  final TextEditingController _invoiceCodeController = TextEditingController();
  final TextEditingController _deliveryCodeController = TextEditingController();
  final TextEditingController _customerController = TextEditingController();
  final TextEditingController _productCodeController = TextEditingController();
  final TextEditingController _productNameController = TextEditingController();

  DateTime? _dateFrom;
  DateTime? _dateTo;
  List<SaleModel> _sales = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _sortDescending = true;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _invoiceCodeController.dispose();
    _deliveryCodeController.dispose();
    _customerController.dispose();
    _productCodeController.dispose();
    _productNameController.dispose();
    super.dispose();
  }

  Future<void> _loadSales() async {
    final auth = context.read<AuthProvider>();
    if (auth.user == null) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final salesService = SalesService(isPro: auth.isPro, userId: auth.user!.uid);
      DateTime? start = _dateFrom != null ? DateTime(_dateFrom!.year, _dateFrom!.month, _dateFrom!.day) : null;
      DateTime? end = _dateTo != null
          ? DateTime(_dateTo!.year, _dateTo!.month, _dateTo!.day).add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1))
          : null;
      final list = await salesService.getSales(startDate: start, endDate: end);
      if (!mounted) return;
      setState(() {
        _sales = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<SaleModel> _getFilteredSales() {
    var list = _sales;
    final invoiceQ = _invoiceCodeController.text.trim().toLowerCase();
    if (invoiceQ.isNotEmpty) {
      list = list.where((s) => _displayInvoiceCode(s).toLowerCase().contains(invoiceQ) || s.id.toLowerCase().contains(invoiceQ)).toList();
    }
    final deliveryQ = _deliveryCodeController.text.trim().toLowerCase();
    if (deliveryQ.isNotEmpty) {
      list = list.where((s) => (s.notes ?? '').toLowerCase().contains(deliveryQ)).toList();
    }
    final customerQ = _customerController.text.trim().toLowerCase();
    if (customerQ.isNotEmpty) {
      list = list.where((s) {
        final name = (s.customerName ?? 'Khách lẻ').toLowerCase();
        return name.contains(customerQ);
      }).toList();
    }
    final productCodeQ = _productCodeController.text.trim().toLowerCase();
    if (productCodeQ.isNotEmpty) {
      list = list.where((s) => s.items.any((i) => (i.productId).toLowerCase().contains(productCodeQ))).toList();
    }
    final productNameQ = _productNameController.text.trim().toLowerCase();
    if (productNameQ.isNotEmpty) {
      list = list.where((s) => s.items.any((i) => i.productName.toLowerCase().contains(productNameQ))).toList();
    }
    list = List.from(list);
    list.sort((a, b) => _sortDescending ? b.timestamp.compareTo(a.timestamp) : a.timestamp.compareTo(b.timestamp));
    return list;
  }

  String _displayInvoiceCode(SaleModel sale) {
    final short = sale.id.length >= 8 ? sale.id.substring(0, 8).toUpperCase() : sale.id.toUpperCase();
    return 'HD$short';
  }

  String _formatPrice(double v) => NumberFormat('#,###', 'vi_VN').format(v);

  @override
  Widget build(BuildContext context) {
    final filtered = _getFilteredSales();
    return Dialog(
      child: Container(
        width: 900,
        height: 560,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Chọn hóa đơn trả hàng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 280,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _filterSection('Tìm kiếm', [
                          _filterField('Theo mã hóa đơn', _invoiceCodeController, () => setState(() {})),
                          _filterField('Theo mã vận đơn bán', _deliveryCodeController, () => setState(() {})),
                          _filterField('Theo khách hàng hoặc ĐT', _customerController, () => setState(() {})),
                          _filterField('Theo mã hàng', _productCodeController, () => setState(() {})),
                          _filterField('Theo tên hàng', _productNameController, () => setState(() {})),
                        ]),
                        const SizedBox(height: 12),
                        _filterSection('Thời gian', [
                          ListTile(
                            title: const Text('Từ ngày', style: TextStyle(fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_today, size: 20),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _dateFrom ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (d != null && mounted) setState(() { _dateFrom = d; _loadSales(); });
                              },
                            ),
                            subtitle: Text(_dateFrom != null ? DateFormat('dd/MM/yyyy').format(_dateFrom!) : 'Chọn', style: const TextStyle(fontSize: 13)),
                          ),
                          ListTile(
                            title: const Text('Đến ngày', style: TextStyle(fontSize: 12)),
                            trailing: IconButton(
                              icon: const Icon(Icons.calendar_today, size: 20),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _dateTo ?? DateTime.now(),
                                  firstDate: _dateFrom ?? DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (d != null && mounted) setState(() { _dateTo = d; _loadSales(); });
                              },
                            ),
                            subtitle: Text(_dateTo != null ? DateFormat('dd/MM/yyyy').format(_dateTo!) : 'Chọn', style: const TextStyle(fontSize: 13)),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.search, size: 18),
                          label: const Text('Lọc'),
                          onPressed: _loadSales,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ),
                          Expanded(
                            child: _isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: SingleChildScrollView(
                                      child: DataTable(
                                        headingRowColor: WidgetStateProperty.all(const Color(0xFF2563EB)),
                                        headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                        columnSpacing: 20,
                                        columns: [
                                          const DataColumn(label: Text('Mã hóa đơn')),
                                          DataColumn(
                                            label: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text('Thời gian'),
                                                IconButton(
                                                  icon: Icon(_sortDescending ? Icons.arrow_drop_down : Icons.arrow_drop_up, color: Colors.white),
                                                  onPressed: () => setState(() => _sortDescending = !_sortDescending),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 32),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const DataColumn(label: Text('Nhân viên')),
                                          const DataColumn(label: Text('Khách hàng')),
                                          const DataColumn(label: Text('Tổng cộng'), numeric: true),
                                          const DataColumn(label: SizedBox(width: 70)),
                                        ],
                                        rows: filtered.map((sale) {
                                          return DataRow(
                                            cells: [
                                              DataCell(Text(_displayInvoiceCode(sale), style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w500))),
                                              DataCell(Text(DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp), style: const TextStyle(fontSize: 13))),
                                              DataCell(Text(sale.sellerName ?? '—', style: const TextStyle(fontSize: 13))),
                                              DataCell(Text(sale.customerName ?? 'Khách lẻ', style: const TextStyle(fontSize: 13))),
                                              DataCell(Text(_formatPrice(sale.totalAmount), style: const TextStyle(fontSize: 13))),
                                              DataCell(
                                                OutlinedButton(
                                                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12)),
                                                  onPressed: () => Navigator.pop(context, sale),
                                                  child: const Text('Chọn'),
                                                ),
                                              ),
                                            ],
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                icon: const Icon(Icons.keyboard_return, size: 18),
                label: const Text('Trả nhanh'),
                onPressed: filtered.isNotEmpty ? () => Navigator.pop(context, filtered.first) : null,
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _filterField(String hint, TextEditingController controller, VoidCallback onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 12, color: Colors.grey[600]),
          isDense: true,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (_) => onChanged(),
      ),
    );
  }
}
