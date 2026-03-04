import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../controllers/product_provider.dart';
import 'product_form_screen_data.dart';

// ─── Design tokens (hiện đại, card-based) ───────────────────────────────────
const double _kCardRadius = 16;
const double _kShadowBlur = 10;
const double _kShadowOpacity = 0.04;
const double _kPadding = 16;
const double _kImageSize = 72;

const Color _bluePrimary = Color(0xFF2563EB);
const Color _blueLight = Color(0xFFEFF6FF);

/// Giao diện form thêm/sửa sản phẩm cho Mobile: layout card, section "Sửa", bottom bar.
class ProductFormScreenMobile extends StatelessWidget {
  const ProductFormScreenMobile({super.key, required this.params});

  final ProductFormParams params;

  static String _fmtNum(String? s) {
    if (s == null || s.trim().isEmpty) return '0';
    final n = double.tryParse(s);
    return n != null ? NumberFormat('#,###').format(n.toInt()) : '0';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Expanded(
            child: Form(
              key: params.formKey,
              child: ListView(
                padding: const EdgeInsets.all(_kPadding),
                children: [
                  _buildBasicInfoCard(context, primary),
                  const SizedBox(height: 12),
                  _buildDescriptionCard(context, primary),
                  const SizedBox(height: 12),
                  _buildStockLimitCard(context, primary),
                  const SizedBox(height: 12),
                  _buildPriceListCard(context, primary),
                  const SizedBox(height: 12),
                  _buildOtherInfoCard(context, primary),
                  const SizedBox(height: 12),
                  _buildDirectSellCard(context, primary),
                  SizedBox(height: 88 + MediaQuery.of(context).padding.bottom),
                ],
              ),
            ),
          ),
          _buildBottomBar(context, primary),
        ],
      ),
    );
  }

  Widget _card({
    required Widget child,
    required String sectionTitle,
    required VoidCallback onEdit,
    required Color primary,
  }) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_kPadding, _kPadding, _kPadding, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  sectionTitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                    letterSpacing: 0.5,
                  ),
                ),
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Sửa'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(_kPadding, 0, _kPadding, _kPadding),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoCard(BuildContext context, Color primary) {
    final name = params.nameController.text.trim().isEmpty ? 'Chưa có tên' : params.nameController.text;
    final code = params.skuController.text.trim().isEmpty ? '—' : params.skuController.text;
    final barcode = params.barcodeController.text.trim().isEmpty ? '—' : params.barcodeController.text;
    final costPrice = _fmtNum(params.importPriceController.text);
    final categoryName = params.categoryName ?? 'Không chọn';
    final stock = params.stockController.text.trim().isEmpty ? '0' : params.stockController.text;
    final imageUrl = params.imageUrlController.text.trim();

    return _card(
      sectionTitle: 'THÔNG TIN CƠ BẢN',
      primary: primary,
      onEdit: () => _showBasicInfoSheet(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _productImage(imageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _rowLabelValue(
            'Mã hàng',
            code,
            trailing: IconButton(
              icon: Icon(Icons.copy_rounded, size: 20, color: primary),
              onPressed: () {
                if (code != '—') {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã sao chép mã hàng'), duration: Duration(seconds: 1)),
                  );
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ),
          const SizedBox(height: 6),
          _rowLabelValue('Mã vạch', barcode),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _colLabelValue('Giá vốn', '$costPrice đ')),
              const SizedBox(width: 16),
              Expanded(child: _colLabelValue('Giá bán', '${_fmtNum(params.priceController.text)} đ', valueColor: primary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _colLabelValue('Nhóm hàng', categoryName)),
              Expanded(
                child: InkWell(
                  onTap: params.onShowStockCard != null ? () => params.onShowStockCard!() : null,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _colLabelValue('Tồn kho', stock),
                        if (params.onShowStockCard != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Sửa',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: primary,
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade400),
                            ],
                          )
                        else
                          Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _productImage(String imageUrl) {
    return Container(
      width: _kImageSize,
      height: _kImageSize,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? Icon(Icons.image_outlined, size: 32, color: Colors.grey.shade400)
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey.shade400),
            ),
    );
  }

  Widget _rowLabelValue(String label, String value, {Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ...? (trailing != null ? [trailing] : null),
      ],
    );
  }

  Widget _colLabelValue(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: valueColor ?? Colors.black87),
        ),
      ],
    );
  }

  InputDecoration _sheetInputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 15),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _bluePrimary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _sheetLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF475569),
        ),
      ),
    );
  }

  void _showBasicInfoSheet(BuildContext context) {
    final productProvider = context.read<ProductProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewPadding.bottom),
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _blueLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_2_outlined, size: 24, color: _bluePrimary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Thông tin cơ bản',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: _bluePrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                    child: const Text('Xong'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sheetLabel('Tên sản phẩm *'),
              TextFormField(
                controller: params.nameController,
                decoration: _sheetInputDecoration('Nhập tên sản phẩm'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
                onChanged: (_) => params.requestRebuild(),
              ),
              const SizedBox(height: 18),
              _sheetLabel('Đơn vị tính *'),
              TextFormField(
                controller: params.unitController,
                decoration: _sheetInputDecoration('VD: cái, hộp'),
                onChanged: (_) => params.requestRebuild(),
              ),
              const SizedBox(height: 18),
              _sheetLabel('Mã hàng (SKU)'),
              TextFormField(
                controller: params.skuController,
                decoration: _sheetInputDecoration('Tùy chọn'),
                onChanged: (_) => params.requestRebuild(),
              ),
              const SizedBox(height: 18),
              _sheetLabel('Mã vạch'),
              TextFormField(
                controller: params.barcodeController,
                decoration: _sheetInputDecoration(
                  'Nhập hoặc quét',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: _bluePrimary),
                    onPressed: params.onScanBarcode,
                  ),
                ),
                onChanged: (_) => params.requestRebuild(),
              ),
              if (params.enableCostPrice) ...[
                const SizedBox(height: 18),
                _sheetLabel('Giá vốn'),
                TextFormField(
                  controller: params.importPriceController,
                  decoration: _sheetInputDecoration('0').copyWith(suffixText: 'đ'),
                  keyboardType: TextInputType.number,
                  onChanged: (_) => params.requestRebuild(),
                ),
              ],
              const SizedBox(height: 18),
              _sheetLabel('Giá bán *'),
              TextFormField(
                controller: params.priceController,
                decoration: _sheetInputDecoration('0').copyWith(suffixText: 'đ'),
                keyboardType: TextInputType.number,
                onChanged: (_) => params.requestRebuild(),
              ),
              const SizedBox(height: 18),
              _sheetLabel('Nhóm hàng'),
              DropdownButtonFormField<String?>(
                initialValue: params.selectedCategoryId,
                decoration: _sheetInputDecoration('Chọn nhóm hàng').copyWith(
                  suffixIcon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Không chọn')),
                  ...productProvider.categories.map((c) => DropdownMenuItem<String?>(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) {
                  params.onCategoryChanged(v);
                  params.requestRebuild();
                },
              ),
              const SizedBox(height: 18),
              _sheetLabel('Link ảnh'),
              TextFormField(
                controller: params.imageUrlController,
                decoration: _sheetInputDecoration('https://...'),
                keyboardType: TextInputType.url,
                onChanged: (_) => params.requestRebuild(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ).then((_) => params.requestRebuild());
  }

  Widget _buildDescriptionCard(BuildContext context, Color primary) {
    return _card(
      sectionTitle: 'MÔ TẢ',
      primary: primary,
      onEdit: () {
        // Mô tả: có thể dùng category text hoặc để trống
        params.requestRebuild();
      },
      child: InkWell(
        onTap: () {},
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.description_outlined, size: 20, color: primary),
              const SizedBox(width: 8),
              Text('Thêm mô tả', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockLimitCard(BuildContext context, Color primary) {
    final min = params.minStockController.text.trim().isEmpty ? '0' : params.minStockController.text;
    final max = params.maxStockController.text.trim().isEmpty ? '0' : params.maxStockController.text;
    return _card(
      sectionTitle: 'ĐỊNH MỨC TỒN KHO',
      primary: primary,
      onEdit: () => _showStockLimitSheet(context),
      child: Text('$min - $max', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    );
  }

  void _showStockLimitSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewPadding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _blueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.storage_outlined, size: 24, color: _bluePrimary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Định mức tồn kho',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: _bluePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Xong'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sheetLabel('Tồn kho tối thiểu'),
            TextFormField(
              controller: params.minStockController,
              decoration: _sheetInputDecoration('0'),
              keyboardType: TextInputType.number,
              onChanged: (_) => params.requestRebuild(),
            ),
            const SizedBox(height: 18),
            _sheetLabel('Tồn kho tối đa'),
            TextFormField(
              controller: params.maxStockController,
              decoration: _sheetInputDecoration('0'),
              keyboardType: TextInputType.number,
              onChanged: (_) => params.requestRebuild(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ).then((_) => params.requestRebuild());
  }

  Widget _buildPriceListCard(BuildContext context, Color primary) {
    final price = _fmtNum(params.priceController.text);
    final unitName = params.unitController.text.trim().isEmpty ? 'cái' : params.unitController.text;
    return _card(
      sectionTitle: 'BẢNG GIÁ',
      primary: primary,
      onEdit: () => _showPriceSheet(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Bảng giá chung ($unitName)', style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
          Text('$price đ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primary)),
        ],
      ),
    );
  }

  void _showPriceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewPadding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _blueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.sell_outlined, size: 24, color: _bluePrimary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Giá bán',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: _bluePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Xong'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sheetLabel('Giá bán *'),
            TextFormField(
              controller: params.priceController,
              decoration: _sheetInputDecoration('0').copyWith(suffixText: 'đ'),
              keyboardType: TextInputType.number,
              onChanged: (_) => params.requestRebuild(),
            ),
            const SizedBox(height: 16),
            Text('Đơn vị quy đổi', style: Theme.of(ctx).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (params.units.isEmpty)
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  params.showAddUnitDialog();
                },
                icon: const Icon(Icons.add),
                label: const Text('Thêm đơn vị quy đổi'),
              )
            else
              ...params.units.asMap().entries.map((e) {
                final i = e.key;
                final u = e.value;
                return ListTile(
                  title: Text(u.unitName),
                  subtitle: Text('${u.conversionValue} · ${NumberFormat('#,###').format(u.price.toInt())} đ'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () { Navigator.pop(ctx); params.showAddUnitDialog(index: i); }),
                      IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => params.onRemoveUnit(i)),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ).then((_) => params.requestRebuild());
  }

  Widget _buildOtherInfoCard(BuildContext context, Color primary) {
    final manufacturer = params.manufacturerController.text.trim().isEmpty ? '—' : params.manufacturerController.text;
    return _card(
      sectionTitle: 'THÔNG TIN KHÁC',
      primary: primary,
      onEdit: () => _showOtherInfoSheet(context),
      child: _colLabelValue('Nhà sản xuất', manufacturer),
    );
  }

  void _showOtherInfoSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(20, 20, 20, 24 + MediaQuery.of(context).viewPadding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _blueLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.info_outline_rounded, size: 24, color: _bluePrimary),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Thông tin khác',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                  ),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(
                    backgroundColor: _bluePrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: const Text('Xong'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sheetLabel('Nhà sản xuất'),
            TextFormField(
              controller: params.manufacturerController,
              decoration: _sheetInputDecoration('Tùy chọn'),
              onChanged: (_) => params.requestRebuild(),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    ).then((_) => params.requestRebuild());
  }

  Widget _buildDirectSellCard(BuildContext context, Color primary) {
    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: _kPadding, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Quản lý tồn kho', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          Switch(
            value: params.isInventoryManaged,
            onChanged: params.onToggleInventoryManaged,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, Color primary) {
    return Container(
      padding: EdgeInsets.fromLTRB(_kPadding, 12, _kPadding, _kPadding + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: params.isLoading ? null : () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: const Text('Hủy'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: params.isLoading ? null : params.onSaveAndContinue,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                child: params.isLoading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const FittedBox(fit: BoxFit.scaleDown, child: Text('Lưu và thêm tiếp')),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                onPressed: params.isLoading ? null : params.onSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                child: params.isLoading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(params.isEdit ? 'Cập nhật' : 'Thêm sản phẩm'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
