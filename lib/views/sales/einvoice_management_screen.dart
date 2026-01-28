import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/sale_model.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../services/sales_service.dart';
import '../../services/einvoice_service.dart';
import '../../services/firebase_service.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/date_range_filter.dart';
import 'sale_detail_screen.dart';

/// Màn hình quản lý hóa đơn điện tử
/// Liệt kê các hóa đơn đã bán, hiển thị trạng thái HĐĐT (Đã xuất/Chưa xuất)
/// Cho phép phát hành hàng loạt và xem PDF
class EinvoiceManagementScreen extends StatefulWidget {
  const EinvoiceManagementScreen({super.key});

  @override
  State<EinvoiceManagementScreen> createState() => _EinvoiceManagementScreenState();
}

class _EinvoiceManagementScreenState extends State<EinvoiceManagementScreen> {
  DateTime _startDate = DateTime.now().copyWith(day: 1); // Ngày đầu tháng
  DateTime _endDate = DateTime.now(); // Hôm nay
  String? _selectedBranchId;
  List<SaleModel> _sales = [];
  final Set<String> _selectedSaleIds = {}; // Danh sách các đơn được chọn để phát hành hàng loạt
  bool _isLoading = false;
  String? _errorMessage;
  bool _isBulkIssuing = false;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  Future<void> _loadSales() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user == null) {
        setState(() {
          _errorMessage = 'Chưa đăng nhập';
          _isLoading = false;
        });
        return;
      }

      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );

      final sales = await salesService.getSales(
        startDate: _startDate,
        endDate: _endDate,
        branchId: _selectedBranchId,
      );

      // Sắp xếp theo thời gian mới nhất
      sales.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _sales = sales;
        _isLoading = false;
        _selectedSaleIds.clear(); // Clear selection khi reload
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tải danh sách hóa đơn: $e';
        _isLoading = false;
      });
    }
  }

  /// Kiểm tra hóa đơn đã xuất hay chưa
  bool _isInvoiceIssued(SaleModel sale) {
    return sale.invoiceNo != null && 
           sale.invoiceNo!.isNotEmpty &&
           sale.einvoiceUrl != null &&
           sale.einvoiceUrl!.isNotEmpty;
  }

  /// Phát hành hàng loạt hóa đơn điện tử
  Future<void> _bulkIssueInvoices() async {
    if (_selectedSaleIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ít nhất một hóa đơn để phát hành'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final selectedSales = _sales.where((sale) => _selectedSaleIds.contains(sale.id)).toList();
    
    // Kiểm tra các hóa đơn chưa được phát hành
    final unissuedSales = selectedSales.where((sale) => !_isInvoiceIssued(sale)).toList();
    
    if (unissuedSales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tất cả các hóa đơn đã được phát hành'),
          backgroundColor: Colors.blue,
        ),
      );
      return;
    }

    // Xác nhận phát hành hàng loạt
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận phát hành hàng loạt'),
        content: Text(
          'Bạn có chắc chắn muốn phát hành ${unissuedSales.length} hóa đơn điện tử?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isBulkIssuing = true;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final firebaseService = FirebaseService();
      final shop = await firebaseService.getShopData(authProvider.user!.uid);
      
      if (shop == null || shop.einvoiceConfig == null) {
        throw Exception('Chưa cấu hình thông tin hóa đơn điện tử');
      }

      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );

      final einvoiceService = EinvoiceService();

      int successCount = 0;
      int failCount = 0;
      final errors = <String>[];

      for (final sale in unissuedSales) {
        try {
          await einvoiceService.createInvoice(
            sale: sale,
            shop: shop,
            salesService: salesService,
          );
          successCount++;
        } catch (e) {
          failCount++;
          errors.add('${sale.id.substring(0, 8)}: $e');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Phát hành hoàn tất: $successCount thành công, $failCount thất bại',
            ),
            backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Reload danh sách
      await _loadSales();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi phát hành hàng loạt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBulkIssuing = false;
          _selectedSaleIds.clear();
        });
      }
    }
  }

  /// Xem PDF hóa đơn điện tử
  Future<void> _viewInvoicePdf(SaleModel sale) async {
    if (sale.einvoiceUrl == null || sale.einvoiceUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có link xem hóa đơn'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(sale.einvoiceUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Không thể mở link');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi mở PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Toggle chọn/bỏ chọn hóa đơn
  void _toggleSaleSelection(String saleId) {
    setState(() {
      if (_selectedSaleIds.contains(saleId)) {
        _selectedSaleIds.remove(saleId);
      } else {
        _selectedSaleIds.add(saleId);
      }
    });
  }

  /// Bỏ chọn tất cả
  void _clearSelection() {
    setState(() {
      _selectedSaleIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final double maxWidth = isDesktop ? 1200 : 800;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Quản lý hóa đơn điện tử'),
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
                    const Text(
                      'Quản lý hóa đơn điện tử',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Row(
                      children: [
                        if (_selectedSaleIds.isNotEmpty) ...[
                          OutlinedButton.icon(
                            onPressed: _isBulkIssuing ? null : _bulkIssueInvoices,
                            icon: _isBulkIssuing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send, size: 18),
                            label: Text(
                              _isBulkIssuing
                                  ? 'Đang phát hành...'
                                  : 'Phát hành (${_selectedSaleIds.length})',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _clearSelection,
                            child: const Text('Bỏ chọn'),
                          ),
                          const SizedBox(width: 8),
                        ],
                        ElevatedButton.icon(
                          onPressed: _loadSales,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Tải lại'),
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
                // Filters
                Row(
                  children: [
                    // Bộ lọc thời gian
                    Expanded(
                      child: DateRangeFilter(
                        startDate: _startDate,
                        endDate: _endDate,
                        onStartDateChanged: (date) {
                          setState(() {
                            _startDate = date;
                          });
                          _loadSales();
                        },
                        onEndDateChanged: (date) {
                          setState(() {
                            _endDate = date;
                          });
                          _loadSales();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Bộ lọc chi nhánh
                    Consumer<BranchProvider>(
                      builder: (context, branchProvider, child) {
                        final branches = branchProvider.branches.where((b) => b.isActive).toList();
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
                                _loadSales();
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Summary
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.receipt,
                        iconColor: Colors.blue,
                        iconBg: Colors.blue.shade50,
                        label: 'Tổng số hóa đơn',
                        value: _sales.length.toString(),
                        suffix: 'đơn',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.check_circle,
                        iconColor: Colors.green,
                        iconBg: Colors.green.shade50,
                        label: 'Đã xuất HĐĐT',
                        value: _sales.where((s) => _isInvoiceIssued(s)).length.toString(),
                        suffix: 'đơn',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.pending,
                        iconColor: Colors.orange,
                        iconBg: Colors.orange.shade50,
                        label: 'Chưa xuất HĐĐT',
                        value: _sales.where((s) => !_isInvoiceIssued(s)).length.toString(),
                        suffix: 'đơn',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                              onPressed: _loadSales,
                              child: const Text('Thử lại'),
                            ),
                          ],
                        ),
                      )
                    : _sales.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long,
                                    size: 64, color: Colors.grey.shade300),
                                const SizedBox(height: 16),
                                Text(
                                  'Không có hóa đơn trong kỳ báo cáo',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor:
                                    WidgetStateProperty.all(Colors.grey.shade50),
                                columnSpacing: 16,
                                columns: [
                                  const DataColumn(
                                    label: SizedBox(width: 40, child: Icon(Icons.check_box_outline_blank, size: 20)),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Mã đơn',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Ngày bán',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Khách hàng',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Tổng tiền',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    numeric: true,
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Trạng thái HĐĐT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: Text(
                                      'Số HĐĐT',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                  const DataColumn(
                                    label: SizedBox(width: 100),
                                  ),
                                ],
                                rows: _sales.map((sale) {
                                  final isIssued = _isInvoiceIssued(sale);
                                  final isSelected = _selectedSaleIds.contains(sale.id);
                                  
                                  return DataRow(
                                    selected: isSelected,
                                    onSelectChanged: !isIssued
                                        ? (selected) {
                                            _toggleSaleSelection(sale.id);
                                          }
                                        : null,
                                    cells: [
                                      DataCell(
                                        !isIssued
                                            ? Checkbox(
                                                value: isSelected,
                                                onChanged: (value) {
                                                  _toggleSaleSelection(sale.id);
                                                },
                                              )
                                            : const SizedBox(width: 40),
                                      ),
                                      DataCell(
                                        Text(
                                          sale.id.substring(0, 8).toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF3B82F6),
                                          ),
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => SaleDetailScreen(sale: sale),
                                            ),
                                          );
                                        },
                                      ),
                                      DataCell(
                                        Text(
                                          DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          sale.customerName ?? 'Khách lẻ',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          NumberFormat.currency(
                                            locale: 'vi_VN',
                                            symbol: '₫',
                                          ).format(sale.totalAmount),
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      DataCell(
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isIssued
                                                ? Colors.green.shade50
                                                : Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(999),
                                            border: Border.all(
                                              color: isIssued
                                                  ? Colors.green.shade300
                                                  : Colors.orange.shade300,
                                            ),
                                          ),
                                          child: Text(
                                            isIssued ? 'Đã xuất' : 'Chưa xuất',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isIssued
                                                  ? Colors.green.shade700
                                                  : Colors.orange.shade700,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataCell(
                                        Text(
                                          sale.invoiceNo ?? '-',
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                      ),
                                      DataCell(
                                        isIssued
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                                                    color: Colors.red,
                                                    onPressed: () => _viewInvoicePdf(sale),
                                                    tooltip: 'Xem PDF',
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.open_in_new, size: 18),
                                                    color: Colors.blue,
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) => SaleDetailScreen(sale: sale),
                                                        ),
                                                      );
                                                    },
                                                    tooltip: 'Xem chi tiết',
                                                  ),
                                                ],
                                              )
                                            : const SizedBox(width: 100),
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
    );
  }
}

/// Stat Card Widget
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;
  final String suffix;

  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade500,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      suffix,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
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
