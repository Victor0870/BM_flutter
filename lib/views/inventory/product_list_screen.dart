import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/product_provider.dart';
import '../../core/routes.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../widgets/responsive_container.dart';
import 'category_management_screen.dart';
import 'product_form_screen.dart';


/// Màn hình danh sách sản phẩm với thiết kế mới
class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
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
        builder: (context) => const ProductFormScreen(),
      ),
    ).then((_) {
      _refreshProducts();
    });
  }

  void _navigateToEditProduct(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductFormScreen(product: product),
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

  @override
  Widget build(BuildContext context) {
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    // Nội dung chính (không bao gồm sidebar)
    Widget mainContent = ResponsiveContainer(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          // Header Section với Search và Filter
          Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Danh sách sản phẩm',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _navigateToAddProduct,
                      icon: const Icon(Icons.add, size: 20),
                      label: const Text('Thêm sản phẩm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Search và Filter Bar
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm theo tên, SKU hoặc mã vạch...',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Consumer<ProductProvider>(
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
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              items: [
                                const DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Tất cả danh mục'),
                                ),
                                ...categories.map((cat) => DropdownMenuItem(
                                      value: cat.id,
                                      child: Text(cat.name),
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
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedStatus ?? 'Tất cả',
                          isExpanded: true,
                          underline: const SizedBox(),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Product List
          Expanded(
            child: Consumer<ProductProvider>(
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
                        Text(productProvider.errorMessage!, style: TextStyle(color: Colors.red[700])),
                        const SizedBox(height: 16),
                        ElevatedButton(onPressed: _refreshProducts, child: const Text('Thử lại')),
                      ],
                    ),
                  );
                }

                final filteredProducts = _getFilteredProducts(productProvider.products);

                return RefreshIndicator(
                  onRefresh: _refreshProducts,
                  child: Container(
                    color: Colors.white,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
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
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                          onPressed: () => _navigateToEditProduct(product),
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
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: isDesktop
          ? null
          : AppBar(
              title: const Text('Quản lý Kho'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.home),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/', (route) => false);
                  },
                  tooltip: 'Về trang chủ',
                ),
                IconButton(
                  icon: const Icon(Icons.category),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const CategoryManagementScreen(),
                      ),
                    );
                  },
                  tooltip: 'Quản lý Nhóm hàng',
                ),
                IconButton(
                  icon: const Icon(Icons.file_download),
                  onPressed: () {
                    Navigator.pushNamed(context, AppRoutes.purchaseHistory);
                  },
                  tooltip: 'Lịch sử nhập',
                ),
              ],
            ),
      body: mainContent,
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