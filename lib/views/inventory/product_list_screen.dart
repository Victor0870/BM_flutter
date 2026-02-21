import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../controllers/branch_provider.dart';
import '../../controllers/product_provider.dart';
import '../../core/routes.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';
import 'category_management_screen.dart';
import 'import_product_dialog.dart';
import 'product_form_screen.dart';
import 'product_list_screen_data.dart';
import 'product_list_screen_mobile.dart';
import 'product_list_screen_desktop.dart';

/// Màn hình danh sách sản phẩm (mobile/desktop theo platform).
/// Tệp điều phối — chọn giao diện Mobile hoặc Desktop theo platform.
class ProductListScreen extends StatefulWidget {
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
  ProductModel? _selectedProduct;

  int _filterStock = 0;
  DateTime? _filterExpiryFrom;
  DateTime? _filterExpiryTo;
  DateTime? _filterCreatedAtFrom;
  DateTime? _filterCreatedAtTo;
  int _filterPoints = 0;
  int _filterDirectSale = 0;
  int _filterChannelLink = 0;
  int _filterProductStatus = 1;

  late Map<String, bool> _visibleColumns;

  @override
  void initState() {
    super.initState();
    _visibleColumns = {
      for (final def in productColumnDefs)
        def.id: def.id == 'code' || def.id == 'name' || def.id == 'category' ||
            def.id == 'price' || def.id == 'stock' || def.id == 'createdAt',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = context.read<ProductProvider>();
      productProvider.loadProductsPaginated();
      productProvider.loadCategories();
      if (!_useMobileLayout) context.read<BranchProvider>().loadBranches();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshProducts() async {
    await context.read<ProductProvider>().loadProductsPaginated();
  }

  void _navigateToAddProduct() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductFormScreen(forceMobile: _useMobileLayout)),
    ).then((_) => _refreshProducts());
  }

  void _navigateToCategoryManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CategoryManagementScreen(forceMobile: _useMobileLayout)),
    ).then((_) {
      if (mounted) context.read<ProductProvider>().loadCategories();
    });
  }

  void _navigateToEditProduct(ProductModel product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ProductFormScreen(product: product, forceMobile: _useMobileLayout)),
    ).then((_) => _refreshProducts());
  }

  Future<void> _openImportExcelDialog() async {
    final result = await showDialog<bool>(context: context, builder: (context) => const ImportProductDialog());
    if (result == true && mounted) _refreshProducts();
  }

  Future<void> _toggleSellable(ProductModel product, bool value) async {
    try {
      final updatedProduct = product.copyWith(isSellable: value);
      await context.read<ProductProvider>().updateProduct(updatedProduct);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(value ? AppLocalizations.of(context)!.productSellEnabled : AppLocalizations.of(context)!.productSellDisabled), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorOnUpdate(e)), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _onQuickStockUpdate(ProductModel product) async {
    final authProvider = context.read<AuthProvider>();
    final branchProvider = context.read<BranchProvider>();
    final productProvider = context.read<ProductProvider>();
    final branchId = branchProvider.currentBranchId;

    if (branchId == null || branchId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.pleaseSelectBranchToUpdateStock), backgroundColor: Colors.orange),
        );
      }
      return;
    }

    if (!authProvider.allowQuickStockUpdate) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.updateStock),
          content: Text(AppLocalizations.of(context)!.quickUpdateDisabledMessage),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppLocalizations.of(context)!.close)),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, AppRoutes.purchase);
              },
              child: Text(AppLocalizations.of(context)!.goToPurchase),
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
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(AppLocalizations.of(context)!.updateStock),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(AppLocalizations.of(context)!.currentStock(currentStock.toStringAsFixed(0)), style: TextStyle(fontSize: 13, color: Colors.grey[600])),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: AppLocalizations.of(context)!.newQuantity, border: const OutlineInputBorder()),
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppLocalizations.of(context)!.cancel)),
            FilledButton(
              onPressed: () {
                final v = double.tryParse(controller.text.trim());
                if (v == null || v < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.invalidQuantity), backgroundColor: Colors.red));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(AppLocalizations.of(context)!.update),
            ),
          ],
        ),
      ),
    );

    final rawNewStock = controller.text.trim();
    controller.dispose();
    if (result != true || !mounted) return;

    final newStock = double.tryParse(rawNewStock) ?? 0;
    final delta = newStock - currentStock;
    if (delta == 0) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.quantityUnchanged)));
      return;
    }

    try {
      final ok = await productProvider.adjustProductStock(product.id, branchId, delta, note: AppLocalizations.of(context)!.quickUpdateFromList);
      if (!mounted) return;
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.stockUpdated(product.name))));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(productProvider.errorMessage ?? AppLocalizations.of(context)!.errorUpdateStock), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorGeneric(e)), backgroundColor: Colors.red));
    }
  }

  Future<void> _confirmDeleteProduct(ProductModel product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.confirmDelete),
        content: Text(AppLocalizations.of(context)!.confirmDeleteProduct(product.name)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppLocalizations.of(context)!.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: Text(AppLocalizations.of(context)!.delete)),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await context.read<ProductProvider>().deleteProduct(product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.productDeleted), duration: const Duration(seconds: 2)));
        _refreshProducts();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorOnDelete(e)), backgroundColor: Colors.red));
    }
  }

  void _showMobileFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    Text(AppLocalizations.of(context)!.advancedFilter, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    TextButton(onPressed: () => Navigator.pop(context), child: Text(AppLocalizations.of(context)!.apply)),
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

  List<ProductModel> _getFilteredProducts(List<ProductModel> products, ProductProvider productProvider) {
    var filtered = products;
    if (_searchController.text.trim().isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((p) {
        return p.name.toLowerCase().contains(query) ||
            (p.sku != null && p.sku!.toLowerCase().contains(query)) ||
            (p.barcode != null && p.barcode!.toLowerCase().contains(query));
      }).toList();
    }
    if (_selectedCategoryId != null && _selectedCategoryId != 'all') {
      filtered = filtered.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    if (_selectedStatus != null && _selectedStatus != 'Tất cả') {
      filtered = filtered.where((p) {
        final stock = productProvider.getStockForCurrentBranch(p);
        if (_selectedStatus == 'Còn hàng') return stock > 10;
        if (_selectedStatus == 'Sắp hết') return stock > 0 && stock <= 10;
        if (_selectedStatus == 'Hết hàng') return stock == 0;
        return true;
      }).toList();
    }
    return filtered;
  }

  String _getCategoryName(ProductModel product, List<CategoryModel> categories) {
    if (product.categoryId != null) {
      try {
        return categories.firstWhere((cat) => cat.id == product.categoryId).name;
      } catch (_) {
        return product.category ?? 'Chưa phân loại';
      }
    }
    return product.category ?? 'Chưa phân loại';
  }

  void _showColumnPicker() async {
    final result = await showDialog<Map<String, bool>>(
      context: context,
      builder: (ctx) => ProductColumnPickerDialog(visibleColumns: _visibleColumns, columnDefs: productColumnDefs),
    );
    if (result != null && mounted) setState(() => _visibleColumns = result);
  }

  String _formatPrice(double value) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(value);
  }

  List<ProductModel> _applySidebarFilters(List<ProductModel> list, ProductProvider productProvider) {
    var result = list;
    if (_filterStock == 1) {
      result = result.where((p) => productProvider.getStockForCurrentBranch(p) > 10).toList();
    } else if (_filterStock == 2) {
      result = result.where((p) { final s = productProvider.getStockForCurrentBranch(p); return s > 0 && s <= 10; }).toList();
    } else if (_filterStock == 3) {
      result = result.where((p) => productProvider.getStockForCurrentBranch(p) == 0).toList();
    }
    if (_filterCreatedAtFrom != null) result = result.where((p) => p.createdAt != null && !p.createdAt!.isBefore(_filterCreatedAtFrom!)).toList();
    if (_filterCreatedAtTo != null) {
      final end = DateTime(_filterCreatedAtTo!.year, _filterCreatedAtTo!.month, _filterCreatedAtTo!.day, 23, 59, 59);
      result = result.where((p) => p.createdAt != null && !p.createdAt!.isAfter(end)).toList();
    }
    if (_filterDirectSale == 1) {
      result = result.where((p) => p.isSellable).toList();
    } else if (_filterDirectSale == 2) {
      result = result.where((p) => !p.isSellable).toList();
    }
    if (_filterProductStatus == 1) {
      result = result.where((p) => p.isActive && p.isSellable).toList();
    } else if (_filterProductStatus == 2) {
      result = result.where((p) => !p.isActive || !p.isSellable).toList();
    }
    if (_selectedCategoryId != null) {
      result = result.where((p) => p.categoryId == _selectedCategoryId).toList();
    }
    return result;
  }

  String _getProductCellValue(ProductModel product, ProductProvider productProvider, String columnId) {
    switch (columnId) {
      case 'code': return product.code ?? product.sku ?? product.barcode ?? '—';
      case 'name': return product.name;
      case 'category': return _getCategoryName(product, productProvider.categories);
      case 'price': return _formatPrice(product.price);
      case 'cost': return _formatPrice(product.importPrice);
      case 'stock': return productProvider.getStockForCurrentBranch(product).toStringAsFixed(0);
      case 'customerOrder': return '0';
      case 'createdAt': return product.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(product.createdAt!) : '—';
      case 'expiry': return '---';
      case 'isSellable': return product.isSellable ? 'Có' : 'Không';
      default: return '—';
    }
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
          hintText: AppLocalizations.of(context)!.searchByNameSku,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade400, size: 22),
          suffixIcon: _searchController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () => setState(() => _searchController.clear())) : null,
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
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: DropdownButton<String>(
            value: _selectedCategoryId ?? 'all',
            isExpanded: true,
            underline: const SizedBox(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            items: [
              DropdownMenuItem(value: 'all', child: Text(AppLocalizations.of(context)!.allCategories, overflow: TextOverflow.ellipsis)),
              ...categories.map((cat) => DropdownMenuItem(value: cat.id, child: Text(cat.name, overflow: TextOverflow.ellipsis))),
            ],
            onChanged: (value) => setState(() => _selectedCategoryId = value == 'all' ? null : value),
          ),
        );
      },
    );
  }

  Widget _buildStatusDropdown() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: DropdownButton<String>(
        value: _selectedStatus ?? 'Tất cả',
        isExpanded: true,
        underline: const SizedBox(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        items: [
          DropdownMenuItem(value: 'Tất cả', child: Text(AppLocalizations.of(context)!.all)),
          DropdownMenuItem(value: 'Còn hàng', child: Text(AppLocalizations.of(context)!.inStock)),
          DropdownMenuItem(value: 'Sắp hết', child: Text(AppLocalizations.of(context)!.lowStock)),
          DropdownMenuItem(value: 'Hết hàng', child: Text(AppLocalizations.of(context)!.outOfStock)),
        ],
        onChanged: (value) => setState(() => _selectedStatus = value),
      ),
    );
  }

  ProductListSnapshot _buildSnapshot(ProductProvider productProvider) {
    var filtered = _getFilteredProducts(productProvider.products, productProvider);
    if (!_useMobileLayout) filtered = _applySidebarFilters(filtered, productProvider);
    return ProductListSnapshot(
      filteredProducts: filtered,
      selectedCategoryId: _selectedCategoryId,
      selectedProduct: _selectedProduct,
      selectedStatus: _selectedStatus,
      visibleColumns: _visibleColumns,
      categories: productProvider.categories,
      isLoading: productProvider.isLoading,
      errorMessage: productProvider.errorMessage,
      hasMore: productProvider.hasMoreProducts,
      isLoadingMore: productProvider.isLoadingMore,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktopPlatform
          ? null
          : AppBar(
              title: Text(AppLocalizations.of(context)!.productList),
              actions: [
                IconButton(icon: const Icon(Icons.filter_list), onPressed: () => _showMobileFilterSheet(context), tooltip: AppLocalizations.of(context)!.advancedFilter),
              ],
            ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, _) {
          final snapshot = _buildSnapshot(productProvider);
          if (_useMobileLayout) {
            return ResponsiveContainer(
              padding: EdgeInsets.zero,
              maxWidth: double.infinity,
              child: ProductListScreenMobile(
                snapshot: snapshot,
                searchController: _searchController,
                onSearchChanged: (_) => setState(() {}),
                onCategoryChanged: (v) => setState(() => _selectedCategoryId = v),
                onStatusChanged: (v) => setState(() => _selectedStatus = v),
                onAddProduct: _navigateToAddProduct,
                onAddCategory: _navigateToCategoryManagement,
                onRefresh: _refreshProducts,
                onEdit: _navigateToEditProduct,
                onDelete: _confirmDeleteProduct,
                onToggleSellable: _toggleSellable,
                onQuickStockUpdate: _onQuickStockUpdate,
                formatPrice: _formatPrice,
              ),
            );
          }
          return ProductListScreenDesktop(
            snapshot: snapshot,
            searchController: _searchController,
            onSearchChanged: (_) => setState(() {}),
            onCategoryChanged: (v) => setState(() => _selectedCategoryId = v),
            onShowColumnPicker: _showColumnPicker,
            onImportExcel: _openImportExcelDialog,
            onAddCategory: _navigateToCategoryManagement,
            onRefresh: _refreshProducts,
            onProductSelected: (p) => setState(() => _selectedProduct = p),
            onEdit: _navigateToEditProduct,
            onToggleSellable: _toggleSellable,
            onQuickStockUpdate: _onQuickStockUpdate,
            formatPrice: _formatPrice,
            getCellValue: _getProductCellValue,
            getCategoryName: (p) => _getCategoryName(p, productProvider.categories),
            filterStock: _filterStock,
            onFilterStockChanged: (v) => setState(() => _filterStock = v),
            filterExpiryFrom: _filterExpiryFrom,
            filterExpiryTo: _filterExpiryTo,
            onExpiryChanged: (from, to) => setState(() { _filterExpiryFrom = from; _filterExpiryTo = to; }),
            filterCreatedAtFrom: _filterCreatedAtFrom,
            filterCreatedAtTo: _filterCreatedAtTo,
            onCreatedAtChanged: (from, to) => setState(() { _filterCreatedAtFrom = from; _filterCreatedAtTo = to; }),
            filterPoints: _filterPoints,
            onFilterPointsChanged: (v) => setState(() => _filterPoints = v),
            filterDirectSale: _filterDirectSale,
            onFilterDirectSaleChanged: (v) => setState(() => _filterDirectSale = v),
            filterChannelLink: _filterChannelLink,
            onFilterChannelLinkChanged: (v) => setState(() => _filterChannelLink = v),
            filterProductStatus: _filterProductStatus,
            onFilterProductStatusChanged: (v) => setState(() => _filterProductStatus = v),
            onReset: () => setState(() {
              _selectedCategoryId = null;
              _filterStock = 0;
              _filterExpiryFrom = null;
              _filterExpiryTo = null;
              _filterCreatedAtFrom = null;
              _filterCreatedAtTo = null;
              _filterPoints = 0;
              _filterDirectSale = 0;
              _filterChannelLink = 0;
              _filterProductStatus = 1;
            }),
          );
        },
      ),
    );
  }
}
