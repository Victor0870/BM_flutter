import 'package:flutter/material.dart';
import '../../widgets/responsive_container.dart';
import 'product_form_screen_data.dart';

/// Giao diện form thêm/sửa sản phẩm cho Desktop (layout form đầy đủ, nút Lưu inline).
class ProductFormScreenDesktop extends StatelessWidget {
  const ProductFormScreenDesktop({super.key, required this.params});

  final ProductFormParams params;

  @override
  Widget build(BuildContext context) {
    final isEdit = params.isEdit;
    return ResponsiveContainer(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: params.formKey,
        child: ListView(
          children: [
            _field(
              controller: params.nameController,
              label: 'Tên sản phẩm *',
              hint: 'Nhập tên sản phẩm',
              icon: Icons.inventory_2,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên sản phẩm' : null,
            ),
            const SizedBox(height: 16),
            _field(
              controller: params.unitController,
              label: 'Đơn vị tính *',
              hint: 'Ví dụ: cái, kg, lít, thùng...',
              icon: Icons.scale,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập đơn vị tính' : null,
            ),
            const SizedBox(height: 16),
            if (params.enableCostPrice) ...[
              _field(
                controller: params.importPriceController,
                label: 'Giá nhập *',
                hint: '0',
                icon: Icons.arrow_downward,
                suffixText: 'đ',
                keyboardType: TextInputType.number,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập giá nhập';
                  if (double.tryParse(v) == null || double.parse(v) < 0) return 'Giá nhập phải là số hợp lệ';
                  return null;
                },
              ),
              const SizedBox(height: 16),
            ],
            _field(
              controller: params.priceController,
              label: 'Giá bán *',
              hint: '0',
              icon: Icons.arrow_upward,
              suffixText: 'đ',
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Vui lòng nhập giá bán';
                if (double.tryParse(v) == null || double.parse(v) < 0) return 'Giá bán phải là số hợp lệ';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _barcodeField(context),
            const SizedBox(height: 16),
            _stockField(context),
            const SizedBox(height: 16),
            _field(
              controller: params.skuController,
              label: 'Mã SKU',
              hint: 'Mã sản phẩm (SKU)',
              icon: Icons.label,
            ),
            const SizedBox(height: 16),
            _categoryRow(context),
            const SizedBox(height: 8),
            _field(
              controller: params.categoryController,
              label: 'Danh mục (tùy chọn)',
              hint: 'Hoặc nhập danh mục cũ...',
              icon: Icons.text_fields,
            ),
            const SizedBox(height: 16),
            _imageUrlField(context),
            const SizedBox(height: 16),
            TextFormField(
              controller: params.descriptionController,
              decoration: const InputDecoration(
                labelText: 'Mô tả',
                hintText: 'Mô tả sản phẩm (tùy chọn)',
                prefixIcon: Icon(Icons.description_outlined),
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              minLines: 2,
            ),
            const SizedBox(height: 16),
            _minMaxStockRow(context),
            const SizedBox(height: 24),
            _sectionTitle(Icons.swap_horiz, Colors.blue, 'Đơn vị quy đổi'),
            const SizedBox(height: 8),
            Text(
              'Thêm các đơn vị quy đổi (VD: 1 Thùng = 24 Lon)',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            _unitsSection(context),
            const SizedBox(height: 24),
            _sectionTitle(Icons.settings, Colors.orange, 'Cấu hình loại hình'),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Quản lý tồn kho'),
              subtitle: const Text('Theo dõi số lượng tồn kho'),
              value: params.isInventoryManaged,
              onChanged: params.onToggleInventoryManaged,
            ),
            SwitchListTile(
              title: const Text('Quản lý IMEI'),
              subtitle: const Text('Cho hàng công nghệ (điện thoại, máy tính...)'),
              value: params.isImeiManaged,
              onChanged: params.onToggleImeiManaged,
            ),
            SwitchListTile(
              title: const Text('Quản lý lô hạn sử dụng'),
              subtitle: const Text('Cho hàng thực phẩm, thuốc có hạn sử dụng'),
              value: params.isBatchManaged,
              onChanged: params.onToggleBatchManaged,
            ),
            const SizedBox(height: 16),
            _field(
              controller: params.manufacturerController,
              label: 'Nhà sản xuất',
              hint: 'Tên nhà sản xuất',
              icon: Icons.business,
            ),
            const SizedBox(height: 24),
            _sectionTitle(Icons.style, Colors.blue, 'Biến thể sản phẩm'),
            const SizedBox(height: 8),
            Text(
              'Thêm các biến thể như: Size (S, M, L), Màu sắc, v.v.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            _variantsSection(context),
            const SizedBox(height: 24),
            _saveButtons(context, isEdit),
          ],
        ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? suffixText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        suffixText: suffixText,
        border: const OutlineInputBorder(),
      ),
      keyboardType: keyboardType,
      validator: validator,
    );
  }

  Widget _barcodeField(BuildContext context) {
    return TextFormField(
      controller: params.barcodeController,
      decoration: InputDecoration(
        labelText: 'Mã vạch',
        hintText: 'Nhập mã vạch hoặc quét',
        prefixIcon: const Icon(Icons.qr_code_scanner),
        suffixIcon: IconButton(
          icon: params.isScanning
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.camera_alt),
          onPressed: params.onScanBarcode,
          tooltip: 'Quét mã vạch',
        ),
        border: const OutlineInputBorder(),
      ),
      keyboardType: TextInputType.text,
    );
  }

  Widget _stockField(BuildContext context) {
    return TextFormField(
      controller: params.stockController,
      decoration: InputDecoration(
        labelText: 'Số lượng tồn kho',
        hintText: '0',
        prefixIcon: const Icon(Icons.inventory),
        suffixIcon: Icon(Icons.lock_outline, color: Colors.grey[600], size: 20),
        helperText: 'Chỉ đọc - Sử dụng "Nhập kho" hoặc "Xuất kho" để thay đổi',
        helperMaxLines: 2,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.grey[100],
      ),
      keyboardType: TextInputType.number,
      readOnly: true,
      enabled: false,
    );
  }

  Widget _categoryRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: params.selectedCategoryId,
            decoration: const InputDecoration(
              labelText: 'Nhóm hàng',
              hintText: 'Chọn nhóm hàng',
              prefixIcon: Icon(Icons.category),
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('Không chọn')),
              ...params.categories.map((c) => DropdownMenuItem<String>(value: c.id, child: Text(c.name))),
            ],
            onChanged: params.onCategoryChanged,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: params.showQuickAddCategoryDialog,
          tooltip: 'Tạo nhanh nhóm hàng mới',
          style: IconButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primaryContainer),
        ),
      ],
    );
  }

  Widget _imageUrlField(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: params.imageUrlController,
          decoration: const InputDecoration(
            labelText: 'Link ảnh sản phẩm',
            hintText: 'https://example.com/image.jpg',
            prefixIcon: Icon(Icons.image),
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          onChanged: (_) => params.requestRebuild(),
        ),
        const SizedBox(height: 8),
        if (params.imageUrlController.text.isNotEmpty)
          Container(
            height: 150,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                params.imageUrlController.text,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _imageError(),
                loadingBuilder: (_, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }

  Widget _imageError() => Container(
        color: Colors.grey.shade200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Không thể tải ảnh', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );

  Widget _minMaxStockRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: params.minStockController,
            decoration: const InputDecoration(
              labelText: 'Tồn kho tối thiểu',
              hintText: '0',
              prefixIcon: Icon(Icons.arrow_downward),
              suffixText: 'đơn vị',
              border: OutlineInputBorder(),
              helperText: 'Cảnh báo khi dưới mức này',
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: params.maxStockController,
            decoration: const InputDecoration(
              labelText: 'Tồn kho tối đa',
              hintText: '0',
              prefixIcon: Icon(Icons.arrow_upward),
              suffixText: 'đơn vị',
              border: OutlineInputBorder(),
              helperText: 'Cảnh báo khi vượt mức này',
            ),
            keyboardType: TextInputType.number,
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(IconData icon, Color color, String title) {
    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _unitsSection(BuildContext context) {
    if (params.units.isEmpty) {
      return TextButton.icon(
        onPressed: () => params.showAddUnitDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm đơn vị quy đổi'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...params.units.asMap().entries.map((e) {
          final i = e.key;
          final unit = e.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(unit.unitName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Hệ số: ${unit.conversionValue}'),
                  Text('Giá bán: ${unit.price.toStringAsFixed(0)} đ'),
                  if (unit.barcode != null) Text('Mã vạch: ${unit.barcode}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => params.showAddUnitDialog(index: i), tooltip: 'Sửa'),
                  IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => params.onRemoveUnit(i), tooltip: 'Xóa'),
                ],
              ),
            ),
          );
        }),
        ElevatedButton.icon(
          onPressed: () => params.showAddUnitDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Thêm đơn vị quy đổi'),
        ),
      ],
    );
  }

  Widget _variantsSection(BuildContext context) {
    if (params.variants.isEmpty) {
      return TextButton.icon(
        onPressed: () => params.showAddVariantDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Thêm biến thể đầu tiên'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...params.variants.asMap().entries.map((e) {
          final i = e.key;
          final v = e.value;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(v.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SKU: ${v.sku}'),
                  Text('Giá: ${v.price.toStringAsFixed(0)} đ'),
                  Text('Tồn kho: ${v.stock.toStringAsFixed(0)}'),
                  if (v.barcode != null) Text('Mã vạch: ${v.barcode}'),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: () => params.showAddVariantDialog(index: i), tooltip: 'Sửa'),
                  IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () => params.onRemoveVariant(i), tooltip: 'Xóa'),
                ],
              ),
            ),
          );
        }),
        ElevatedButton.icon(
          onPressed: () => params.showAddVariantDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Thêm biến thể'),
        ),
      ],
    );
  }

  Widget _saveButtons(BuildContext context, bool isEdit) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: params.isLoading ? null : params.onSaveAndContinue,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: params.isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const FittedBox(fit: BoxFit.scaleDown, child: Text('Lưu và thêm tiếp', style: TextStyle(fontSize: 16))),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: params.isLoading ? null : params.onSave,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: params.isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : FittedBox(fit: BoxFit.scaleDown, child: Text(isEdit ? 'Cập nhật' : 'Thêm sản phẩm', style: const TextStyle(fontSize: 16))),
          ),
        ),
      ],
    );
  }
}
