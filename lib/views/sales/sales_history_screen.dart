import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/sale_model.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../services/sales_service.dart';
import '../../services/product_service.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';
import 'sale_detail_screen.dart';

/// Màn hình hiển thị lịch sử đơn hàng đã bán (mobile/desktop theo platform).
class SalesHistoryScreen extends StatelessWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const SalesHistoryScreen({super.key, this.forceMobile});

  @override
  Widget build(BuildContext context) {
    final useMobileLayout = forceMobile ?? isMobilePlatform;

    return Scaffold(
      appBar: isDesktopPlatform
          ? null
          : AppBar(
              title: const Text('Quản lý đơn hàng'),
            ),
      body: _SalesHistoryContent(useMobileLayout: useMobileLayout),
    );
  }
}

class _SalesHistoryContent extends StatefulWidget {
  final bool useMobileLayout;

  const _SalesHistoryContent({required this.useMobileLayout});

  @override
  State<_SalesHistoryContent> createState() => _SalesHistoryContentState();
}

/// Các lựa chọn khoảng thời gian hiển thị
enum _TimeRangeKey {
  today,
  week,
  month,
  all,
  custom,
}

class _SalesHistoryContentState extends State<_SalesHistoryContent> {
  List<SaleModel> _sales = [];
  bool _isLoading = true;
  String? _errorMessage;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';

  /// Khoảng thời gian hiển thị
  _TimeRangeKey _timeRange = _TimeRangeKey.week;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _loadSales();
  }

  /// Trả về (startDate, endDate) theo khoảng thời gian đã chọn. endDate là cuối ngày (23:59:59).
  (DateTime?, DateTime?) _getDateRange() {
    final now = DateTime.now();
    switch (_timeRange) {
      case _TimeRangeKey.today:
        final start = DateTime(now.year, now.month, now.day);
        final end = start.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
        return (start, end);
      case _TimeRangeKey.week:
        final start = now.subtract(const Duration(days: 6));
        final startOfStart = DateTime(start.year, start.month, start.day);
        final end = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        return (startOfStart, end);
      case _TimeRangeKey.month:
        final start = now.subtract(const Duration(days: 29));
        final startOfStart = DateTime(start.year, start.month, start.day);
        final end = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        return (startOfStart, end);
      case _TimeRangeKey.all:
        return (null, null);
      case _TimeRangeKey.custom:
        if (_customStart == null || _customEnd == null) return (null, null);
        final endOfDay = DateTime(_customEnd!.year, _customEnd!.month, _customEnd!.day)
            .add(const Duration(days: 1))
            .subtract(const Duration(milliseconds: 1));
        return (_customStart, endOfDay);
    }
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 6)),
              end: now,
            ),
      locale: const Locale('vi'),
      helpText: 'Chọn khoảng thời gian',
    );
    if (picked != null && mounted) {
      setState(() {
        _timeRange = _TimeRangeKey.custom;
        _customStart = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _customEnd = DateTime(picked.end.year, picked.end.month, picked.end.day);
      });
      _loadSales();
    }
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

      final (startDate, endDate) = _getDateRange();
      final sales = await salesService.getSales(
        startDate: startDate,
        endDate: endDate,
      );
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
    final useMobile = widget.useMobileLayout;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        double maxWidth;
        if (useMobile) {
          maxWidth = screenWidth;
        } else if (screenWidth < kBreakpointTablet) {
          maxWidth = 900;
        } else {
          maxWidth = kBreakpointTablet;
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
                      _HeaderSection(onRefresh: _loadSales, isMobile: widget.useMobileLayout),
                      const SizedBox(height: 16),
                      _TimeRangeSelector(
                        selected: _timeRange,
                        customStart: _customStart,
                        customEnd: _customEnd,
                        onSelected: (key) {
                          setState(() => _timeRange = key);
                          _loadSales();
                        },
                        onCustomPick: _pickCustomDateRange,
                        isMobile: widget.useMobileLayout,
                      ),
                      const SizedBox(height: 16),
                      _SummaryCards(
                        isLoading: _isLoading,
                        errorMessage: _errorMessage,
                        stats: _getOrderStats(),
                        isMobile: widget.useMobileLayout,
                      ),
                    ],
                  ),
                ),
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
                      isMobile: widget.useMobileLayout,
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
  final bool isMobile;

  const _HeaderSection({required this.onRefresh, required this.isMobile});

  @override
  Widget build(BuildContext context) {
    final onMobile = isMobile;
    final buttons = Row(
      mainAxisSize: MainAxisSize.min,
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
    );

    if (onMobile) {
      // Mobile: AppBar đã có title "Quản lý đơn hàng", chỉ hiển thị subtitle + nút (nút cuộn ngang nếu chật)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Theo dõi và xử lý đơn hàng.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: buttons,
          ),
        ],
      );
    }

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
        buttons,
      ],
    );
  }
}

