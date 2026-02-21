import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../controllers/product_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../models/branch_model.dart';
import 'product_list_screen_data.dart';

String _productColumnLabel(BuildContext context, String id) {
  final l10n = AppLocalizations.of(context)!;
  switch (id) {
    case 'code': return l10n.productCode;
    case 'name': return l10n.productName;
    case 'category': return l10n.category;
    case 'price': return l10n.sellPrice;
    case 'cost': return l10n.costPrice;
    case 'stock': return l10n.stock;
    case 'customerOrder': return l10n.customerOrder;
    case 'createdAt': return l10n.createdAt;
    case 'expiry': return l10n.expiry;
    case 'isSellable': return l10n.isSellable;
    default: return id;
  }
}

/// Dialog chọn cột hiển thị (desktop).
class ProductColumnPickerDialog extends StatefulWidget {
  final Map<String, bool> visibleColumns;
  final List<ProductColumnDef> columnDefs;

  const ProductColumnPickerDialog({
    super.key,
    required this.visibleColumns,
    required this.columnDefs,
  });

  @override
  State<ProductColumnPickerDialog> createState() => _ProductColumnPickerDialogState();
}

class _ProductColumnPickerDialogState extends State<ProductColumnPickerDialog> {
  late Map<String, bool> _visible;

  @override
  void initState() {
    super.initState();
    _visible = Map.of(widget.visibleColumns);
  }

