import 'package:flutter/material.dart';
import '../../models/product_model.dart';
import '../../models/category_model.dart';
import '../../models/unit_conversion.dart';

/// Tham số truyền từ [ProductFormScreen] xuống [ProductFormScreenMobile] và [ProductFormScreenDesktop].
/// Giữ reference tới controllers, state và callbacks để hai giao diện chỉ build UI.
class ProductFormParams {
  const ProductFormParams({
    required this.formKey,
    required this.nameController,
    required this.unitController,
    required this.importPriceController,
    required this.priceController,
    required this.stockController,
    required this.barcodeController,
    required this.categoryController,
    required this.manufacturerController,
    required this.skuController,
    required this.imageUrlController,
    required this.minStockController,
    required this.maxStockController,
    required this.selectedCategoryId,
    required this.categories,
    required this.enableCostPrice,
    required this.variants,
    required this.units,
    required this.isInventoryManaged,
    required this.isImeiManaged,
    required this.isBatchManaged,
    required this.isLoading,
    required this.isScanning,
    required this.isEdit,
    required this.onSave,
    required this.onSaveAndContinue,
    required this.onScanBarcode,
    required this.onCategoryChanged,
    required this.showAddVariantDialog,
    required this.showAddUnitDialog,
    required this.showQuickAddCategoryDialog,
    required this.onToggleInventoryManaged,
    required this.onToggleImeiManaged,
    required this.onToggleBatchManaged,
    required this.onRemoveVariant,
    required this.onRemoveUnit,
    required this.requestRebuild,
    this.onShowStockCard,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController unitController;
  final TextEditingController importPriceController;
  final TextEditingController priceController;
  final TextEditingController stockController;
  final TextEditingController barcodeController;
  final TextEditingController categoryController;
  final TextEditingController manufacturerController;
  final TextEditingController skuController;
  final TextEditingController imageUrlController;
  final TextEditingController minStockController;
  final TextEditingController maxStockController;

  final String? selectedCategoryId;
  final List<CategoryModel> categories;
  final bool enableCostPrice;

  final List<ProductVariant> variants;
  final List<UnitConversion> units;

  final bool isInventoryManaged;
  final bool isImeiManaged;
  final bool isBatchManaged;
  final bool isLoading;
  final bool isScanning;
  final bool isEdit;

  final VoidCallback onSave;
  final VoidCallback onSaveAndContinue;
  final VoidCallback onScanBarcode;
  final ValueChanged<String?> onCategoryChanged;
  final void Function({int? index}) showAddVariantDialog;
  final void Function({int? index}) showAddUnitDialog;
  final VoidCallback showQuickAddCategoryDialog;
  final ValueChanged<bool> onToggleInventoryManaged;
  final ValueChanged<bool> onToggleImeiManaged;
  final ValueChanged<bool> onToggleBatchManaged;
  final void Function(int index) onRemoveVariant;
  final void Function(int index) onRemoveUnit;
  /// Gọi sau khi đóng bottom sheet / thay đổi cần rebuild (mobile).
  final VoidCallback requestRebuild;
  /// Mở thẻ kho (tồn kho theo chi nhánh). Chỉ có khi đang sửa sản phẩm (mobile).
  final VoidCallback? onShowStockCard;

  String? get categoryName {
    if (selectedCategoryId == null) return null;
    try {
      return categories.firstWhere((c) => c.id == selectedCategoryId).name;
    } catch (_) {
      return null;
    }
  }
}
