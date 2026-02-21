import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../models/product_model.dart';
import '../../services/product_service.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';

/// Số ngày cảnh báo: lô hàng còn dưới [days] ngày hết hạn sẽ được liệt kê.
const int kExpiryWarningDays = 30;

/// Một dòng báo cáo: sản phẩm + lô sắp hết hạn.
class ExpiryReportRow {
  final ProductModel product;
  final ProductBatchExpire batch;

  ExpiryReportRow({required this.product, required this.batch});

  int get daysUntilExpiry {
    if (batch.expireDate == null) return 999;
    return batch.expireDate!.difference(DateTime.now()).inDays;
  }
}

/// Báo cáo hàng sắp hết hạn (KiotViet 2.4.1, 2.12.1 — Batch & Expire).
/// Cảnh báo chủ cửa hàng những lô còn dưới 30 ngày sử dụng.
class ExpiryReportScreen extends StatefulWidget {
  final bool? forceMobile;

  const ExpiryReportScreen({super.key, this.forceMobile});

  @override
  State<ExpiryReportScreen> createState() => _ExpiryReportScreenState();
}

class _ExpiryReportScreenState extends State<ExpiryReportScreen> {
  List<ExpiryReportRow> _rows = [];
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

      final now = DateTime.now();
      final cutoff = now.add(const Duration(days: kExpiryWarningDays));
      final list = <ExpiryReportRow>[];

      for (final p in products) {
        if (!p.isBatchExpireControl || p.batchExpires.isEmpty) continue;
        for (final b in p.batchExpires) {
          if (b.expireDate == null) continue;
          if (branchId != null && branchId.isNotEmpty && b.branchId != branchId) continue;
          if (b.onHand <= 0) continue;
          if (b.expireDate!.isBefore(now)) continue; // Đã hết hạn
          if (b.expireDate!.isAfter(cutoff)) continue; // Còn > 30 ngày
          list.add(ExpiryReportRow(product: p, batch: b));
        }
      }
      list.sort((a, b) => (a.batch.expireDate ?? DateTime.now())
          .compareTo(b.batch.expireDate ?? DateTime.now()));

      if (mounted) {
        setState(() {
          _rows = list;
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = isDesktopPlatform && (widget.forceMobile != true);
    final maxWidth = isDesktop ? 1200.0 : 800.0;

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Hàng sắp hết hạn'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _loadReport,
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
                          'Báo cáo hàng sắp hết hạn',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cảnh báo lô hàng còn dưới $kExpiryWarningDays ngày sử dụng — Dược, Thực phẩm.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _isLoading ? null : _loadReport,
                      tooltip: 'Tải lại',
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
                  _buildContent(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
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
              color: const Color(0xFFFEF3C7),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(
                bottom: BorderSide(color: Colors.amber.shade200),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.event_busy,
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
                        'Số lô hàng sắp hết hạn (dưới $kExpiryWarningDays ngày)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_rows.length}',
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
          if (_rows.isEmpty)
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
                    'Không có lô hàng nào sắp hết hạn',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tất cả lô hàng đều còn hạn sử dụng trên $kExpiryWarningDays ngày.',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
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
                      'SẢN PHẨM',
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
                      'MÃ LÔ',
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
                      'HẠN SỬ DỤNG',
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
                      'CÒN (NGÀY)',
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
                      'TỒN LÔ',
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
                rows: _rows.map((row) {
                  final days = row.daysUntilExpiry;
                  final isUrgent = days <= 7;
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          row.product.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DataCell(
                        Text(
                          row.batch.batchName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0EA5E9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.batch.expireDate != null
                              ? DateFormat('dd/MM/yyyy').format(row.batch.expireDate!)
                              : '—',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isUrgent ? Colors.red.shade50 : Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isUrgent ? Colors.red.shade200 : Colors.amber.shade200,
                            ),
                          ),
                          child: Text(
                            '$days',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isUrgent ? Colors.red.shade700 : Colors.amber.shade800,
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          row.batch.onHand.toStringAsFixed(0),
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