/// Bộ chọn khoảng thời gian hiển thị danh sách hóa đơn (mobile: chips cuộn ngang, desktop: hàng chips).
class _TimeRangeSelector extends StatelessWidget {
  final _TimeRangeKey selected;
  final DateTime? customStart;
  final DateTime? customEnd;
  final ValueChanged<_TimeRangeKey> onSelected;
  final VoidCallback onCustomPick;
  final bool isMobile;

  const _TimeRangeSelector({
    required this.selected,
    required this.customStart,
    required this.customEnd,
    required this.onSelected,
    required this.onCustomPick,
    required this.isMobile,
  });

  String _label(_TimeRangeKey key) {
    switch (key) {
      case _TimeRangeKey.today:
        return 'Hôm nay';
      case _TimeRangeKey.week:
        return '7 ngày qua';
      case _TimeRangeKey.month:
        return '30 ngày qua';
      case _TimeRangeKey.all:
        return 'Tất cả';
      case _TimeRangeKey.custom:
        if (customStart != null && customEnd != null) {
          return '${DateFormat('dd/MM').format(customStart!)} - ${DateFormat('dd/MM/yyyy').format(customEnd!)}';
        }
        return 'Tùy chọn';
    }
  }

  @override
  Widget build(BuildContext context) {
    const chipPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 10);
    final selectedBg = Colors.blue.shade600;
    final selectedFg = Colors.white;
    final unselectedBg = const Color(0xFFF1F5F9);
    final unselectedFg = const Color(0xFF64748B);

    Widget chip(_TimeRangeKey key, {bool isCustom = false}) {
      final isSelected = selected == key;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: FilterChip(
          label: Text(
            _label(key),
            style: TextStyle(
              fontSize: isMobile ? 13 : 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? selectedFg : unselectedFg,
            ),
          ),
          selected: isSelected,
          onSelected: isCustom
              ? (_) => onCustomPick()
              : (v) {
                  if (v) onSelected(key);
                },
          selectedColor: selectedBg,
          backgroundColor: unselectedBg,
          checkmarkColor: selectedFg,
          padding: chipPadding,
          side: BorderSide(
            color: isSelected ? selectedBg : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
      );
    }

    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!isMobile)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Text(
              'Khoảng thời gian:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        chip(_TimeRangeKey.today),
        chip(_TimeRangeKey.week),
        chip(_TimeRangeKey.month),
        chip(_TimeRangeKey.all),
        chip(_TimeRangeKey.custom, isCustom: true),
      ],
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Khoảng thời gian',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: row,
          ),
        ],
      );
    }

    return row;
  }
}

