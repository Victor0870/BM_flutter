import 'dart:io' show Platform;
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/sale_model.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../services/sales_service.dart';
import '../../services/product_service.dart';
import 'sale_detail_screen.dart';

/// Màn hình hiển thị lịch sử đơn hàng đã bán với thiết kế mới
class SalesHistoryScreen extends StatelessWidget {
  const SalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    Widget mainContent = const _SalesHistoryContent();

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Quản lý đơn hàng'),
            ),
      body: mainContent,
    );
  }
}

class _SalesHistoryContent extends StatefulWidget {
  const _SalesHistoryContent();

  @override
  State<_SalesHistoryContent> createState() => _SalesHistoryContentState();
}

class _SalesHistoryContentState extends State<_SalesHistoryContent> {
  List<SaleModel> _sales = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _searchQuery = value;
      });
    });
  }

  List<SaleModel> _getFilteredSales() {
    if (_searchQuery.trim().isEmpty) {
      return _sales;
    }
    final query = _searchQuery.toLowerCase();
    return _sales.where((sale) {
      final orderId = _getOrderId(sale.id).toLowerCase();
      final customerName = (sale.customerName ?? 'Khách lẻ').toLowerCase();
      return orderId.contains(query) || customerName.contains(query);
    }).toList();
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

      final productService = ProductService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );
      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
        productService: productService,
      );

      final sales = await salesService.getSales();
      setState(() {
        _sales = sales;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tải lịch sử: $e';
        _isLoading = false;
      });
    }
  }

  String _getShortId(String id) {
    return id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  String _getOrderId(String id) {
    return 'ORD-${_getShortId(id)}';
  }

  Map<String, int> _getOrderStats() {
    int pending = 0;
    int completed = 0;
    int cancelled = 0;

    for (var sale in _sales) {
      if (sale.paymentStatus == 'COMPLETED') {
        completed++;
      } else if (sale.paymentStatus == 'PENDING') {
        pending++;
      } else {
        cancelled++;
      }
    }

    return {
      'pending': pending,
      'completed': completed,
      'cancelled': cancelled,
      'delivering': 0, // Có thể thêm sau
    };
  }

  @override
  Widget build(BuildContext context) {
    final filteredSales = _getFilteredSales();

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        // Xác định maxWidth dựa trên kích thước màn hình
        double maxWidth;
        if (screenWidth < 600) {
          // Mobile: full width
          maxWidth = screenWidth;
        } else if (screenWidth < 1200) {
          // Tablet: maxWidth = 900
          maxWidth = 900;
        } else {
          // Desktop: maxWidth = 1200
          maxWidth = 1200;
        }

        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                // Header và Summary Cards có padding
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Column(
                    children: [
                      _HeaderSection(onRefresh: _loadSales),
                      const SizedBox(height: 16),
                      _SummaryCards(
                        isLoading: _isLoading,
                        errorMessage: _errorMessage,
                        stats: _getOrderStats(),
                      ),
                    ],
                  ),
                ),
                // DataTable tràn toàn bộ chiều rộng trong maxWidth
                Expanded(
                  child: Card(
                    margin: EdgeInsets.zero,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(0),
                      side: BorderSide.none,
                    ),
                    child: _SalesTable(
                      sales: filteredSales,
                      isLoading: _isLoading,
                      errorMessage: _errorMessage,
                      searchController: _searchController,
                      onSearchChanged: _onSearchChanged,
                      onRefresh: () => _loadSales(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

}

class _HeaderSection extends StatelessWidget {
  final VoidCallback onRefresh;

  const _HeaderSection({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quản lý đơn hàng',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Theo dõi và xử lý đơn hàng.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Làm mới'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tính năng đang được phát triển')),
                );
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Xuất Excel'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, int> stats;

  const _SummaryCards({
    required this.isLoading,
    this.errorMessage,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.access_time,
            iconColor: const Color(0xFFF59E0B),
            iconBg: const Color(0xFFFFFBEB),
            label: 'Chờ xử lý',
            value: (isLoading || errorMessage != null) ? '...' : (stats['pending'] ?? 0).toString(),
            suffix: 'đơn',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.local_shipping,
            iconColor: const Color(0xFF2563EB),
            iconBg: const Color(0xFFE0F2FE),
            label: 'Đang giao',
            value: (isLoading || errorMessage != null) ? '...' : (stats['delivering'] ?? 0).toString(),
            suffix: 'đơn',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.check_circle,
            iconColor: const Color(0xFF059669),
            iconBg: const Color(0xFFD1FAE5),
            label: 'Đã hoàn thành',
            value: (isLoading || errorMessage != null) ? '...' : (stats['completed'] ?? 0).toString(),
            suffix: 'đơn',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.cancel,
            iconColor: const Color(0xFF64748B),
            iconBg: const Color(0xFFF1F5F9),
            label: 'Đã hủy',
            value: (isLoading || errorMessage != null) ? '...' : (stats['cancelled'] ?? 0).toString(),
            suffix: 'đơn',
          ),
        ),
      ],
    );
  }
}

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
          Column(
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
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
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
        ],
      ),
    );
  }
}

