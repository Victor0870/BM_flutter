import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/product_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../models/product_model.dart';
import '../../models/branch_model.dart';
import '../../core/routes.dart';
import '_stock_count_dialog.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/ad_banner_widget.dart';


class StockOverviewScreen extends StatelessWidget {
  const StockOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool useMobileLayout = isMobile(context);

    return Scaffold(
      appBar: useMobileLayout
          ? AppBar(
              title: const Text('Quản lý tồn kho'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.history),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.purchaseHistory);
                  },
                  tooltip: 'Lịch sử nhập kho',
                ),
              ],
            )
          : null,
      body: const _StockOverviewContent(),
    );
  }
}

class _StockOverviewContent extends StatefulWidget {
  const _StockOverviewContent();

  @override
  State<_StockOverviewContent> createState() => _StockOverviewContentState();
}

class _StockOverviewContentState extends State<_StockOverviewContent> {
  String? _selectedBranchId; // null = tất cả chi nhánh
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String? _selectedCategoryId;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      final productProvider = context.read<ProductProvider>();
      if (value.trim().isEmpty) {
        productProvider.clearSearch();
      } else {
        productProvider.searchProducts(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobileLayout = isMobile(context);
    final double maxWidth = isMobileLayout ? kContentMaxWidth : kBreakpointTablet;

    final headerAndCards = ResponsiveContainer(
      maxWidth: maxWidth,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: isMobileLayout ? 4 : 16,
        bottom: isMobileLayout ? 16 : 12,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HeaderSection(
            isMobile: isMobileLayout,
            selectedBranchId: _selectedBranchId,
            onBranchChanged: (branchId) {
              setState(() {
                _selectedBranchId = branchId;
              });
            },
            onStockCountPressed: () {
              _showStockCountDialog(context, _selectedBranchId);
            },
            searchController: isMobileLayout ? null : _searchController,
            onSearchChanged: isMobileLayout ? null : _onSearchChanged,
            selectedCategoryId: isMobileLayout ? null : _selectedCategoryId,
            onCategoryChanged: isMobileLayout
                ? null
                : (categoryId) {
                    setState(() {
                      _selectedCategoryId = categoryId;
                    });
                  },
          ),
          if (isMobileLayout) ...[
            const SizedBox(height: 12),
            _SummaryCards(
              selectedBranchId: _selectedBranchId,
              isMobile: true,
            ),
          ],
        ],
      ),
    );