class _SummaryCards extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final Map<String, int> stats;
  final bool isMobile;

  const _SummaryCards({
    required this.isLoading,
    this.errorMessage,
    required this.stats,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    const cardMinWidth = 165.0;
    final cards = [
      _StatCard(
        icon: Icons.access_time,
        iconColor: const Color(0xFFF59E0B),
        iconBg: const Color(0xFFFFFBEB),
        label: 'Chờ xử lý',
        value: (isLoading || errorMessage != null) ? '...' : (stats['pending'] ?? 0).toString(),
        suffix: 'đơn',
      ),
      _StatCard(
        icon: Icons.local_shipping,
        iconColor: const Color(0xFF2563EB),
        iconBg: const Color(0xFFE0F2FE),
        label: 'Đang giao',
        value: (isLoading || errorMessage != null) ? '...' : (stats['delivering'] ?? 0).toString(),
        suffix: 'đơn',
      ),
      _StatCard(
        icon: Icons.check_circle,
        iconColor: const Color(0xFF059669),
        iconBg: const Color(0xFFD1FAE5),
        label: 'Đã hoàn thành',
        value: (isLoading || errorMessage != null) ? '...' : (stats['completed'] ?? 0).toString(),
        suffix: 'đơn',
      ),
      _StatCard(
        icon: Icons.cancel,
        iconColor: const Color(0xFF64748B),
        iconBg: const Color(0xFFF1F5F9),
        label: 'Đã hủy',
        value: (isLoading || errorMessage != null) ? '...' : (stats['cancelled'] ?? 0).toString(),
        suffix: 'đơn',
      ),
    ];

    if (isMobile) {
      // Mobile: cuộn ngang để mỗi card đủ rộng hiển thị đủ nội dung
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              SizedBox(
                width: cardMinWidth,
                child: cards[i],
              ),
            ],
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: cards[0]),
        const SizedBox(width: 12),
        Expanded(child: cards[1]),
        const SizedBox(width: 12),
        Expanded(child: cards[2]),
        const SizedBox(width: 12),
        Expanded(child: cards[3]),
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
  final bool isMobile;

  const _SalesTable({
    required this.sales,
    required this.isLoading,
    this.errorMessage,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.isMobile,
  });

  void _openSaleDetail(BuildContext context, SaleModel sale, {bool fullScreen = false}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: fullScreen,
        builder: (_) => SaleDetailScreen(sale: sale, forceMobile: isMobile),
      ),
    );
  }

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
                              if (isMobile) {
                                return _SalesListMobile(
                                  sales: sales,
                                  getOrderId: _getOrderId,
                                  onTapSale: (sale) => _openSaleDetail(context, sale, fullScreen: true),
                                );
                              }
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
                                            WidgetStateProperty.all(Colors.grey.shade50),
                                        columnSpacing: 16,
                                        columns: [
                                          DataColumn(
                                            label: SizedBox(
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
                                            label: SizedBox(
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
                                            label: SizedBox(
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
                                            label: SizedBox(
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
                                            label: SizedBox(
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
                                            label: SizedBox(
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
                                            label: SizedBox(
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
                                                _openSaleDetail(context, sale, fullScreen: false);
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
                                                        color: statusColor.withValues(alpha: 0.08),
                                                        borderRadius: BorderRadius.circular(999),
                                                        border: Border.all(
                                                          color: statusColor.withValues(alpha: 0.3),
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
                                                        _openSaleDetail(context, sale, fullScreen: false);
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

/// Danh sách đơn hàng dạng ListTile cho Mobile: mã đơn, ngày + khách hàng (subtitle), tổng tiền (trailing).
class _SalesListMobile extends StatelessWidget {
  final List<SaleModel> sales;
  final String Function(String id) getOrderId;
  final void Function(SaleModel sale) onTapSale;

  const _SalesListMobile({
    required this.sales,
    required this.getOrderId,
    required this.onTapSale,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        final orderId = getOrderId(sale.id);
        final dateStr = DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp);
        final customerName = sale.customerName ?? 'Khách lẻ';

        return ListTile(
          title: Text(
            orderId,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF3B82F6),
              fontSize: 15,
            ),
          ),
          subtitle: Text(
            '$dateStr\n$customerName',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.35,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(sale.totalAmount),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          onTap: () => onTapSale(sale),
        );
      },
    );
  }
}
