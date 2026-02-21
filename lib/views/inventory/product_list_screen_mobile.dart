import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../controllers/product_provider.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import 'product_list_screen_data.dart';

// ─── Design tokens (minimalism, premium) ─────────────────────────────────────
const double _kCardRadius = 16;
const double _kImageRadius = 8;
const double _kShadowBlur = 10;
const double _kShadowOpacity = 0.04;
const double _kSpacing = 16;
const double _kSpacingTight = 12;
const double _kProductNameSize = 16;
const double _kMetaSize = 12;
const double _kPriceSize = 14;

/// Màn hình Danh sách sản phẩm - giao diện Mobile.
/// Thiết kế: Card đổ bóng nhẹ, Slidable actions, Search StadiumBorder, Filter Chips.
class ProductListScreenMobile extends StatelessWidget {
  const ProductListScreenMobile({
    super.key,
    required this.snapshot,
    required this.searchController,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onStatusChanged,
    required this.onAddProduct,
    required this.onAddCategory,
    required this.onRefresh,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSellable,
    required this.onQuickStockUpdate,
    required this.formatPrice,
  });

  final ProductListSnapshot snapshot;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onAddProduct;
  final VoidCallback onAddCategory;
  final VoidCallback onRefresh;
  final void Function(ProductModel) onEdit;
  final void Function(ProductModel) onDelete;
  final void Function(ProductModel, bool) onToggleSellable;
  final void Function(ProductModel) onQuickStockUpdate;
  final String Function(double) formatPrice;

