import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../controllers/product_provider.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../models/product_model.dart';
import '../../models/branch_model.dart';
import '../../models/unit_conversion.dart';
import '../../models/category_model.dart';
import '../../utils/platform_utils.dart';
import 'product_form_screen_data.dart';
import 'product_form_screen_mobile.dart';
import 'product_form_screen_desktop.dart';

/// Màn hình thêm/sửa sản phẩm (mobile/desktop theo platform).
/// State và logic nằm ở đây; UI nằm ở product_form_screen_mobile.dart và product_form_screen_desktop.dart.
class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const ProductFormScreen({super.key, this.product, this.forceMobile});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _importPriceController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController(); // Backward compatibility
  final _manufacturerController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _skuController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _minStockController = TextEditingController();
  final _maxStockController = TextEditingController();

  String? _selectedCategoryId; // ID của CategoryModel
  List<ProductVariant> _variants = [];
  List<UnitConversion> _units = []; // Danh sách đơn vị quy đổi
  List<ProductAttribute> _attributes = []; // Thuộc tính: Màu sắc, Size...
  
  // Loại hình sản phẩm
  bool _isInventoryManaged = true;
  bool _isImeiManaged = false;
  bool _isBatchManaged = false;

  bool _isLoading = false;
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // Load categories
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductProvider>().loadCategories();
    });

    // Nếu là màn hình sửa, điền dữ liệu cũ
    if (widget.product != null) {
      _populateForm(widget.product!);
    } else {
      // Giá trị mặc định cho màn hình thêm mới
      _unitController.text = 'cái';
      _stockController.text = '0';
      // Tạo đơn vị mặc định
      _units = [
        UnitConversion(
          id: 'default',
          unitName: 'cái',
          conversionValue: 1.0,
          price: 0.0,
        ),
      ];
    }
  }

  void _populateForm(ProductModel product) {
    _nameController.text = product.name;
    _unitController.text = product.unit;
    _importPriceController.text = product.importPrice.toStringAsFixed(0);
    _priceController.text = product.price.toStringAsFixed(0);
    _stockController.text = product.stock.toStringAsFixed(0);
    _barcodeController.text = product.barcode ?? '';
    _categoryController.text = product.category ?? ''; // Backward compatibility
    _manufacturerController.text = product.manufacturer ?? '';
    _descriptionController.text = product.description ?? '';
    _skuController.text = product.sku ?? '';
    _imageUrlController.text = product.imageUrl ?? '';
    _minStockController.text = product.minStock?.toStringAsFixed(0) ?? '';
    _maxStockController.text = product.maxStock?.toStringAsFixed(0) ?? '';
    _selectedCategoryId = product.categoryId;
    _variants = List.from(product.variants);
    _units = List.from(product.units);
    _attributes = List.from(product.attributes);
    _isInventoryManaged = product.isInventoryManaged;
    _isImeiManaged = product.isImeiManaged;
    _isBatchManaged = product.isBatchManaged;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _unitController.dispose();
    _importPriceController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _barcodeController.dispose();
    _categoryController.dispose();
    _manufacturerController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _imageUrlController.dispose();
    _minStockController.dispose();
    _maxStockController.dispose();
    super.dispose();
  }

  void _updateStockDisplay() {
    if (_variants.isNotEmpty) {
      final totalStock = _variants.fold(0.0, (sum, variant) => sum + variant.stock);
      _stockController.text = totalStock.toStringAsFixed(0);
    }
  }

  void _showAddVariantDialog({int? index}) {
    final variant = index != null ? _variants[index] : null;

    final nameController = TextEditingController(text: variant?.name ?? '');
    final skuController = TextEditingController(text: variant?.sku ?? '');
    final priceController = TextEditingController(
        text: variant?.price.toStringAsFixed(0) ?? _priceController.text);
    final costPriceController = TextEditingController(
        text: variant?.costPrice.toStringAsFixed(0) ?? _importPriceController.text);
    final stockController = TextEditingController(
        text: variant?.stock.toStringAsFixed(0) ?? '0');
    final barcodeController = TextEditingController(text: variant?.barcode ?? '');

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(index != null ? 'Sửa biến thể' : 'Thêm biến thể'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên biến thể *',
                    hintText: 'VD: S - Đỏ, M - Xanh',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên biến thể';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: skuController,
                  decoration: const InputDecoration(
                    labelText: 'SKU biến thể',
                    hintText: 'Mã SKU cho biến thể này',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: costPriceController,
                  decoration: const InputDecoration(
                    labelText: 'Giá nhập *',
                    suffixText: 'đ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập giá nhập';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Giá nhập phải là số';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Giá bán *',
                    suffixText: 'đ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập giá bán';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Giá bán phải là số';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: stockController,
                  decoration: const InputDecoration(
                    labelText: 'Tồn kho *',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tồn kho';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Tồn kho phải là số';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: barcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Mã vạch',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                // Lấy branchId từ authProvider hoặc dùng 'default'
                final authProvider = context.read<AuthProvider>();
                final branchId = authProvider.selectedBranchId ?? 'default';
                
                final newVariant = ProductVariant(
                  id: variant?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  sku: skuController.text.trim().isEmpty
                      ? ''
                      : skuController.text.trim(),
                  name: nameController.text.trim(),
                  branchPrices: {branchId: double.parse(priceController.text)},
                  costPrice: double.parse(costPriceController.text),
                  branchStock: {branchId: double.parse(stockController.text)},
                  barcode: barcodeController.text.trim().isEmpty
                      ? null
                      : barcodeController.text.trim(),
                );

                setState(() {
                  if (index != null) {
                    _variants[index] = newVariant;
                  } else {
                    _variants.add(newVariant);
                  }
                  _updateStockDisplay();
                });

                Navigator.pop(context);
              }
            },
            child: Text(index != null ? 'Cập nhật' : 'Thêm'),
          ),
        ],
      ),
    );
  }

  void _showStockCardSheet(BuildContext context) {
    final product = widget.product;
    if (product == null) return;

    Map<String, double> stockByBranch = Map<String, double>.from(product.branchStock);
    if (product.variants.isNotEmpty) {
      stockByBranch = {};
      for (final v in product.variants) {
        v.branchStock.forEach((branchId, qty) {
          stockByBranch[branchId] = (stockByBranch[branchId] ?? 0) + qty;
        });
      }
    }

    final branchProvider = context.read<BranchProvider>();
    final branches = branchProvider.branches.where((b) => b.isActive).toList();
    final branchIds = <String>{...stockByBranch.keys};
    for (final b in branches) {
      branchIds.add(b.id);
    }
    if (stockByBranch.isEmpty && branches.isEmpty) {
      branchIds.add(kMainStoreBranchId);
    }

    final fmt = NumberFormat('#,###');
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.4,
        minChildSize: 0.25,
        maxChildSize: 0.85,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Thẻ kho',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Xong'),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  children: [
                    ...branchIds.map((branchId) {
                      final match = branches.where((b) => b.id == branchId);
                      final name = branchId == kMainStoreBranchId
                          ? 'Cửa hàng chính'
                          : (match.isEmpty ? branchId : match.first.name);
                      final qty = stockByBranch[branchId] ?? 0.0;
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        trailing: Text(
                          fmt.format(qty.toInt()),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanBarcode() async {
    setState(() {
      _isScanning = true;
    });

    // Mở màn hình quét mã vạch
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        _barcodeController.text = result;
        _isScanning = false;
      });
    } else {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _saveProductWithoutNavigation();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.product == null
                  ? 'Thêm sản phẩm thành công!'
                  : 'Cập nhật sản phẩm thành công!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
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
          _isLoading = false;
        });
      }
    }
  }

  /// Lưu sản phẩm và tiếp tục thêm sản phẩm mới
  Future<void> _saveProductAndContinue() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _saveProductWithoutNavigation();
      
      if (mounted) {
        // Xóa form để nhập sản phẩm mới
        _nameController.clear();
        _unitController.text = 'cái';
        _importPriceController.clear();
        _priceController.clear();
        _stockController.text = '0';
        _barcodeController.clear();
        _manufacturerController.clear();
        _descriptionController.clear();
        _skuController.clear();
        _imageUrlController.clear();
        _minStockController.clear();
        _maxStockController.clear();
        _selectedCategoryId = null;
        _variants.clear();
        _attributes.clear();
        _units = [
          UnitConversion(
            id: 'default',
            unitName: 'cái',
            conversionValue: 1.0,
            price: 0.0,
          ),
        ];
        _isInventoryManaged = true;
        _isImeiManaged = false;
        _isBatchManaged = false;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã lưu! Tiếp tục nhập sản phẩm mới...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Focus vào ô tên sản phẩm
        FocusScope.of(context).requestFocus(FocusNode());
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
          _isLoading = false;
        });
      }
    }
  }

  /// Lưu sản phẩm (logic chung, không navigate)
  Future<void> _saveProductWithoutNavigation() async {
    final productProvider = context.read<ProductProvider>();
    final authProvider = productProvider.authProvider;

    if (authProvider.user == null) {
      throw Exception('Chưa đăng nhập');
    }

    // Lấy branchId từ authProvider hoặc dùng 'default'
    final branchId = authProvider.selectedBranchId ?? 'default';
    
    // Tính branchPrices và branchStock
    Map<String, double> branchPrices = widget.product?.branchPrices ?? {};
    Map<String, double> branchStock = widget.product?.branchStock ?? {};
    
    // Cập nhật giá và stock cho branch được chọn
    branchPrices[branchId] = double.tryParse(_priceController.text) ?? 0;
    
    double finalStock = double.tryParse(_stockController.text) ?? 0;
    if (_variants.isNotEmpty) {
      finalStock = _variants.fold(0.0, (sum, variant) {
        final variantStock = variant.branchStock[branchId] ?? variant.stock;
        return sum + variantStock;
      });
    }
    branchStock[branchId] = finalStock;

    // Nếu units rỗng, tạo đơn vị mặc định
    List<UnitConversion> finalUnits = _units;
    if (finalUnits.isEmpty) {
      final defaultPrice = double.tryParse(_priceController.text) ?? 0.0;
      finalUnits = [
        UnitConversion(
          id: 'default',
          unitName: _unitController.text.trim().isEmpty ? 'cái' : _unitController.text.trim(),
          conversionValue: 1.0,
          price: defaultPrice,
          barcode: _barcodeController.text.trim().isEmpty ? null : _barcodeController.text.trim(),
        ),
      ];
    }

    final product = ProductModel(
      id: widget.product?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      units: finalUnits,
      branchPrices: branchPrices,
      importPrice: double.tryParse(_importPriceController.text) ?? 0,
      branchStock: branchStock,
      barcode: _barcodeController.text.trim().isEmpty
          ? null
          : _barcodeController.text.trim(),
      category: _categoryController.text.trim().isEmpty
          ? null
          : _categoryController.text.trim(),
      categoryId: _selectedCategoryId,
      manufacturer: _manufacturerController.text.trim().isEmpty
          ? null
          : _manufacturerController.text.trim(),
      sku: _skuController.text.trim().isEmpty
          ? null
          : _skuController.text.trim(),
      imageUrl: _imageUrlController.text.trim().isEmpty
          ? null
          : _imageUrlController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      minStock: _minStockController.text.trim().isEmpty
          ? null
          : double.tryParse(_minStockController.text),
      maxStock: _maxStockController.text.trim().isEmpty
          ? null
          : double.tryParse(_maxStockController.text),
      attributes: _attributes,
      variants: _variants,
      isInventoryManaged: _isInventoryManaged,
      isImeiManaged: _isImeiManaged,
      isBatchManaged: _isBatchManaged,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
      isActive: true,
    );

    bool success;
    if (widget.product == null) {
      success = await productProvider.addProduct(product);
    } else {
      success = await productProvider.updateProduct(product);
    }

    if (!success) {
      throw Exception(productProvider.errorMessage ?? 'Có lỗi xảy ra');
    }
  }

  /// Hiển thị dialog tạo nhanh Category
  void _showQuickAddCategoryDialog(ProductProvider productProvider) {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tạo nhanh nhóm hàng'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Tên nhóm hàng *',
              hintText: 'Ví dụ: Đồ uống, Thực phẩm...',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Vui lòng nhập tên nhóm hàng';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final authProvider = context.read<AuthProvider>();
                if (authProvider.user == null) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chưa đăng nhập'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final newCategory = CategoryModel(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  userId: authProvider.user!.uid,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                final success = await productProvider.addCategory(newCategory);
                if (!context.mounted) return;
                Navigator.pop(context);

                if (success) {
                  setState(() {
                    _selectedCategoryId = newCategory.id;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã tạo và chọn nhóm hàng mới!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(productProvider.categoryErrorMessage ?? 'Có lỗi xảy ra'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Tạo'),
          ),
        ],
      ),
    );
  }

  /// Hiển thị dialog thêm/sửa đơn vị quy đổi
  void _showAddUnitDialog({int? index}) {
    final unit = index != null ? _units[index] : null;
    final unitNameController = TextEditingController(text: unit?.unitName ?? '');
    final conversionController = TextEditingController(text: unit?.conversionValue.toString() ?? '1');
    final priceController = TextEditingController(text: unit?.price.toStringAsFixed(0) ?? '');
    final barcodeController = TextEditingController(text: unit?.barcode ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(unit == null ? 'Thêm đơn vị quy đổi' : 'Sửa đơn vị quy đổi'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: unitNameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên đơn vị *',
                    hintText: 'VD: Thùng, Chai, Kg...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên đơn vị';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: conversionController,
                  decoration: const InputDecoration(
                    labelText: 'Hệ số quy đổi *',
                    hintText: 'VD: 24 (1 thùng = 24 chai)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập hệ số quy đổi';
                    }
                    if (double.tryParse(value) == null || double.parse(value) <= 0) {
                      return 'Hệ số phải là số dương';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: priceController,
                  decoration: const InputDecoration(
                    labelText: 'Giá bán cho đơn vị này *',
                    hintText: '0',
                    suffixText: 'đ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập giá bán';
                    }
                    if (double.tryParse(value) == null || double.parse(value) < 0) {
                      return 'Giá phải là số hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: barcodeController,
                  decoration: const InputDecoration(
                    labelText: 'Mã vạch (tùy chọn)',
                    hintText: 'Mã vạch riêng cho đơn vị này',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newUnit = UnitConversion(
                  id: unit?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  unitName: unitNameController.text.trim(),
                  conversionValue: double.parse(conversionController.text),
                  price: double.parse(priceController.text),
                  barcode: barcodeController.text.trim().isEmpty
                      ? null
                      : barcodeController.text.trim(),
                );

                setState(() {
                  if (index != null) {
                    _units[index] = newUnit;
                  } else {
                    _units.add(newUnit);
                  }
                });

                Navigator.pop(context);
              }
            },
            child: Text(unit == null ? 'Thêm' : 'Cập nhật'),
          ),
        ],
      ),
    );
  }

  /// Dialog thêm/sửa thuộc tính (Màu sắc, Size...)
  void _showAddAttributeDialog({int? index}) {
    final attr = index != null ? _attributes[index] : null;
    final nameController = TextEditingController(text: attr?.attributeName ?? '');
    final valueController = TextEditingController(text: attr?.attributeValue ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(attr == null ? 'Thêm thuộc tính' : 'Sửa thuộc tính'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên thuộc tính *',
                    hintText: 'VD: Màu sắc, Size, Chất liệu...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên thuộc tính' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: valueController,
                  decoration: const InputDecoration(
                    labelText: 'Giá trị *',
                    hintText: 'VD: Đỏ, M, Cotton...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập giá trị' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final newAttr = ProductAttribute(
                  attributeName: nameController.text.trim(),
                  attributeValue: valueController.text.trim(),
                );
                setState(() {
                  if (index != null) {
                    _attributes[index] = newAttr;
                  } else {
                    _attributes.add(newAttr);
                  }
                });
                Navigator.pop(context);
              }
            },
            child: Text(attr == null ? 'Thêm' : 'Cập nhật'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    return Scaffold(
      backgroundColor: _useMobileLayout ? Colors.white : null,
      appBar: AppBar(
        title: Text(
          isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm mới',
          style: _useMobileLayout
              ? const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                )
              : null,
        ),
        backgroundColor: _useMobileLayout ? Colors.white : null,
        foregroundColor: _useMobileLayout ? const Color(0xFF1E293B) : null,
        elevation: _useMobileLayout ? 0 : null,
        scrolledUnderElevation: _useMobileLayout ? 0.5 : null,
        centerTitle: _useMobileLayout,
        leading: _useMobileLayout
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
      ),
      body: Consumer2<ProductProvider, AuthProvider>(
        builder: (context, productProvider, authProvider, _) {
          if (!(authProvider.shop?.enableCostPrice ?? true) &&
              (_importPriceController.text.isEmpty || _importPriceController.text == '0')) {
            _importPriceController.text = '0';
          }
          final enableCostPrice = authProvider.shop?.enableCostPrice ?? true;
          final params = ProductFormParams(
            formKey: _formKey,
            nameController: _nameController,
            unitController: _unitController,
            importPriceController: _importPriceController,
            priceController: _priceController,
            stockController: _stockController,
            barcodeController: _barcodeController,
            categoryController: _categoryController,
            manufacturerController: _manufacturerController,
            descriptionController: _descriptionController,
            skuController: _skuController,
            imageUrlController: _imageUrlController,
            minStockController: _minStockController,
            maxStockController: _maxStockController,
            selectedCategoryId: _selectedCategoryId,
            categories: productProvider.categories,
            enableCostPrice: enableCostPrice,
            variants: _variants,
            units: _units,
            isInventoryManaged: _isInventoryManaged,
            isImeiManaged: _isImeiManaged,
            isBatchManaged: _isBatchManaged,
            isLoading: _isLoading,
            isScanning: _isScanning,
            isEdit: isEdit,
            onSave: _saveProduct,
            onSaveAndContinue: _saveProductAndContinue,
            onScanBarcode: _scanBarcode,
            onCategoryChanged: (value) => setState(() => _selectedCategoryId = value),
            showAddVariantDialog: _showAddVariantDialog,
            showAddUnitDialog: _showAddUnitDialog,
            showAddAttributeDialog: _showAddAttributeDialog,
            showQuickAddCategoryDialog: () => _showQuickAddCategoryDialog(productProvider),
            onToggleInventoryManaged: (value) => setState(() => _isInventoryManaged = value),
            onToggleImeiManaged: (value) => setState(() => _isImeiManaged = value),
            onToggleBatchManaged: (value) => setState(() => _isBatchManaged = value),
            onRemoveVariant: (index) {
              setState(() {
                _variants.removeAt(index);
                _updateStockDisplay();
              });
            },
            onRemoveUnit: (index) => setState(() => _units.removeAt(index)),
            attributes: _attributes,
            onRemoveAttribute: (index) => setState(() => _attributes.removeAt(index)),
            requestRebuild: () => setState(() {}),
            onShowStockCard: (isEdit && widget.product != null) ? () => _showStockCardSheet(context) : null,
          );
          if (_useMobileLayout) {
            return ProductFormScreenMobile(params: params);
          }
          return ProductFormScreenDesktop(params: params);
        },
      ),
    );
  }
}

/// Màn hình quét mã vạch
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final MobileScannerController controller = MobileScannerController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quét mã vạch'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
            tooltip: 'Bật/tắt đèn flash',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => controller.switchCamera(),
            tooltip: 'Đổi camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  Navigator.pop(context, barcode.rawValue);
                  break;
                }
              }
            },
          ),
          // Overlay với hướng dẫn
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Đưa mã vạch vào khung hình',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

