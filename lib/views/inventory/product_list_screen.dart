import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../controllers/product_provider.dart';
import '../../core/routes.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/ad_banner_widget.dart';
import 'category_management_screen.dart';
import 'product_form_screen.dart';

/// Màn hình danh sách sản phẩm (mobile/desktop theo platform).
class ProductListScreen extends StatefulWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const ProductListScreen({super.key, this.forceMobile});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;
  String? _selectedCategoryId;
  String? _selectedStatus;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load products và categories khi màn hình được khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = context.read<ProductProvider>();
      productProvider.loadProducts();
      productProvider.loadCategories();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshProducts() async {
    await context.read<ProductProvider>().loadProducts();
  }

  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductFormScreen(forceMobile: _useMobileLayout),
      ),
    ).then((_) {
      _refreshProducts();
    });
  }

  void _navigateToCategoryManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryManagementScreen(forceMobile: _useMobileLayout),
      ),
    ).then((_) {
      if (mounted) {
        context.read<ProductProvider>().loadCategories();
      }
    });
  }

  void _navigateToEditProduct(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductFormScreen(product: product, forceMobile: _useMobileLayout),
      ),
    ).then((_) {
      _refreshProducts();
    });
  }

  Future<void> _toggleSellable(ProductModel product, bool value) async {
    try {
      final updatedProduct = product.copyWith(isSellable: value);
      await context.read<ProductProvider>().updateProduct(updatedProduct);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'Đã bật bán sản phẩm' : 'Đã tắt bán sản phẩm'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Xử lý "Cập nhật tồn kho": nếu allowQuickStockUpdate false thì thông báo + điều hướng Nhập kho; nếu true thì dialog nhập số lượng mới.
  Future<void> _onQuickStockUpdate(ProductModel product) async {
    final authProvider = context.read<AuthProvider>();
    final branchProvider = context.read<BranchProvider>();
    final productProvider = context.read<ProductProvider>();
    final branchId = branchProvider.currentBranchId;

    if (branchId == null || branchId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn chi nhánh để cập nhật tồn kho.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (!authProvider.allowQuickStockUpdate) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cập nhật tồn kho'),
          content: const Text(
            "Tính năng cập nhật nhanh đã bị tắt. Vui lòng sử dụng 'Phiếu nhập kho' để điều chỉnh số lượng.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, AppRoutes.purchase);
              },
              child: const Text('Đến Phiếu nhập kho'),
            ),
          ],
        ),
      );
      return;
    }

    final currentStock = productProvider.getStockForCurrentBranch(product);
    final controller = TextEditingController(text: currentStock.toStringAsFixed(0));

    if (!mounted) return;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Cập nhật tồn kho'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text('Tồn kho hiện tại: ${currentStock.toStringAsFixed(0)}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Số lượng mới',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
                FilledButton(
                  onPressed: () {
                    final v = double.tryParse(controller.text.trim());
                    if (v == null || v < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Số lượng không hợp lệ'), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Cập nhật'),
                ),
              ],
            );
          },
        );
      },
    );

    final rawNewStock = controller.text.trim();
    controller.dispose();
    if (result != true || !mounted) return;

    final newStock = double.tryParse(rawNewStock) ?? 0;
    final delta = newStock - currentStock;
    if (delta == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số lượng không thay đổi')));
      }
      return;
    }

    try {
      final ok = await productProvider.adjustProductStock(
        product.id,
        branchId,
        delta,
        note: 'Cập nhật nhanh từ danh sách sản phẩm',
      );
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã cập nhật tồn kho ${product.name}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(productProvider.errorMessage ?? 'Lỗi cập nhật tồn kho'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _confirmDeleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text(
          'Bạn có chắc muốn xóa sản phẩm "${product.name}"? Sản phẩm sẽ được chuyển sang trạng thái ngừng kinh doanh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ProductProvider>().deleteProduct(product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xóa sản phẩm'), duration: Duration(seconds: 2)),
        );
        _refreshProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showMobileFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tìm kiếm & Bộ lọc',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Áp dụng'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildSearchField(),
                const SizedBox(height: 12),
                _buildCategoryDropdown(context),
                const SizedBox(height: 12),
                _buildStatusDropdown(),
              ],
            ),
          ),
        ),
      ),
    ).then((_) => setState(() {}));
  }

  List<ProductModel> _getFilteredProducts(List<ProductModel> products) {
    var filtered = products;

    // Filter by search
    if (_searchController.text.trim().isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(query) ||
            (p.sku != null && p.sku!.toLowerCase().contains(query)) ||
            (p.barcode != null && p.barcode!.toLowerCase().contains(query));
      }).toList();
    }

    // Filter by category
    if (_selectedCategoryId != null && _selectedCategoryId != 'all') {
      filtered = filtered.where((p) => p.categoryId == _selectedCategoryId).toList();
    }

    // Filter by status
    if (_selectedStatus != null && _selectedStatus != 'Tất cả') {
      filtered = filtered.where((p) {
        final stock = p.stock;
        if (_selectedStatus == 'Còn hàng') {
          return stock > 10;
        } else if (_selectedStatus == 'Sắp hết') {
          return stock > 0 && stock <= 10;
        } else if (_selectedStatus == 'Hết hàng') {
          return stock == 0;
        }
        return true;
      }).toList();
    }

    return filtered;
  }

  String _getCategoryName(ProductModel product, List<CategoryModel> categories) {
    if (product.categoryId != null) {
      try {
        final category = categories.firstWhere(
          (cat) => cat.id == product.categoryId,
        );
        return category.name;
      } catch (e) {
        return product.category ?? 'Chưa phân loại';
      }
    }
    return product.category ?? 'Chưa phân loại';
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Tìm kiếm theo tên, SKU hoặc mã vạch...',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                    });
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          isDense: true,
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildCategoryDropdown(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        final categories = productProvider.categories;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButton<String>(
            value: _selectedCategoryId ?? 'all',
            isExpanded: true,
            underline: const SizedBox(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            items: [
              const DropdownMenuItem(
                value: 'all',
                child: Text('Tất cả danh mục', overflow: TextOverflow.ellipsis),
              ),
              ...categories.map((cat) => DropdownMenuItem(
                    value: cat.id,
                    child: Text(cat.name, overflow: TextOverflow.ellipsis),
                  )),
            ],
            onChanged: (value) {
              setState(() {
                _selectedCategoryId = value == 'all' ? null : value;
              });
            },
          ),
        );
      },
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButton<String>(
        value: _selectedStatus ?? 'Tất cả',
        isExpanded: true,
        underline: const SizedBox(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        items: const [
          DropdownMenuItem(value: 'Tất cả', child: Text('Tất cả')),
          DropdownMenuItem(value: 'Còn hàng', child: Text('Còn hàng')),
          DropdownMenuItem(value: 'Sắp hết', child: Text('Sắp hết')),
          DropdownMenuItem(value: 'Hết hàng', child: Text('Hết hàng')),
        ],
        onChanged: (value) {
          setState(() {
            _selectedStatus = value;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final useMobileLayout = _useMobileLayout;

    return Scaffold(
      appBar: isDesktopPlatform
          ? null
          : AppBar(
              title: const Text('Danh sách sản phẩm'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: () => _showMobileFilterSheet(context),
                  tooltip: 'Tìm kiếm & Bộ lọc',
                ),
              ],
            ),
      body: ResponsiveContainer(
        padding: EdgeInsets.zero,
        maxWidth: double.infinity,
        child: Column(
          children: [
            Expanded(
              child: Column(
                children: [
                  _buildHeaderSection(context, useMobileLayout),
                  Expanded(child: _buildProductListContent(context)),
                ],
              ),
            ),
            const SafeArea(
              top: false,
              child: AdBannerWidget(),
            ),
          ],
        ),
      ),
    );
  }

  /// Style chung cho nút Thêm sản phẩm / Thêm nhóm hàng (đảm bảo cùng chiều cao).
  ButtonStyle get _addButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 2,
      );

  /// Header: tiêu đề (desktop), nút Thêm sản phẩm + Thêm nhóm hàng, và (desktop) thanh tìm kiếm + bộ lọc.
  Widget _buildHeaderSection(BuildContext context, bool useMobileLayout) {
    return Container(
      padding: EdgeInsets.all(useMobileLayout ? 16.0 : 24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (useMobileLayout)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToAddProduct,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Thêm sản phẩm'),
                    style: _addButtonStyle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _navigateToCategoryManagement,
                    icon: const Icon(Icons.category, size: 20),
                    label: const Text('Thêm nhóm hàng'),
                    style: _addButtonStyle,
                  ),
                ),
              ],
            ),
          if (!useMobileLayout)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Danh sách sản phẩm',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _navigateToAddProduct,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Thêm sản phẩm'),
                      style: _addButtonStyle,
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _navigateToCategoryManagement,
                      icon: const Icon(Icons.category, size: 20),
                      label: const Text('Thêm nhóm hàng'),
                      style: _addButtonStyle,
                    ),
                  ],
                ),
              ],
            ),
          if (!useMobileLayout) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildSearchField(),
                ),
                const SizedBox(width: 12),
                Expanded(child: _buildCategoryDropdown(context)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatusDropdown()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Nội dung danh sách: Mobile = ListView với Card, Desktop = DataTable (dùng isMobile(context)).
  Widget _buildProductListContent(BuildContext context) {
    return Consumer<ProductProvider>(
      builder: (context, productProvider, child) {
        if (productProvider.isLoading && productProvider.products.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (productProvider.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  productProvider.errorMessage!,
                  style: TextStyle(color: Colors.red[700]),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshProducts,
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }

        final filteredProducts = _getFilteredProducts(productProvider.products);

        if (_useMobileLayout) {
          return _buildMobileProductList(
            context,
            filteredProducts: filteredProducts,
            productProvider: productProvider,
          );
        }
        return _buildDesktopProductTable(
          context,
          filteredProducts: filteredProducts,
          productProvider: productProvider,
        );
      },
    );
  }

  /// Giao diện mobile: ListView với các Card sản phẩm (spacing đồng bộ với stock_overview_screen).
  Widget _buildMobileProductList(
    BuildContext context, {
    required List<ProductModel> filteredProducts,
    required ProductProvider productProvider,
  }) {
    final mobile = _useMobileLayout;
    final listPadding = mobile
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
        : const EdgeInsets.fromLTRB(12, 8, 12, 16);
    final itemBottom = mobile ? 8.0 : 10.0;

    return RefreshIndicator(
      onRefresh: _refreshProducts,
      child: ListView.builder(
        padding: listPadding,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: filteredProducts.length,
        itemBuilder: (context, index) {
          final product = filteredProducts[index];
          return Padding(
            padding: EdgeInsets.only(bottom: itemBottom),
            child: _ProductListCard(
              isMobile: _useMobileLayout,
              product: product,
              stockCurrentBranch: productProvider.getStockForCurrentBranch(product),
              onEdit: () => _navigateToEditProduct(product),
              onDelete: () => _confirmDeleteProduct(product),
              onToggleSellable: (value) => _toggleSellable(product, value),
              onQuickStockUpdate: () => _onQuickStockUpdate(product),
            ),
          );
        },
      ),
    );
  }

  /// Giao diện desktop: DataTable.
  Widget _buildDesktopProductTable(
    BuildContext context, {
    required List<ProductModel> filteredProducts,
    required ProductProvider productProvider,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: _refreshProducts,
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                    columnSpacing: 24,
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('MÃ/SKU', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('TÊN SẢN PHẨM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('NHÓM HÀNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('GIÁ BÁN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('TỒN KHO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('ĐANG BÁN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                      DataColumn(label: Text('', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                    ],
                    rows: filteredProducts.map((product) {
                      return DataRow(
                        onSelectChanged: (_) => _navigateToEditProduct(product),
                        cells: [
                          DataCell(Text(product.barcode ?? product.sku ?? '-')),
                          DataCell(Text(product.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                          DataCell(Text(_getCategoryName(product, productProvider.categories))),
                          DataCell(Text(NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(product.price))),
                          DataCell(Text(
                            product.stock.toStringAsFixed(0),
                            style: TextStyle(
                              color: product.stock > 10 ? Colors.green : (product.stock > 0 ? Colors.orange : Colors.red),
                              fontWeight: FontWeight.bold,
                            ),
                          )),
                          DataCell(
                            Transform.scale(
                              scale: 0.8,
                              child: Switch(
                                value: product.isSellable,
                                onChanged: (value) => _toggleSellable(product, value),
                                activeTrackColor: Colors.green,
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_note, size: 20, color: Colors.teal),
                                  onPressed: () => _onQuickStockUpdate(product),
                                  tooltip: 'Cập nhật tồn kho',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                  onPressed: () => _navigateToEditProduct(product),
                                  tooltip: 'Sửa sản phẩm',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Card cho mỗi sản phẩm trên Mobile: ảnh (nếu có), tên, mã vạch, tồn kho theo chi nhánh; menu Sửa/Xóa/Cập nhật tồn kho.
class _ProductListCard extends StatelessWidget {
  final bool isMobile;
  final ProductModel product;
  final double stockCurrentBranch;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(bool) onToggleSellable;
  final VoidCallback onQuickStockUpdate;

  const _ProductListCard({
    required this.isMobile,
    required this.product,
    required this.stockCurrentBranch,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSellable,
    required this.onQuickStockUpdate,
  });

  Widget _buildProductImage(bool mobile) {
    final size = mobile ? 52.0 : 64.0;
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          product.imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildPlaceholderImage(mobile),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildPlaceholderImage(mobile);
          },
        ),
      );
    }
    return _buildPlaceholderImage(mobile);
  }

  Widget _buildPlaceholderImage(bool mobile) {
    final size = mobile ? 52.0 : 64.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(Icons.inventory_2, color: Colors.grey.shade400, size: mobile ? 24 : 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stock = stockCurrentBranch;
    final mobile = isMobile;
    Color statusColor = Colors.green;
    if (stock == 0) {
      statusColor = Colors.red;
    } else if (stock <= 10) {
      statusColor = Colors.orange;
    }

    // Mobile: gọn hơn, elevation 0, border mỏng dưới (đồng bộ density với stock_overview_screen).
    final cardElevation = mobile ? 0.0 : 1.0;
    final cardPaddingH = mobile ? 10.0 : 12.0;
    final cardPaddingV = mobile ? 8.0 : 10.0;
    final spacingNameBarcode = mobile ? 2.0 : 4.0;
    final spacingBarcodeStock = mobile ? 4.0 : 6.0;
    final rowSpacing = mobile ? 8.0 : 12.0;

    return Card(
      elevation: cardElevation,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: mobile ? 0.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: cardPaddingH, vertical: cardPaddingV),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildProductImage(mobile),
              SizedBox(width: rowSpacing),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacingNameBarcode),
                    Text(
                      product.barcode ?? product.sku ?? 'Mã: -',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacingBarcodeStock),
                    Row(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 14, color: statusColor),
                        SizedBox(width: mobile ? 4 : 6),
                        Text(
                          'Tồn kho: ${stock.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  } else if (value == 'sellable') {
                    onToggleSellable(!product.isSellable);
                  } else if (value == 'update_stock') {
                    onQuickStockUpdate();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 20),
                        SizedBox(width: 12),
                        Text('Sửa'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'update_stock',
                    child: Row(
                      children: [
                        Icon(Icons.edit_note, size: 20, color: Colors.teal),
                        SizedBox(width: 12),
                        Text('Cập nhật tồn kho'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'sellable',
                    child: Row(
                      children: [
                        Icon(
                          product.isSellable ? Icons.toggle_on : Icons.toggle_off,
                          size: 20,
                          color: product.isSellable ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Text(product.isSellable ? 'Ngừng bán' : 'Đang bán'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 20, color: Colors.red),
                        SizedBox(width: 12),
                        Text('Xóa', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
/*
/// Widget Card hiển thị thông tin sản phẩm
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final List<CategoryModel> categories;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final Function(bool) onToggleSellable;
  final String Function(ProductModel) getCategoryName;

  const _ProductCard({
    required this.product,
    required this.categories,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSellable,
    required this.getCategoryName,
  });

  @override
  Widget build(BuildContext context) {
    final categoryName = getCategoryName(product);
    final hasVariants = product.variants.isNotEmpty;
    final variantCount = product.variants.length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hình ảnh sản phẩm
              _buildProductImage(),
              const SizedBox(width: 16),
              // Thông tin sản phẩm
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tên sản phẩm
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            product.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        // Switch bán/không bán
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              product.isSellable ? 'Đang bán' : 'Ngừng bán',
                              style: TextStyle(
                                fontSize: 12,
                                color: product.isSellable
                                    ? Colors.green.shade700
                                    : Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: product.isSellable,
                              onChanged: (value) => onToggleSellable(value),
                              activeTrackColor: Colors.green,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Grid thông tin
                    Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        _buildInfoItem(
                          icon: Icons.scale,
                          label: 'Đơn vị',
                          value: product.unit.isNotEmpty
                              ? product.unit
                              : 'Chưa có',
                        ),
                        _buildInfoItem(
                          icon: Icons.qr_code,
                          label: 'Mã vạch',
                          value: product.barcode ?? 'Chưa có',
                        ),
                        _buildInfoItem(
                          icon: Icons.category,
                          label: 'Nhóm hàng',
                          value: categoryName,
                        ),
                        _buildInfoItem(
                          icon: Icons.business,
                          label: 'Thương hiệu',
                          value: product.manufacturer ?? 'Chưa có',
                        ),
                        _buildInfoItem(
                          icon: Icons.style,
                          label: 'Phiên bản',
                          value: hasVariants
                              ? '$variantCount phiên bản'
                              : 'Không có',
                        ),
                        _buildInfoItem(
                          icon: Icons.inventory_2,
                          label: 'Tồn kho',
                          value: product.stock.toStringAsFixed(0),
                          valueColor: product.stock > 10
                              ? Colors.green
                              : product.stock > 0
                                  ? Colors.orange
                                  : Colors.red,
                        ),
                        _buildInfoItem(
                          icon: Icons.attach_money,
                          label: 'Giá bán',
                          value: NumberFormat.currency(
                            locale: 'vi_VN',
                            symbol: '₫',
                          ).format(product.price),
                          valueColor: Colors.blue.shade700,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Menu actions
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  if (value == 'edit') {
                    onEdit();
                  } else if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Chỉnh sửa'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Xóa', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: valueColor ?? const Color(0xFF0F172A),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildProductImage() {
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          product.imageUrl!,
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildDefaultImage();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildDefaultImage();
          },
        ),
      );
    }
    return _buildDefaultImage();
  }

  Widget _buildDefaultImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(
        Icons.inventory_2,
        color: Colors.grey.shade400,
        size: 32,
      ),
    );
  }
}
*/