import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../services/export_service.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';

/// Ngưỡng tồn kho thấp: sản phẩm có tồn < [threshold] sẽ được liệt kê.
const int kLowStockThreshold = 5;

/// Báo cáo sản phẩm sắp hết hàng (tồn kho < 5 hoặc dưới ngưỡng).
/// Giao diện chuyên nghiệp, hỗ trợ xuất PDF.
class LowStockReportScreen extends StatefulWidget {
  final bool? forceMobile;

  const LowStockReportScreen({super.key, this.forceMobile});

  @override
  State<LowStockReportScreen> createState() => _LowStockReportScreenState();
}

class _LowStockReportScreenState extends State<LowStockReportScreen> {
  List<ProductModel> _lowStockProducts = [];
  bool _isLoading = true;
  String? _error;
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReport());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final branchId = context.read<BranchProvider>().currentBranchId;
    if (_selectedBranchId != branchId) {
      _selectedBranchId = branchId;
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final branchId = context.read<BranchProvider>().currentBranchId;
      final productService = ProductService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );
      final products = await productService.getProducts(
        includeInactive: false,
        activeBranchId: branchId,
      );

      final lowStock = <ProductModel>[];
      for (final p in products) {
        final onHand = _getOnHandForBranch(p, branchId);
        final threshold = p.minStock != null && p.minStock! > 0
            ? p.minStock!.toInt()
            : kLowStockThreshold;
        if (onHand < threshold) {
          lowStock.add(p);
        }
      }
      lowStock.sort((a, b) {
        final aHand = _getOnHandForBranch(a, branchId);
        final bHand = _getOnHandForBranch(b, branchId);
        return aHand.compareTo(bHand);
      });

      if (mounted) {
        setState(() {
          _lowStockProducts = lowStock;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  double _getOnHandForBranch(ProductModel p, String? branchId) {
    if (branchId != null && branchId.isNotEmpty) {
      if (p.variants.isNotEmpty) {
        return p.variants.fold<double>(
            0.0, (sum, v) => sum + (v.branchStock[branchId] ?? 0));
      }
      return p.branchStock[branchId] ?? 0;
    }
    return p.stock;
  }

  Future<void> _exportPdf() async {
    if (_lowStockProducts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không có dữ liệu để xuất PDF'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    final branchId = context.read<BranchProvider>().currentBranchId;
    final branchName = _getBranchName(context, branchId);
    final subtitle = branchName != null && branchName.isNotEmpty
        ? 'Chi nhánh: $branchName'
        : null;

    final headers = ['Mã SP', 'Tên sản phẩm', 'Tồn kho', 'Đơn vị', 'Giá vốn (₫)'];
    final rows = _lowStockProducts.map((p) {
      final onHand = _getOnHandForBranch(p, branchId);
      return [
        p.code ?? p.id.substring(0, 8),
        p.name,
        NumberFormat('#,##0.##').format(onHand),
        p.unit,
        NumberFormat('#,##0').format(p.importPrice),
      ];
    }).toList();
    final summaryText =
        'Tổng số sản phẩm sắp hết hàng: ${_lowStockProducts.length}';
    final suggestedFileName =
        'Bao_cao_ton_kho_thap_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}';

    try {
      final result = await ExportService.instance.exportToPdf(
        title: 'BÁO CÁO SẢN PHẨM SẮP HẾT HÀNG',
        subtitle: subtitle,
        headers: headers,
        rows: rows,
        summaryText: summaryText,
        suggestedFileName: suggestedFileName,
      );
      if (!mounted) return;
      _showExportSnackBar(result, isPdf: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi xuất PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showExportSnackBar(ExportResult result, {bool isPdf = false}) {
    if (result.savedFilePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã xuất ${isPdf ? 'PDF' : 'Excel'}: ${result.suggestedFileName}'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'File đã tạo: ${result.suggestedFileName}. Trên web dùng In → Lưu PDF hoặc tải về.',
          ),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  String? _getBranchName(BuildContext context, String? branchId) {
    if (branchId == null || branchId.isEmpty) return null;
    try {
      final branches = context.read<BranchProvider>().branches;
      final b = branches.firstWhere((e) => e.id == branchId);
      return b.name;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopPlatform && (widget.forceMobile != true);
    final maxWidth = isDesktop ? 1200.0 : 800.0;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Báo cáo tồn kho thấp'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _loadReport,
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf),
                  onPressed: _isLoading || _lowStockProducts.isEmpty
                      ? null
                      : _exportPdf,
                  tooltip: 'Xuất PDF',
                ),
              ],
            ),
      body: Column(
        children: [
          ResponsiveContainer(
            maxWidth: maxWidth,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Báo cáo sản phẩm sắp hết hàng',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sản phẩm có tồn kho dưới ngưỡng ($kLowStockThreshold) — nên nhập thêm.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: _isLoading ? null : _loadReport,
                          tooltip: 'Tải lại',
                        ),
                        FilledButton.icon(
                          onPressed: _isLoading || _lowStockProducts.isEmpty
                              ? null
                              : _exportPdf,
                          icon: const Icon(Icons.picture_as_pdf, size: 20),
                          label: const Text('Xuất PDF'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0EA5E9),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _loadReport,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                else
                  _buildContent(context, branchId: _selectedBranchId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, {String? branchId}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: Colors.amber.shade800,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tổng số sản phẩm cần nhập hàng',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_lowStockProducts.length}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_lowStockProducts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(48),
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Không có sản phẩm nào sắp hết hàng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tất cả sản phẩm đều đủ tồn kho.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                columnSpacing: 24,
                columns: const [
                  DataColumn(
                    label: Text(
                      'MÃ SP',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'TÊN SẢN PHẨM',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'TỒN KHO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    numeric: true,
                  ),
                  DataColumn(
                    label: Text(
                      'ĐƠN VỊ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'GIÁ VỐN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                    numeric: true,
                  ),
                ],
                rows: _lowStockProducts.map((p) {
                  final onHand = _getOnHandForBranch(p, branchId);
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          p.code ?? p.id.substring(0, 8),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0EA5E9),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: onHand < 2
                                ? Colors.red.shade50
                                : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: onHand < 2
                                  ? Colors.red.shade200
                                  : Colors.amber.shade200,
                            ),
                          ),
                          child: Text(
                            NumberFormat('#,##0.##').format(onHand),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: onHand < 2
                                  ? Colors.red.shade700
                                  : Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          p.unit,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          NumberFormat.currency(
                                  locale: 'vi_VN', symbol: '₫')
                              .format(p.importPrice),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