  static double displayStock(ProductModel p) {
    return p.branchStock.values.fold(0.0, (a, b) => a + b);
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.grey.shade50,
      child: Column(
        children: [
          _buildHeader(context),
          _buildSearchAndFilters(context),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(_kSpacing, _kSpacing, _kSpacing, _kSpacingTight),
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onAddProduct,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(AppLocalizations.of(context)!.addProductShort),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: _kSpacing, vertical: 12),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: _kSpacingTight),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onAddCategory,
                icon: const Icon(Icons.category_rounded, size: 20),
                label: Text(AppLocalizations.of(context)!.addCategoryShort),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primary,
                  side: BorderSide(color: primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(horizontal: _kSpacing, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(_kSpacing, 0, _kSpacing, _kSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search bar — StadiumBorder, Grey[100]
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: l10n.searchByNameSku,
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500, size: 22),
              suffixIcon: searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear_rounded, size: 20, color: Colors.grey.shade600),
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.grey.shade100,
              border: const OutlineInputBorder(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(24), right: Radius.circular(24)),
                borderSide: BorderSide.none,
              ),
              enabledBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(24), right: Radius.circular(24)),
                borderSide: BorderSide.none,
              ),
              focusedBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.horizontal(left: Radius.circular(24), right: Radius.circular(24)),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              isDense: true,
            ),
          ),
          const SizedBox(height: _kSpacingTight),
          // Filter chips: Tất cả, Còn hàng, Hết hàng, Theo loại
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: l10n.all,
                  selected: snapshot.selectedStatus == null || snapshot.selectedStatus == 'Tất cả',
                  onTap: () => onStatusChanged(null),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.inStock,
                  selected: snapshot.selectedStatus == 'Còn hàng',
                  onTap: () => onStatusChanged('Còn hàng'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.outOfStock,
                  selected: snapshot.selectedStatus == 'Hết hàng',
                  onTap: () => onStatusChanged('Hết hàng'),
                ),
                const SizedBox(width: 8),
                _FilterChip(
                  label: l10n.lowStock,
                  selected: snapshot.selectedStatus == 'Sắp hết',
                  onTap: () => onStatusChanged('Sắp hết'),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  categories: snapshot.categories,
                  selectedId: snapshot.selectedCategoryId,
                  onSelected: onCategoryChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (snapshot.isLoading && snapshot.filteredProducts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(_kSpacing),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, size: 56, color: Colors.red.shade300),
              const SizedBox(height: _kSpacing),
              Text(
                snapshot.errorMessage!,
                style: TextStyle(color: Colors.red.shade700, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: _kSpacing),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(AppLocalizations.of(context)!.retry),
              ),
            ],
          ),
        ),
      );
    }
    if (snapshot.filteredProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: _kSpacing),
            Text(
              'Không có sản phẩm',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          color: Theme.of(context).colorScheme.primary,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(_kSpacing, 0, _kSpacing, _kSpacing),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: snapshot.filteredProducts.length + (snapshot.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == snapshot.filteredProducts.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: _kSpacing),
                  child: Center(
                    child: snapshot.isLoadingMore
                        ? SizedBox(
                            height: 32,
                            width: 32,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Theme.of(context).colorScheme.primary),
                          )
                        : TextButton.icon(
                            onPressed: productProvider.loadMoreProducts,
                            icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                            label: Text(AppLocalizations.of(context)!.loadMore),
                          ),
                  ),
                );
              }
              final product = snapshot.filteredProducts[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: _kSpacingTight),
                child: _ProductListCardMobile(
                  product: product,
                  stockCurrentBranch: productProvider.getStockForCurrentBranch(product),
                  totalStockDisplay: displayStock(product),
                  formatPrice: formatPrice,
                  onEdit: () => onEdit(product),
                  onDelete: () => onDelete(product),
                  onToggleSellable: (v) => onToggleSellable(product, v),
                  onQuickStockUpdate: () => onQuickStockUpdate(product),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Material(
      color: selected ? primary.withValues(alpha: 0.12) : Colors.grey.shade100,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? primary : Colors.grey.shade700,
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final List<CategoryModel> categories;
  final String? selectedId;
  final ValueChanged<String?> onSelected;

  const _CategoryChip({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isAll = selectedId == null || selectedId == 'all';
    return PopupMenuButton<String?>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) => onSelected(v == 'all' ? null : v),
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'all', child: Text('Theo loại')),
        ...categories.map((c) => PopupMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))),
      ],
      child: Material(
        color: !isAll ? primary.withValues(alpha: 0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {}, // opens popup
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Theo loại',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: !isAll ? FontWeight.w600 : FontWeight.w500,
                    color: !isAll ? primary : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down_rounded, size: 20, color: !isAll ? primary : Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductListCardMobile extends StatelessWidget {
  final ProductModel product;
  final double stockCurrentBranch;
  final double totalStockDisplay;
  final String Function(double) formatPrice;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(bool) onToggleSellable;
  final VoidCallback onQuickStockUpdate;

  const _ProductListCardMobile({
    required this.product,
    required this.stockCurrentBranch,
    required this.totalStockDisplay,
    required this.formatPrice,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleSellable,
    required this.onQuickStockUpdate,
  });

  Widget _buildProductImage() {
    const size = 72.0;
    if (product.imageUrl != null && product.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(_kImageRadius),
        child: Image.network(
          product.imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _buildPlaceholder(),
          loadingBuilder: (_, child, progress) => progress == null ? child : _buildPlaceholder(),
        ),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    const size = 72.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(_kImageRadius),
      ),
      child: Icon(Icons.inventory_2_rounded, color: Colors.grey.shade400, size: 28),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final stock = stockCurrentBranch;
    Color statusColor = Colors.green.shade600;
    if (stock == 0) {
      statusColor = Colors.red.shade600;
    } else if (stock <= 10) {
      statusColor = Colors.orange.shade700;
    }

    return Slidable(
      key: ValueKey(product.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.5,
        children: [
          SlidableAction(
            onPressed: (_) => onEdit(),
            backgroundColor: primary,
            foregroundColor: Colors.white,
            icon: Icons.edit_rounded,
            label: 'Sửa',
            borderRadius: BorderRadius.circular(_kCardRadius),
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.red.shade500,
            foregroundColor: Colors.white,
            icon: Icons.delete_rounded,
            label: 'Xóa',
            borderRadius: BorderRadius.circular(_kCardRadius),
          ),
        ],
      ),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.36,
        children: [
          SlidableAction(
            onPressed: (_) => onQuickStockUpdate(),
            backgroundColor: Colors.teal.shade500,
            foregroundColor: Colors.white,
            icon: Icons.inventory_rounded,
            label: 'Tồn kho',
            borderRadius: BorderRadius.circular(_kCardRadius),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_kCardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _kShadowOpacity),
              blurRadius: _kShadowBlur,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(_kCardRadius),
          child: InkWell(
            onTap: onEdit,
            borderRadius: BorderRadius.circular(_kCardRadius),
            child: Padding(
              padding: const EdgeInsets.all(_kSpacingTight),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildProductImage(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(
                            fontSize: _kProductNameSize,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.barcode ?? product.sku ?? product.code ?? 'Mã: —',
                          style: TextStyle(fontSize: _kMetaSize, color: Colors.grey.shade600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          formatPrice(product.price),
                          style: TextStyle(
                            fontSize: _kPriceSize,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tồn kho: ${stock.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: _kMetaSize, color: statusColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