  @override
  Widget build(BuildContext context) {
    const splitAt = 6;
    final left = widget.columnDefs.take(splitAt).toList();
    final right = widget.columnDefs.skip(splitAt).toList();
    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(AppLocalizations.of(context)!.selectColumns, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(_visible),
                  tooltip: AppLocalizations.of(context)!.close,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: left.map((def) => CheckboxListTile(
                          value: _visible[def.id] ?? false,
                          onChanged: (v) => setState(() => _visible[def.id] = v ?? false),
                          title: Text(_productColumnLabel(context, def.id), style: const TextStyle(fontSize: 14)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        )).toList(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: right.map((def) => CheckboxListTile(
                          value: _visible[def.id] ?? false,
                          onChanged: (v) => setState(() => _visible[def.id] = v ?? false),
                          title: Text(_productColumnLabel(context, def.id), style: const TextStyle(fontSize: 14)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        )).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Màn hình Danh sách sản phẩm - giao diện Desktop.
class ProductListScreenDesktop extends StatelessWidget {
  const ProductListScreenDesktop({
    super.key,
    required this.snapshot,
    required this.searchController,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onShowColumnPicker,
    required this.onImportExcel,
    required this.onAddCategory,
    required this.onRefresh,
    required this.onProductSelected,
    required this.onEdit,
    required this.onToggleSellable,
    required this.onQuickStockUpdate,
    required this.formatPrice,
    required this.getCellValue,
    required this.getCategoryName,
    // Sidebar
    required this.filterStock,
    required this.onFilterStockChanged,
    required this.filterExpiryFrom,
    required this.filterExpiryTo,
    required this.onExpiryChanged,
    required this.filterCreatedAtFrom,
    required this.filterCreatedAtTo,
    required this.onCreatedAtChanged,
    required this.filterPoints,
    required this.onFilterPointsChanged,
    required this.filterDirectSale,
    required this.onFilterDirectSaleChanged,
    required this.filterChannelLink,
    required this.onFilterChannelLinkChanged,
    required this.filterProductStatus,
    required this.onFilterProductStatusChanged,
    required this.onReset,
  });

  final ProductListSnapshot snapshot;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onShowColumnPicker;
  final VoidCallback onImportExcel;
  final VoidCallback onAddCategory;
  final VoidCallback onRefresh;
  final ValueChanged<ProductModel?> onProductSelected;
  final void Function(ProductModel) onEdit;
  final void Function(ProductModel, bool) onToggleSellable;
  final void Function(ProductModel) onQuickStockUpdate;
  final String Function(double) formatPrice;
  final String Function(ProductModel, ProductProvider, String) getCellValue;
  final String Function(ProductModel) getCategoryName;
  final int filterStock;
  final ValueChanged<int> onFilterStockChanged;
  final DateTime? filterExpiryFrom;
  final DateTime? filterExpiryTo;
  final void Function(DateTime?, DateTime?) onExpiryChanged;
  final DateTime? filterCreatedAtFrom;
  final DateTime? filterCreatedAtTo;
  final void Function(DateTime?, DateTime?) onCreatedAtChanged;
  final int filterPoints;
  final ValueChanged<int> onFilterPointsChanged;
  final int filterDirectSale;
  final ValueChanged<int> onFilterDirectSaleChanged;
  final int filterChannelLink;
  final ValueChanged<int> onFilterChannelLinkChanged;
  final int filterProductStatus;
  final ValueChanged<int> onFilterProductStatusChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProductFilterSidebar(
          selectedCategoryId: snapshot.selectedCategoryId,
          onCategoryChanged: onCategoryChanged,
          filterStock: filterStock,
          onFilterStockChanged: onFilterStockChanged,
          filterExpiryFrom: filterExpiryFrom,
          filterExpiryTo: filterExpiryTo,
          onExpiryChanged: onExpiryChanged,
          filterCreatedAtFrom: filterCreatedAtFrom,
          filterCreatedAtTo: filterCreatedAtTo,
          onCreatedAtChanged: onCreatedAtChanged,
          filterPoints: filterPoints,
          onFilterPointsChanged: onFilterPointsChanged,
          filterDirectSale: filterDirectSale,
          onFilterDirectSaleChanged: onFilterDirectSaleChanged,
          filterChannelLink: filterChannelLink,
          onFilterChannelLinkChanged: onFilterChannelLinkChanged,
          filterProductStatus: filterProductStatus,
          onFilterProductStatusChanged: onFilterProductStatusChanged,
          onReset: onReset,
        ),
        Expanded(
          child: Column(
            children: [
              _buildToolbar(context),
              Expanded(child: _buildBodyContent(context)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Consumer<ProductProvider>(
        builder: (context, productProvider, _) {
          final categories = productProvider.categories;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.searchByCodeNameSku,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(icon: const Icon(Icons.clear), onPressed: () { searchController.clear(); onSearchChanged(''); })
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: onSearchChanged,
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String?>(
                  initialValue: snapshot.selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)!.category,
                    hintText: AppLocalizations.of(context)!.selectCategory,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(AppLocalizations.of(context)!.selectCategory)),
                    ...categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                  ],
                  onChanged: onCategoryChanged,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.view_column),
                onPressed: onShowColumnPicker,
                tooltip: AppLocalizations.of(context)!.selectColumns,
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onImportExcel,
                icon: const Icon(Icons.upload_file, size: 18),
                label: Text(AppLocalizations.of(context)!.importExcel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade400),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: onAddCategory,
                icon: const Icon(Icons.add, size: 18),
                label: Text(AppLocalizations.of(context)!.createNew),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    if (snapshot.isLoading && snapshot.filteredProducts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(snapshot.errorMessage!, style: TextStyle(color: Colors.red[700])),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRefresh,
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      );
    }
    return Consumer<ProductProvider>(
      builder: (context, productProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (snapshot.selectedProduct != null)
              _ProductDetailPanel(
                product: snapshot.selectedProduct!,
                categories: snapshot.categories,
                productProvider: productProvider,
                formatPrice: formatPrice,
                getCategoryName: getCategoryName,
                onClose: () => onProductSelected(null),
                onEdit: () => onEdit(snapshot.selectedProduct!),
              ),
            Expanded(
              child: _buildTable(context, productProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTable(BuildContext context, ProductProvider productProvider) {
    final filteredProducts = snapshot.filteredProducts;
    final visibleDefs = productColumnDefs.where((d) => snapshot.visibleColumns[d.id] == true).toList();
    final totalStock = filteredProducts.fold<double>(0, (s, p) => s + productProvider.getStockForCurrentBranch(p));

    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: () async => onRefresh(),
          child: Container(
            color: Colors.white,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    scrollDirection: Axis.vertical,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                          columnSpacing: 16,
                          showCheckboxColumn: false,
                          columns: [
                            ...visibleDefs.map((def) {
                              final isTotalCol = def.hasTotal && (def.id == 'stock' || def.id == 'customerOrder');
                              return DataColumn(
                                label: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_productColumnLabel(context, def.id), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                    if (isTotalCol && def.id == 'stock')
                                      Text(totalStock.toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.grey[800])),
                                    if (isTotalCol && def.id == 'customerOrder')
                                      const Text('0', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ],
                                ),
                              );
                            }),
                            const DataColumn(label: SizedBox(width: 80)),
                          ],
                          rows: filteredProducts.map<DataRow>((product) {
                            final selected = snapshot.selectedProduct?.id == product.id;
                            return DataRow(
                              selected: selected,
                              onSelectChanged: (_) => onProductSelected(product),
                              cells: [
                                ...visibleDefs.map((def) {
                                  final raw = getCellValue(product, productProvider, def.id);
                                  final isStock = def.id == 'stock';
                                  return DataCell(
                                    isStock
                                        ? InkWell(
                                            onTap: () => onProductSelected(product),
                                            child: Text(
                                              raw,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: double.tryParse(raw) != null
                                                    ? (double.parse(raw) > 10 ? Colors.green : (double.parse(raw) > 0 ? Colors.orange : Colors.red))
                                                    : null,
                                              ),
                                            ),
                                          )
                                        : def.id == 'isSellable'
                                            ? Transform.scale(
                                                scale: 0.8,
                                                child: Switch(
                                                  value: product.isSellable,
                                                  onChanged: (v) => onToggleSellable(product, v),
                                                  activeTrackColor: Colors.green,
                                                ),
                                              )
                                            : Text(raw),
                                  );
                                }),
                                DataCell(Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_note, size: 20, color: Colors.teal),
                                      onPressed: () => onQuickStockUpdate(product),
                                      tooltip: AppLocalizations.of(context)!.updateStock,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                                      onPressed: () => onEdit(product),
                                      tooltip: AppLocalizations.of(context)!.edit,
                                    ),
                                  ],
                                )),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                if (snapshot.hasMore)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: snapshot.isLoadingMore
                          ? const SizedBox(height: 32, width: 32, child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton.icon(
                              onPressed: productProvider.loadMoreProducts,
                              icon: const Icon(Icons.add_circle_outline, size: 18),
                              label: Text(AppLocalizations.of(context)!.loadMore),
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

const Color _filterPrimary = Color(0xFF2563EB);
const Color _filterText = Color(0xFF1E293B);
const Color _filterBorder = Color(0xFFE2E8F0);

class _ProductFilterSidebar extends StatelessWidget {
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;
  final int filterStock;
  final ValueChanged<int> onFilterStockChanged;
  final DateTime? filterExpiryFrom;
  final DateTime? filterExpiryTo;
  final void Function(DateTime?, DateTime?) onExpiryChanged;
  final DateTime? filterCreatedAtFrom;
  final DateTime? filterCreatedAtTo;
  final void Function(DateTime?, DateTime?) onCreatedAtChanged;
  final int filterPoints;
  final ValueChanged<int> onFilterPointsChanged;
  final int filterDirectSale;
  final ValueChanged<int> onFilterDirectSaleChanged;
  final int filterChannelLink;
  final ValueChanged<int> onFilterChannelLinkChanged;
  final int filterProductStatus;
  final ValueChanged<int> onFilterProductStatusChanged;
  final VoidCallback? onReset;

  const _ProductFilterSidebar({
    required this.selectedCategoryId,
    required this.onCategoryChanged,
    required this.filterStock,
    required this.onFilterStockChanged,
    required this.filterExpiryFrom,
    required this.filterExpiryTo,
    required this.onExpiryChanged,
    required this.filterCreatedAtFrom,
    required this.filterCreatedAtTo,
    required this.onCreatedAtChanged,
    required this.filterPoints,
    required this.onFilterPointsChanged,
    required this.filterDirectSale,
    required this.onFilterDirectSaleChanged,
    required this.filterChannelLink,
    required this.onFilterChannelLinkChanged,
    required this.filterProductStatus,
    required this.onFilterProductStatusChanged,
    this.onReset,
  });

  static InputDecoration _inputDeco(String hint, {Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500], fontStyle: FontStyle.italic),
      prefixIcon: prefixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _filterBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _filterBorder)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _segmentButton({required String label, required bool selected, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _filterPrimary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? _filterPrimary : _filterBorder, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) const Icon(Icons.check, size: 16, color: Colors.white),
              if (selected) const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: selected ? Colors.white : _filterText)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, {required Widget child}) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: _filterPrimary.withValues(alpha: 0.08),
        highlightColor: _filterPrimary.withValues(alpha: 0.04),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _filterText)),
        iconColor: _filterPrimary,
        collapsedIconColor: _filterText,
        initiallyExpanded: true,
        children: [child],
      ),
    );
  }

  Widget _segmentRow({required List<String> labels, required int selected, required ValueChanged<int> onTap}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(labels.length, (i) => _segmentButton(label: labels[i], selected: selected == i, onTap: () => onTap(i))),
    );
  }

  Widget _dateRow(BuildContext ctx, DateTime? from, DateTime? to, void Function(DateTime?, DateTime?) onPick) {
    final isAllTime = from == null && to == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => onPick(null, null),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(isAllTime ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: isAllTime ? _filterPrimary : _filterBorder),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(ctx)!.allTime, style: const TextStyle(fontSize: 13, color: _filterText, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(context: ctx, initialDate: from ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime.now());
            if (date != null) onPick(date, to);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(!isAllTime ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: !isAllTime ? _filterPrimary : _filterBorder),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(ctx)!.customDate, style: const TextStyle(fontSize: 13, color: _filterText, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
        border: Border(right: BorderSide(color: _filterBorder)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(-2, 0))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
            child: Row(
              children: [
                Icon(Icons.filter_list, color: _filterPrimary, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(AppLocalizations.of(context)!.advancedFilter, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _filterText))),
                if (onReset != null)
                  IconButton(icon: Icon(Icons.refresh, size: 20, color: _filterText), onPressed: onReset, tooltip: AppLocalizations.of(context)!.resetFilter, style: IconButton.styleFrom(foregroundColor: _filterText)),
              ],
            ),
          ),
          const Divider(height: 1, color: _filterBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _section(context, AppLocalizations.of(context)!.category, child: Consumer<ProductProvider>(
                  builder: (context, provider, _) => DropdownButtonFormField<String?>(
                    initialValue: selectedCategoryId,
                    decoration: _inputDeco(AppLocalizations.of(context)!.searchCategory, prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[600])),
                    items: [
                      DropdownMenuItem(value: null, child: Text(AppLocalizations.of(context)!.allCategoriesFilter)),
                      ...provider.categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                    ],
                    onChanged: onCategoryChanged,
                  ),
                )),
                _section(context, AppLocalizations.of(context)!.stockStatus, child: _segmentRow(labels: const ['Tất cả', 'Còn hàng', 'Sắp hết', 'Hết hàng'], selected: filterStock, onTap: onFilterStockChanged)),
                _section(context, AppLocalizations.of(context)!.expiry, child: _dateRow(context, filterExpiryFrom, filterExpiryTo, onExpiryChanged)),
                _section(context, AppLocalizations.of(context)!.createdAt, child: _dateRow(context, filterCreatedAtFrom, filterCreatedAtTo, onCreatedAtChanged)),
                _section(context, AppLocalizations.of(context)!.warehouseLocation, child: TextFormField(decoration: _inputDeco('Chọn vị trí'), readOnly: true)),
                _section(context, AppLocalizations.of(context)!.extraOptions, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!.points, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 8),
                    _segmentRow(labels: const ['Tất cả', 'Có', 'Không'], selected: filterPoints, onTap: onFilterPointsChanged),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.directSale, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 8),
                    _segmentRow(labels: const ['Tất cả', 'Có', 'Không'], selected: filterDirectSale, onTap: onFilterDirectSaleChanged),
                    const SizedBox(height: 16),
                    Text(AppLocalizations.of(context)!.channelLink, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                    const SizedBox(height: 8),
                    _segmentRow(labels: const ['Tất cả', 'Có', 'Không'], selected: filterChannelLink, onTap: onFilterChannelLinkChanged),
                  ],
                )),
                _section(context, AppLocalizations.of(context)!.productStatus, child: DropdownButtonFormField<int>(
                  initialValue: filterProductStatus,
                  decoration: _inputDeco(AppLocalizations.of(context)!.status, prefixIcon: Icon(Icons.inventory_2_outlined, size: 20, color: Colors.grey[600])),
                  items: [
                    DropdownMenuItem(value: 0, child: Text(AppLocalizations.of(context)!.all)),
                    DropdownMenuItem(value: 1, child: Text(AppLocalizations.of(context)!.active)),
                    DropdownMenuItem(value: 2, child: Text(AppLocalizations.of(context)!.inactive)),
                  ],
                  onChanged: (v) => onFilterProductStatusChanged(v ?? 1),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductDetailPanel extends StatefulWidget {
  final ProductModel product;
  final List<CategoryModel> categories;
  final ProductProvider productProvider;
  final String Function(double) formatPrice;
  final String Function(ProductModel) getCategoryName;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  const _ProductDetailPanel({
    required this.product,
    required this.categories,
    required this.productProvider,
    required this.formatPrice,
    required this.getCategoryName,
    required this.onClose,
    required this.onEdit,
  });

  @override
  State<_ProductDetailPanel> createState() => _ProductDetailPanelState();
}

class _ProductDetailPanelState extends State<_ProductDetailPanel> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _placeholder() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
      child: Icon(Icons.inventory_2, color: Colors.grey.shade400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final fmt = widget.formatPrice;
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p.imageUrl!, width: 48, height: 48, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder()))
                else
                  _placeholder(),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    children: [
                      Text(p.code ?? p.sku ?? p.barcode ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      Expanded(child: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 16),
                      Text(fmt(p.price)),
                      const SizedBox(width: 16),
                      Text(fmt(p.importPrice)),
                      const SizedBox(width: 16),
                      InkWell(
                        onTap: () => _tabController.animateTo(3),
                        child: Text(widget.productProvider.getStockForCurrentBranch(p).toStringAsFixed(0), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
                      ),
                      const SizedBox(width: 16),
                      const Text('0'),
                      const SizedBox(width: 16),
                      Text(p.createdAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(p.createdAt!) : '—'),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: widget.onClose, tooltip: 'Đóng'),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Colors.blue.shade700,
            tabs: const [Tab(text: 'Thông tin'), Tab(text: 'Mô tả, ghi chú'), Tab(text: 'Thẻ kho'), Tab(text: 'Tồn kho'), Tab(text: 'Liên kết kênh bán')],
          ),
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(),
                const Center(child: Text('Mô tả, ghi chú')),
                const Center(child: Text('Thẻ kho')),
                _buildStockTab(),
                const Center(child: Text('Liên kết kênh bán')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                TextButton.icon(icon: const Icon(Icons.delete_outline), label: const Text('Xóa'), onPressed: () {}),
                const SizedBox(width: 8),
                OutlinedButton.icon(icon: const Icon(Icons.copy), label: const Text('Sao chép'), onPressed: () {}),
                const Spacer(),
                FilledButton.icon(icon: const Icon(Icons.edit), label: const Text('Chỉnh sửa'), onPressed: widget.onEdit),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab() {
    final p = widget.product;
    final fmt = widget.formatPrice;
    final grid = [
      ['Mã hàng', p.code ?? p.sku ?? p.barcode ?? 'Chưa có'],
      ['Mã vạch', p.barcode ?? 'Chưa có'],
      ['Giá vốn', fmt(p.importPrice)],
      ['Giá bán', fmt(p.price)],
      ['Trọng lượng', p.weight != null ? '${p.weight} g' : '0 g'],
      ['Tồn kho', widget.productProvider.getStockForCurrentBranch(p).toStringAsFixed(0)],
      ['Thương hiệu', p.tradeMarkName ?? 'Chưa có'],
      ['Định mức tồn', '${p.minStock ?? 0} - ${p.maxStock ?? 0}'],
      ['Vị trí', 'Chưa có'],
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.network(p.imageUrl!, width: 80, height: 80, fit: BoxFit.cover, errorBuilder: (_, _, _) => _placeholder()))
              else
                _placeholder(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Nhóm hàng: ${widget.getCategoryName(p)}', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      Chip(label: Text('Hàng hóa thường', style: TextStyle(fontSize: 12))),
                      Chip(label: Text(p.isSellable ? 'Bán trực tiếp' : 'Không bán trực tiếp', style: TextStyle(fontSize: 12))),
                      Chip(label: const Text('Tích điểm', style: TextStyle(fontSize: 12))),
                    ]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: grid.map((e) => SizedBox(
              width: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 100, child: Text(e[0], style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
                  Expanded(child: Text(e[1], style: const TextStyle(fontSize: 13))),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStockTab() {
    return Consumer<BranchProvider>(
      builder: (context, branchProvider, _) => _StockByBranchSection(product: widget.product, branches: branchProvider.branches),
    );
  }
}

class _StockByBranchSection extends StatefulWidget {
  final ProductModel product;
  final List<BranchModel> branches;

  const _StockByBranchSection({required this.product, required this.branches});

  @override
  State<_StockByBranchSection> createState() => _StockByBranchSectionState();
}

class _StockByBranchSectionState extends State<_StockByBranchSection> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final search = _searchController.text.trim().toLowerCase();
    final rows = <MapEntry<String, String>>[];
    double totalStock = 0;
    for (final b in widget.branches) {
      if (search.isNotEmpty && !b.name.toLowerCase().contains(search)) continue;
      final stock = p.branchStock[b.id] ?? 0.0;
      totalStock += stock;
      rows.add(MapEntry(b.name, stock.toStringAsFixed(0)));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            decoration: const InputDecoration(hintText: 'Tìm tên chi nhánh', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade100),
                columns: const [
                  DataColumn(label: Text('Chi nhánh', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Tồn kho', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('KH đặt', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Dự kiến hết hàng', style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Trạng thái', style: TextStyle(fontWeight: FontWeight.w600))),
                ],
                rows: [
                  DataRow(cells: [
                    const DataCell(Text('Tổng')),
                    DataCell(Text(totalStock.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w600))),
                    const DataCell(Text('0')),
                    const DataCell(Text('---')),
                    const DataCell(Text('Đang kinh doanh')),
                  ]),
                  ...rows.map((e) => DataRow(cells: [
                    DataCell(Text(e.key)),
                    DataCell(Text(e.value)),
                    const DataCell(Text('0')),
                    const DataCell(Text('---')),
                    const DataCell(Text('Đang kinh doanh')),
                  ])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
