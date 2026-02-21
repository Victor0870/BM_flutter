import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/sale_model.dart';
import '../../utils/platform_utils.dart';
import 'sales_history_screen_data.dart';
import 'sale_detail_screen.dart';

/// Màn hình Quản lý hóa đơn - giao diện Mobile (header gọn, bộ lọc chi tiết trong màn "Bộ lọc").
class SalesHistoryScreenMobile extends StatelessWidget {
  const SalesHistoryScreenMobile({
    super.key,
    required this.snapshot,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onTimeRangeSelected,
    required this.onCustomPick,
    required this.onBranchChanged,
    required this.onSellerChanged,
    required this.onStatusChanged,
    required this.onOpenFilter,
    required this.onLoadMore,
  });

  final SalesHistorySnapshot snapshot;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;
  final ValueChanged<SalesHistoryTimeRangeKey> onTimeRangeSelected;
  final VoidCallback onCustomPick;
  final ValueChanged<String?> onBranchChanged;
  final ValueChanged<String?> onSellerChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onOpenFilter;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktopPlatform
          ? null
          : AppBar(
              title: const Text('Quản lý đơn hàng'),
              actions: [
                IconButton(icon: const Icon(Icons.refresh), onPressed: onRefresh),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: onOpenFilter,
                  tooltip: 'Bộ lọc',
                ),
              ],
            ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CompactFilterRow(
                          snapshot: snapshot,
                          onTimeRangeSelected: onTimeRangeSelected,
                          onCustomPick: onCustomPick,
                          onBranchChanged: onBranchChanged,
                        ),
                        const SizedBox(height: 10),
                        _SummaryLine(
                          isLoading: snapshot.isLoading,
                          errorMessage: snapshot.errorMessage,
                          summary: snapshot.invoiceSummary,
                          count: snapshot.filteredSales.length,
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
                      child: _SalesTableMobile(
                        sales: snapshot.filteredSales,
                        isLoading: snapshot.isLoading,
                        errorMessage: snapshot.errorMessage,
                        searchController: searchController,
                        onSearchChanged: onSearchChanged,
                        onRefresh: onRefresh,
                        hasMore: snapshot.hasMore,
                        isLoadingMore: snapshot.isLoadingMore,
                        onLoadMore: onLoadMore,
                        getOrderId: snapshot.getOrderId,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Hàng lọc gọn: khoảng thời gian + chi nhánh (nhân viên/trạng thái trong màn Bộ lọc).
class _CompactFilterRow extends StatelessWidget {
  const _CompactFilterRow({
    required this.snapshot,
    required this.onTimeRangeSelected,
    required this.onCustomPick,
    required this.onBranchChanged,
  });

  final SalesHistorySnapshot snapshot;
  final ValueChanged<SalesHistoryTimeRangeKey> onTimeRangeSelected;
  final VoidCallback onCustomPick;
  final ValueChanged<String?> onBranchChanged;

  String _timeLabel(SalesHistoryTimeRangeKey key) {
    switch (key) {
      case SalesHistoryTimeRangeKey.today:
        return 'Hôm nay';
      case SalesHistoryTimeRangeKey.week:
        return '7 ngày qua';
      case SalesHistoryTimeRangeKey.month:
        return '30 ngày qua';
      case SalesHistoryTimeRangeKey.all:
        return 'Tất cả';
      case SalesHistoryTimeRangeKey.custom:
        if (snapshot.customStart != null && snapshot.customEnd != null) {
          return '${DateFormat('dd/MM').format(snapshot.customStart!)} - ${DateFormat('dd/MM').format(snapshot.customEnd!)}';
        }
        return 'Tùy chọn';
    }
  }

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    );
    return Row(
      children: [
        Expanded(
          child: _TimeDropDown(
            value: snapshot.timeRange,
            label: _timeLabel(snapshot.timeRange),
            onTimeRangeSelected: onTimeRangeSelected,
            onCustomPick: onCustomPick,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: DropdownButtonFormField<String?>(
            initialValue: snapshot.filterBranchId,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: border,
              enabledBorder: border,
              filled: true,
              fillColor: Colors.white,
            ),
            isExpanded: true,
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Tất cả chi nhánh')),
              ...snapshot.branches.map((b) => DropdownMenuItem<String?>(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: onBranchChanged,
          ),
        ),
      ],
    );
  }
}

class _TimeDropDown extends StatelessWidget {
  const _TimeDropDown({
    required this.value,
    required this.label,
    required this.onTimeRangeSelected,
    required this.onCustomPick,
  });

  final SalesHistoryTimeRangeKey value;
  final String label;
  final ValueChanged<SalesHistoryTimeRangeKey> onTimeRangeSelected;
  final VoidCallback onCustomPick;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
    );
    return InkWell(
      onTap: () => _showTimeMenu(context),
      borderRadius: BorderRadius.circular(20),
      child: InputDecorator(
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          border: border,
          enabledBorder: border,
          suffixIcon: const Icon(Icons.keyboard_arrow_down, size: 20),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  void _showTimeMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Hôm nay'),
              onTap: () {
                Navigator.pop(ctx);
                onTimeRangeSelected(SalesHistoryTimeRangeKey.today);
              },
            ),
            ListTile(
              title: const Text('7 ngày qua'),
              onTap: () {
                Navigator.pop(ctx);
                onTimeRangeSelected(SalesHistoryTimeRangeKey.week);
              },
            ),
            ListTile(
              title: const Text('30 ngày qua'),
              onTap: () {
                Navigator.pop(ctx);
                onTimeRangeSelected(SalesHistoryTimeRangeKey.month);
              },
            ),
            ListTile(
              title: const Text('Tất cả'),
              onTap: () {
                Navigator.pop(ctx);
                onTimeRangeSelected(SalesHistoryTimeRangeKey.all);
              },
            ),
            ListTile(
              title: const Text('Tùy chỉnh'),
              onTap: () {
                Navigator.pop(ctx);
                onCustomPick();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Một dòng tóm tắt: Tổng tiền hàng + số hóa đơn.
class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.isLoading,
    this.errorMessage,
    required this.summary,
    required this.count,
  });

  final bool isLoading;
  final String? errorMessage;
  final ({double totalGoods, double totalDiscount, double totalPaid}) summary;
  final int count;

  @override
  Widget build(BuildContext context) {
    final totalStr = (isLoading || errorMessage != null)
        ? '...'
        : NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0).format(summary.totalGoods);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Tổng tiền hàng',
          style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
        ),
        Row(
          children: [
            Text(
              totalStr,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(width: 8),
            Text(
              '$count hóa đơn',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      ],
    );
  }
}

class _SalesTableMobile extends StatelessWidget {
  final List<SaleModel> sales;
  final bool isLoading;
  final String? errorMessage;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function() onRefresh;
  final bool hasMore;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final String Function(String id) getOrderId;

  const _SalesTableMobile({
    required this.sales,
    required this.isLoading,
    this.errorMessage,
    required this.searchController,
    required this.onSearchChanged,
    required this.onRefresh,
    this.hasMore = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    required this.getOrderId,
  });

  void _openSaleDetail(BuildContext context, SaleModel sale) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => SaleDetailScreen(sale: sale, forceMobile: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: TextField(
            controller: searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Tìm theo mã đơn, tên khách hàng...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
            onChanged: onSearchChanged,
          ),
        ),
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
                                    Text('Chưa có đơn hàng nào', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: onRefresh,
                          child: Column(
                            children: [
                              Expanded(
                                child: ListView.builder(
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
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF3B82F6), fontSize: 15),
                                      ),
                                      subtitle: Text(
                                        '$dateStr\n$customerName',
                                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.35),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Text(
                                        NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(sale.totalAmount),
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                      ),
                                      onTap: () => _openSaleDetail(context, sale),
                                    );
                                  },
                                ),
                              ),
                              if (hasMore && onLoadMore != null)
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Center(
                                    child: isLoadingMore
                                        ? const SizedBox(height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2))
                                        : TextButton.icon(
                                            onPressed: onLoadMore,
                                            icon: const Icon(Icons.add_circle_outline, size: 18),
                                            label: const Text('Tải thêm'),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        ),
        ),
      ],
    );
  }
}