    final tableSection = Card(
      margin: EdgeInsets.zero,
      elevation: isMobileLayout ? 0 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: BorderSide.none,
      ),
      child: _InventoryTable(
        selectedBranchId: _selectedBranchId,
        searchController: _searchController,
        onSearchChanged: _onSearchChanged,
        selectedCategoryId: _selectedCategoryId,
        onCategoryChanged: (categoryId) {
          setState(() {
            _selectedCategoryId = categoryId;
          });
        },
        isMobile: isMobileLayout,
        showSearchBar: isMobileLayout,
      ),
    );

    if (isMobileLayout) {
      // Mobile: header + thẻ thống kê + danh sách cuộn được, ad cố định ở đáy (giống product_list_screen)
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          headerAndCards,
          Expanded(
            child: SingleChildScrollView(
              child: tableSection,
            ),
          ),
          const SafeArea(top: false, child: AdBannerWidget()),
        ],
      );
    }

    // Desktop: layout giống Danh sách sản phẩm — header + bảng list full, ad ở đáy
    return Column(
      children: [
        headerAndCards,
        Expanded(
          child: tableSection,
        ),
        const SafeArea(
          top: false,
          child: AdBannerWidget(),
        ),
      ],
    );
  }

  /// Hiển thị Dialog kiểm kê kho
  void _showStockCountDialog(BuildContext context, String? selectedBranchId) {
    showDialog(
      context: context,
      builder: (dialogContext) => StockCountDialog(
        selectedBranchId: selectedBranchId,
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final bool isMobile;
  final String? selectedBranchId;
  final ValueChanged<String?> onBranchChanged;
  final VoidCallback onStockCountPressed;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final String? selectedCategoryId;
  final ValueChanged<String?>? onCategoryChanged;

  const _HeaderSection({
    required this.isMobile,
    required this.selectedBranchId,
    required this.onBranchChanged,
    required this.onStockCountPressed,
    this.searchController,
    this.onSearchChanged,
    this.selectedCategoryId,
    this.onCategoryChanged,
  });

  @override
  Widget build(BuildContext context) {
    final actions = Row(
      children: [
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
              width: isMobile ? double.infinity : 200,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButton<String?>(
                  value: selectedBranchId,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: items,
                  onChanged: onBranchChanged,
                ),
              ),
            );
          },
        ),
        if (!isMobile) const SizedBox(width: 12),
        if (!isMobile)
          OutlinedButton.icon(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.purchase),
            icon: const Icon(Icons.arrow_downward, size: 18),
            label: const Text('Nhập kho'),
          ),
        if (!isMobile) const SizedBox(width: 8),
        if (!isMobile)
          ElevatedButton.icon(
            onPressed: onStockCountPressed,
            icon: const Icon(Icons.checklist_rtl, size: 18),
            label: const Text('Kiểm kê kho'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
          ),
      ],
    );

    final titleSection = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quản lý tồn kho',
          style: TextStyle(
            fontSize: isMobile ? 20 : 24,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Quản lý số lượng, vị trí và giá trị hàng hóa trong kho.',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );

    // Mobile: Hai nút ngay dưới AppBar (bỏ khoảng trống), dropdown chi nhánh bên dưới.
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, AppRoutes.purchase),
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  label: const Text('Nhập kho'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onStockCountPressed,
                  icon: const Icon(Icons.checklist_rtl, size: 18),
                  label: const Text('Kiểm kê kho'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          actions,
        ],
      );
    }

    // Desktop: hàng 1 = title + actions, hàng 2 = tìm kiếm + nhóm hàng (giống Danh sách sản phẩm)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            titleSection,
            actions,
          ],
        ),
        if (searchController != null && onSearchChanged != null && onCategoryChanged != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Tìm theo SKU, tên sản phẩm...',
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
              const SizedBox(width: 12),
              Consumer<ProductProvider>(
                builder: (context, productProvider, child) {
                  if (productProvider.categories.isEmpty && !productProvider.isLoadingCategories) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      productProvider.loadCategories();
                    });
                  }
                  final categories = productProvider.categories;
                  return Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButton<String?>(
                        value: selectedCategoryId,
                        isExpanded: true,
                        underline: const SizedBox(),
                        hint: const Text('Nhóm hàng'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tất cả'),
                          ),
                          ...categories.map(
                            (c) => DropdownMenuItem<String?>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: onCategoryChanged,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _SummaryCards extends StatelessWidget {
  final String? selectedBranchId;
  final bool isMobile;

  const _SummaryCards({
    required this.selectedBranchId,
    this.isMobile = false,
  });

  static double _getStockForProduct(ProductModel product, String? branchId) {
    if (branchId == null || branchId.isEmpty) {
      return product.stock;
    }
    if (product.variants.isNotEmpty) {
      double total = 0;
      for (final variant in product.variants) {
        total += variant.branchStock[branchId] ?? 0.0;
      }
      return total;
    }
    return product.branchStock[branchId] ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final allProducts = productProvider.products;

        // 1. Tổng số mặt hàng
        final totalProducts = allProducts.length;

        // 2. Tổng giá trị tồn kho (theo chi nhánh nếu có)
        double totalInventoryValue = 0.0;
        for (final product in allProducts) {
          final stock = _getStockForProduct(product, selectedBranchId);
          totalInventoryValue += product.importPrice * stock;
        }

        // 3. Tổng nhóm hàng (số Category)
        final categoryCount = productProvider.categories.length;

        // 4. Sản phẩm cần bổ sung (tồn < minStock)
        final lowStockCount = productProvider.getLowStockCount(
          selectedBranchId: selectedBranchId,
        );

        return Container(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _DashboardStatCell(
                icon: Icons.inventory_2,
                iconColor: const Color(0xFF2563EB),
                label: 'Tổng số mặt hàng',
                value: totalProducts.toString(),
              ),
              _DashboardStatCell(
                icon: Icons.account_balance_wallet,
                iconColor: const Color(0xFF059669),
                label: 'Tổng giá trị tồn kho',
                value: NumberFormat.currency(
                  locale: 'vi_VN',
                  symbol: '₫',
                ).format(totalInventoryValue),
              ),
              _DashboardStatCell(
                icon: Icons.category,
                iconColor: const Color(0xFF7C3AED),
                label: 'Tổng nhóm hàng',
                value: categoryCount.toString(),
              ),
              _DashboardStatCell(
                icon: Icons.warning_amber_rounded,
                iconColor: const Color(0xFFDC2626),
                label: 'Sản phẩm cần bổ sung',
                value: lowStockCount.toString(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Ô thống kê trong lưới Dashboard: icon góc, nhãn, giá trị nổi bật.
class _DashboardStatCell extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _DashboardStatCell({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0).withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryTable extends StatelessWidget {
  final String? selectedBranchId;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final bool isMobile;
  final bool showSearchBar;

  const _InventoryTable({
    this.selectedBranchId,
    required this.searchController,
    required this.onSearchChanged,
    this.selectedCategoryId,
    required this.onCategoryChanged,
    this.isMobile = false,
    this.showSearchBar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (showSearchBar) ...[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Tìm theo SKU, tên sản phẩm...',
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
                const SizedBox(width: 12),
                Consumer<ProductProvider>(
                  builder: (context, productProvider, child) {
                    if (productProvider.categories.isEmpty && !productProvider.isLoadingCategories) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        productProvider.loadCategories();
                      });
                    }
                    final categories = productProvider.categories;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButton<String?>(
                        value: selectedCategoryId,
                        isExpanded: false,
                        underline: const SizedBox(),
                        hint: const Text('Nhóm hàng'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tất cả'),
                          ),
                          ...categories.map(
                            (category) => DropdownMenuItem<String?>(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          ),
                        ],
                        onChanged: onCategoryChanged,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
        // Nội dung: mobile = ListView thẻ, desktop = DataTable
        Consumer2<ProductProvider, BranchProvider>(
          builder: (context, productProvider, branchProvider, child) {
            final allProducts = productProvider.products;

            if (productProvider.isLoading && allProducts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (allProducts.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      const Text('Chưa có dữ liệu tồn kho'),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: productProvider.loadProducts,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tải lại'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final filteredProducts = (selectedBranchId == null || selectedBranchId!.isEmpty)
                ? allProducts
                : allProducts.where((product) {
                    final stock = _getBranchStockForProduct(product, selectedBranchId);
                    return stock > 0;
                  }).toList();

            if (filteredProducts.isEmpty && (selectedBranchId != null && selectedBranchId!.isNotEmpty)) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 48),
                child: Center(
                  child: Column(
                    children: [
                      const Text('Không có tồn kho ở chi nhánh này'),
                      const SizedBox(height: 16),
                      TextButton.icon(
                        onPressed: productProvider.loadProducts,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tải lại'),
                      ),
                    ],
                  ),
                ),
              );
            }

            if (isMobile) {
              return _MobileInventoryList(
                products: filteredProducts,
                selectedBranchId: selectedBranchId,
                onProductTap: (product) {
                  _showProductDetailBottomSheet(context, product, selectedBranchId);
                },
              );
            }

            return Expanded(
              child: RefreshIndicator(
                onRefresh: productProvider.loadProducts,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final screenWidth = MediaQuery.of(context).size.width;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: screenWidth,
                            maxHeight: constraints.maxHeight,
                          ),
                          child: DataTable(
                            showCheckboxColumn: false,
                            headingRowColor:
                                WidgetStateProperty.all(Colors.grey.shade50),
                            columnSpacing: 16,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'SKU / THÔNG TIN',
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
                            'VỊ TRÍ',
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
                            'CHI NHÁNH',
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
                            'TỒN / ĐỊNH MỨC',
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
                            'GIÁ TRỊ KHO',
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
                            'TRẠNG THÁI',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        DataColumn(
                          label: SizedBox(width: 40),
                        ),
                      ],
                      rows: filteredProducts.map((product) {
                        final stock = _getBranchStockForProduct(product, selectedBranchId);
                        final minStock = product.minStock ?? 0;
                        final status = _getStockStatus(stock, minStock);
                        final statusColor = _getStatusColor(status);

                        return DataRow(
                          onSelectChanged: (selected) {
                            if (selected == true) {
                              _showProductDetailBottomSheet(context, product, selectedBranchId);
                            }
                          },
                          cells: [
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    product.name,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (product.sku != null &&
                                      product.sku!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        product.sku!,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const DataCell(
                              Text(
                                'Chưa thiết lập',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ),
                            DataCell(
                              Builder(
                                builder: (context) {
                                  // Nếu đang lọc theo 1 chi nhánh cụ thể, hiển thị tên chi nhánh đó
                                  if (selectedBranchId != null &&
                                      selectedBranchId!.isNotEmpty) {
                                    BranchModel? branch;
                                    try {
                                      branch = branchProvider.branches.firstWhere(
                                        (b) => b.id == selectedBranchId,
                                      );
                                    } catch (_) {
                                      branch = null;
                                    }
                                    return Text(
                                      branch?.name ?? 'Không có',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    );
                                  }
                                  // Nếu "Tất cả", hiển thị danh sách các chi nhánh có tồn kho
                                  final branchesWithStock = <String>{};
                                  if (product.variants.isNotEmpty) {
                                    for (final variant in product.variants) {
                                      variant.branchStock
                                          .forEach((branchId, stock) {
                                        if (stock > 0) branchesWithStock.add(branchId);
                                      });
                                    }
                                  } else {
                                    product.branchStock
                                        .forEach((branchId, stock) {
                                      if (stock > 0) branchesWithStock.add(branchId);
                                    });
                                  }

                                  // Nếu không có branchStock, sản phẩm thuộc "Cửa hàng chính"
                                  if (branchesWithStock.isEmpty) {
                                    // Kiểm tra xem có tồn kho tổng không
                                    if (product.stock > 0) {
                                      // Tìm chi nhánh "Cửa hàng chính"
                                      BranchModel? mainStore;
                                      try {
                                        mainStore = branchProvider.branches
                                            .firstWhere((b) => b.id == kMainStoreBranchId);
                                      } catch (_) {
                                        mainStore = null;
                                      }
                                      return Text(
                                        mainStore?.name ?? 'Cửa hàng chính',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF64748B),
                                        ),
                                      );
                                    }
                                    return const Text(
                                      'Không có',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    );
                                  }

                                  final branchNames = branchesWithStock
                                      .map((branchId) {
                                        BranchModel? branch;
                                        try {
                                          branch = branchProvider.branches
                                              .firstWhere((b) => b.id == branchId);
                                        } catch (_) {
                                          branch = null;
                                        }
                                        return branch?.name ?? 'Không có';
                                      })
                                      .join(', ');

                                  return Text(
                                    branchNames,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ),
                            DataCell(
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    '${stock.toStringAsFixed(0)} / ${minStock.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: statusColor,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 64,
                                    height: 4,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: minStock > 0
                                            ? (stock / minStock).clamp(0, 2)
                                            : 0,
                                        backgroundColor: Colors.grey.shade100,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          statusColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                NumberFormat.currency(
                                  locale: 'vi_VN',
                                  symbol: '₫',
                                ).format(product.importPrice * stock),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
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
                                ),
                              ),
                            ),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.more_horiz,
                                    size: 18, color: Color(0xFFCBD5E1)),
                                onPressed: () {
                                  _showProductDetailBottomSheet(context, product, selectedBranchId);
                                },
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
            },
          ),
      ],
    );
  }

  static double _getBranchStockForProduct(ProductModel product, String? branchId) {
    if (branchId == null || branchId.isEmpty) {
      return product.stock;
    }

    double total = 0;
    if (product.variants.isNotEmpty) {
      for (final variant in product.variants) {
        final stock = variant.branchStock[branchId] ??
                     (branchId == kMainStoreBranchId ? variant.stock : 0);
        total += stock;
      }
    } else {
      total = product.branchStock[branchId] ??
              (branchId == kMainStoreBranchId ? product.stock : 0);
    }
    return total;
  }

  static String _getStockStatus(double stock, double minStock) {
    if (stock == 0) return 'Hết hàng';
    if (minStock <= 0) return 'An toàn';
    if (stock <= minStock) return 'Sắp hết';
    return 'An toàn';
  }

  static Color _getStatusColor(String status) {
    switch (status) {
      case 'An toàn':
        return const Color(0xFF059669);
      case 'Sắp hết':
        return const Color(0xFFF59E0B);
      case 'Hết hàng':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }

  static void _showProductDetailBottomSheet(
    BuildContext context,
    ProductModel product,
    String? selectedBranchId,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _ProductDetailBottomSheet(
        product: product,
        selectedBranchId: selectedBranchId,
      ),
    );
  }
}

/// Danh sách tồn kho dạng thẻ cho mobile (không dùng DataTable ngang).
class _MobileInventoryList extends StatelessWidget {
  final List<ProductModel> products;
  final String? selectedBranchId;
  final ValueChanged<ProductModel> onProductTap;

  const _MobileInventoryList({
    required this.products,
    required this.selectedBranchId,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<BranchProvider>(
      builder: (context, branchProvider, _) {
        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final stock = _InventoryTable._getBranchStockForProduct(product, selectedBranchId);
            final minStock = product.minStock ?? 0;
            final status = _InventoryTable._getStockStatus(stock, minStock);
            final statusColor = _InventoryTable._getStatusColor(status);
            final value = product.importPrice * stock;

            String branchText = 'Tất cả chi nhánh';
            if (selectedBranchId != null && selectedBranchId!.isNotEmpty) {
              try {
                final branch = branchProvider.branches.firstWhere(
                  (b) => b.id == selectedBranchId,
                );
                branchText = branch.name;
              } catch (_) {
                branchText = '—';
              }
            }

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () => onProductTap(product),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                if (product.sku != null && product.sku!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Text(
                                      product.sku!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Chi nhánh',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            branchText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tồn / Định mức',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '${stock.toStringAsFixed(0)} / ${minStock.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Giá trị kho',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            NumberFormat.currency(
                              locale: 'vi_VN',
                              symbol: '₫',
                            ).format(value),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProductDetailBottomSheet extends StatefulWidget {
  final ProductModel product;
  final String? selectedBranchId;

  const _ProductDetailBottomSheet({
    required this.product,
    this.selectedBranchId,
  });

  @override
  State<_ProductDetailBottomSheet> createState() => _ProductDetailBottomSheetState();
}

class _ProductDetailBottomSheetState extends State<_ProductDetailBottomSheet> {
  final TextEditingController _adjustStockController = TextEditingController();
  bool _isAdjusting = false;

  @override
  void dispose() {
    _adjustStockController.dispose();
    super.dispose();
  }

  double _getCurrentStock() {
    if (widget.selectedBranchId != null && widget.selectedBranchId!.isNotEmpty) {
      if (widget.product.variants.isNotEmpty) {
        double total = 0;
        for (final variant in widget.product.variants) {
          total += variant.branchStock[widget.selectedBranchId] ?? 0.0;
        }
        return total;
      } else {
        return widget.product.branchStock[widget.selectedBranchId] ?? 0.0;
      }
    }
    return widget.product.stock;
  }

  Future<void> _quickAdjustStock() async {
    final newStockText = _adjustStockController.text.trim();
    if (newStockText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số lượng')),
      );
      return;
    }

    final newStock = double.tryParse(newStockText);
    if (newStock == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số lượng không hợp lệ')),
      );
      return;
    }

    final branchId = widget.selectedBranchId ?? kMainStoreBranchId;
    final currentStock = _getCurrentStock();
    final difference = newStock - currentStock;

    if (difference == 0) {
      Navigator.pop(context);
      return;
    }

    setState(() {
      _isAdjusting = true;
    });

    try {
      final productProvider = context.read<ProductProvider>();
      
      final success = await productProvider.adjustProductStock(
        widget.product.id,
        branchId,
        difference,
      );
      
      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                difference > 0
                    ? 'Đã tăng tồn kho ${difference.toStringAsFixed(0)}'
                    : 'Đã giảm tồn kho ${(-difference).toStringAsFixed(0)}',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(productProvider.errorMessage ?? 'Có lỗi xảy ra'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdjusting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStock = _getCurrentStock();
    final minStock = widget.product.minStock ?? 0.0;
    final status = _InventoryTable._getStockStatus(currentStock, minStock);
    final statusColor = _InventoryTable._getStatusColor(status);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.product.sku != null && widget.product.sku!.isNotEmpty)
                          Text(
                            'SKU: ${widget.product.sku}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(),
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                children: [
                  // Stock Info
                  _InfoRow(
                    label: 'Tồn kho hiện tại',
                    value: currentStock.toStringAsFixed(0),
                    color: statusColor,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Định mức tối thiểu',
                    value: minStock > 0 ? minStock.toStringAsFixed(0) : 'Chưa thiết lập',
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Trạng thái',
                    value: status,
                    color: statusColor,
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Giá nhập',
                    value: NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: '₫',
                    ).format(widget.product.importPrice),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(
                    label: 'Giá trị kho',
                    value: NumberFormat.currency(
                      locale: 'vi_VN',
                      symbol: '₫',
                    ).format(widget.product.importPrice * currentStock),
                  ),
                  const SizedBox(height: 24),
                  // Progress indicator
                  if (minStock > 0) ...[
                    Text(
                      'Tỷ lệ tồn kho',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (currentStock / minStock).clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(statusColor),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  // Quick Adjust
                  Text(
                    'Điều chỉnh nhanh',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _adjustStockController,
                    decoration: InputDecoration(
                      labelText: 'Số lượng mới',
                      hintText: currentStock.toStringAsFixed(0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.inventory_2),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isAdjusting ? null : _quickAdjustStock,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isAdjusting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Cập nhật tồn kho'),
                  ),
                  const SizedBox(height: 24),
                  // Transaction History (Placeholder)
                  Text(
                    'Lịch sử giao dịch gần đây',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Tính năng đang được phát triển',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _InfoRow({
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
    );
  }
}