class _SalesTable extends StatelessWidget {
  final List<SaleModel> sales;
  final bool isLoading;
  final String? errorMessage;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;

  const _SalesTable({
    required this.sales,
    required this.isLoading,
    this.errorMessage,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
  });

  String _getOrderId(String id) {
    final shortId = id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
    return 'ORD-$shortId';
  }

  String _getStatusText(SaleModel sale) {
    if (sale.paymentStatus == 'COMPLETED') {
      return 'Hoàn thành';
    } else if (sale.paymentStatus == 'PENDING') {
      return 'Đang xử lý';
    }
    return 'Đang xử lý';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Hoàn thành':
        return const Color(0xFF059669);
      case 'Đang xử lý':
        return const Color(0xFFF59E0B);
      case 'Đã hủy':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Tìm theo mã đơn, tên khách hàng...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
            ),
            onChanged: onSearchChanged,
          ),
        ),
        const Divider(height: 1),
        // Data table
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
                          Text(
                            errorMessage!,
                            style: TextStyle(color: Colors.red[700]),
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
                                    Text(
                                      'Chưa có đơn hàng nào',
                                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                                    ),
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
                              // Sử dụng constraints.maxWidth để đảm bảo bảng đạt đúng maxWidth
                              final tableWidth = constraints.maxWidth;
                              
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: tableWidth,
                                  child: Consumer<BranchProvider>(
                                    builder: (context, branchProvider, _) {
                                      String getBranchName(String? branchId) {
                                        if (branchId == null || branchId.isEmpty) {
                                          return '';
                                        }
                                        try {
                                          final branch = branchProvider.branches.firstWhere(
                                            (b) => b.id == branchId,
                                          );
                                          return branch.name;
                                        } catch (e) {
                                          return '';
                                        }
                                      }

                                      return DataTable(
                                        showCheckboxColumn: false,
                                        headingRowColor:
                                            MaterialStateProperty.all(Colors.grey.shade50),
                                        columnSpacing: 16,
                                        columns: [
                                          DataColumn(
                                            label: Container(
                                              width: 80,
                                              child: const Text(
                                                'NGÀY BÁN',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF94A3B8),
                                                  letterSpacing: 0.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Container(
                                              width: 110,
                                              child: const Text(
                                                'MÃ ĐƠN',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF94A3B8),
                                                  letterSpacing: 0.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Container(
                                              width: 120,
                                              child: const Text(
                                                'KHÁCH HÀNG',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF94A3B8),
                                                  letterSpacing: 0.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Container(
                                              width: 110,
                                              child: const Text(
                                                'TỔNG CỘNG',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF94A3B8),
                                                  letterSpacing: 0.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            numeric: true,
                                          ),
                                          DataColumn(
                                            label: Container(
                                              width: 100,
                                              child: const Text(
                                                'NHÂN VIÊN',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF94A3B8),
                                                  letterSpacing: 0.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Container(
                                              width: 110,
                                              child: const Text(
                                                'CHI NHÁNH',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF94A3B8),
                                                  letterSpacing: 0.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Container(
                                              width: 120,
                                              child: const Text(
                                                'TRẠNG THÁI',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF94A3B8),
                                                  letterSpacing: 0.5,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                          DataColumn(
                                            label: Container(width: 50),
                                          ),
                                        ],
                                          rows: sales.map((sale) {
                                            final status = _getStatusText(sale);
                                            final statusColor = _getStatusColor(status);
                                            final orderId = _getOrderId(sale.id);
                                            final sellerName = sale.sellerName ?? '';
                                            final branchName = getBranchName(sale.branchId);

                                            return DataRow(
                                              onSelectChanged: (_) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (_) => SaleDetailScreen(sale: sale),
                                                  ),
                                                );
                                              },
                                              cells: [
                                                DataCell(
                                                  Center(
                                                    child: Text(
                                                      DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp),
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Center(
                                                    child: Text(
                                                      orderId,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF3B82F6),
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Center(
                                                    child: Text(
                                                      sale.customerName ?? 'Khách lẻ',
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.w600,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Center(
                                                    child: Text(
                                                      NumberFormat.currency(
                                                        locale: 'vi_VN',
                                                        symbol: '₫',
                                                      ).format(sale.totalAmount),
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight: FontWeight.bold,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Center(
                                                    child: Text(
                                                      sellerName,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Center(
                                                    child: Text(
                                                      branchName,
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                        color: Color(0xFF0F172A),
                                                      ),
                                                      textAlign: TextAlign.center,
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  Center(
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: statusColor.withOpacity(0.08),
                                                        borderRadius: BorderRadius.circular(999),
                                                        border: Border.all(
                                                          color: statusColor.withOpacity(0.3),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        status,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.bold,
                                                          color: statusColor,
                                                        ),
                                                        textAlign: TextAlign.center,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                DataCell(
                                                  SizedBox(
                                                    width: 50,
                                                    child: IconButton(
                                                      icon: const Icon(Icons.more_horiz, size: 18, color: Color(0xFFCBD5E1)),
                                                      onPressed: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) => SaleDetailScreen(sale: sale),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }
}
