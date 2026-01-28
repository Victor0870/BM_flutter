import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../controllers/product_provider.dart';
import '../../controllers/auth_provider.dart';
import '../../models/product_model.dart';
import '../../models/unit_conversion.dart';
import '../../models/category_model.dart';
import '../../widgets/responsive_container.dart';

/// Màn hình thêm/sửa sản phẩm
class ProductFormScreen extends StatefulWidget {
  final ProductModel? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _unitController = TextEditingController();
  final _importPriceController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _categoryController = TextEditingController(); // Backward compatibility
  final _manufacturerController = TextEditingController();
  final _skuController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _minStockController = TextEditingController();
  final _maxStockController = TextEditingController();

  String? _selectedCategoryId; // ID của CategoryModel
  List<ProductVariant> _variants = [];
  List<UnitConversion> _units = []; // Danh sách đơn vị quy đổi
  
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
    _skuController.text = product.sku ?? '';
    _imageUrlController.text = product.imageUrl ?? '';
    _minStockController.text = product.minStock?.toStringAsFixed(0) ?? '';
    _maxStockController.text = product.maxStock?.toStringAsFixed(0) ?? '';
    _selectedCategoryId = product.categoryId;
    _variants = List.from(product.variants);
    _units = List.from(product.units);
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
        _skuController.clear();
        _imageUrlController.clear();
        _minStockController.clear();
        _maxStockController.clear();
        _selectedCategoryId = null;
        _variants.clear();
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
      minStock: _minStockController.text.trim().isEmpty
          ? null
          : double.tryParse(_minStockController.text),
      maxStock: _maxStockController.text.trim().isEmpty
          ? null
          : double.tryParse(_maxStockController.text),
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

                if (mounted) {
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

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Sửa sản phẩm' : 'Thêm sản phẩm mới'),
      ),
      body: ResponsiveContainer(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
            // Tên sản phẩm
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Tên sản phẩm *',
                hintText: 'Nhập tên sản phẩm',
                prefixIcon: Icon(Icons.inventory_2),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập tên sản phẩm';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Đơn vị tính
            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'Đơn vị tính *',
                hintText: 'Ví dụ: cái, kg, lít, thùng...',
                prefixIcon: Icon(Icons.scale),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập đơn vị tính';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Giá nhập - chỉ hiển thị nếu enableCostPrice = true
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final enableCostPrice = authProvider.shop?.enableCostPrice ?? true;
                
                if (!enableCostPrice) {
                  // Nếu không sử dụng giá nhập, set giá trị mặc định là 0
                  if (_importPriceController.text.isEmpty || _importPriceController.text == '0') {
                    _importPriceController.text = '0';
                  }
                  return const SizedBox.shrink();
                }
                
                return Column(
                  children: [
                    TextFormField(
                      controller: _importPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Giá nhập *',
                        hintText: '0',
                        prefixIcon: Icon(Icons.arrow_downward),
                        suffixText: 'đ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Vui lòng nhập giá nhập';
                        }
                        if (double.tryParse(value) == null || double.parse(value) < 0) {
                          return 'Giá nhập phải là số hợp lệ';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),

            // Giá bán
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Giá bán *',
                hintText: '0',
                prefixIcon: Icon(Icons.arrow_upward),
                suffixText: 'đ',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Vui lòng nhập giá bán';
                }
                if (double.tryParse(value) == null || double.parse(value) < 0) {
                  return 'Giá bán phải là số hợp lệ';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Mã vạch với nút quét
            TextFormField(
              controller: _barcodeController,
              decoration: InputDecoration(
                labelText: 'Mã vạch',
                hintText: 'Nhập mã vạch hoặc quét',
                prefixIcon: const Icon(Icons.qr_code_scanner),
                suffixIcon: IconButton(
                  icon: _isScanning
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt),
                  onPressed: _scanBarcode,
                  tooltip: 'Quét mã vạch',
                ),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.text,
            ),
            const SizedBox(height: 16),

            // Số lượng tồn kho (Read-only)
            TextFormField(
              controller: _stockController,
              decoration: InputDecoration(
                labelText: 'Số lượng tồn kho',
                hintText: '0',
                prefixIcon: const Icon(Icons.inventory),
                suffixIcon: Icon(
                  Icons.lock_outline,
                  color: Colors.grey[600],
                  size: 20,
                ),
                helperText: 'Chỉ đọc - Sử dụng chức năng "Nhập kho" hoặc "Xuất kho" để thay đổi',
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              keyboardType: TextInputType.number,
              readOnly: true,
              enabled: false,
            ),
            const SizedBox(height: 16),

            // SKU
            TextFormField(
              controller: _skuController,
              decoration: const InputDecoration(
                labelText: 'Mã SKU',
                hintText: 'Mã sản phẩm (SKU)',
                prefixIcon: Icon(Icons.label),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Nhóm hàng (Category) - Dropdown với nút thêm nhanh
            Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Nhóm hàng',
                          hintText: 'Chọn nhóm hàng',
                          prefixIcon: Icon(Icons.category),
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Không chọn'),
                          ),
                          ...productProvider.categories.map((category) {
                            return DropdownMenuItem<String>(
                              value: category.id,
                              child: Text(category.name),
                            );
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryId = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => _showQuickAddCategoryDialog(productProvider),
                      tooltip: 'Tạo nhanh nhóm hàng mới',
                      style: IconButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            // Danh mục cũ (backward compatibility)
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Danh mục (tùy chọn)',
                hintText: 'Hoặc nhập danh mục cũ...',
                prefixIcon: Icon(Icons.text_fields),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            // Ảnh sản phẩm (ImageUrl)
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                labelText: 'Link ảnh sản phẩm',
                hintText: 'https://example.com/image.jpg',
                prefixIcon: Icon(Icons.image),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              onChanged: (value) {
                setState(() {}); // Trigger rebuild để hiển thị preview
              },
            ),
            const SizedBox(height: 8),
            // Preview ảnh
            if (_imageUrlController.text.isNotEmpty)
              Container(
                height: 150,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _imageUrlController.text,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image, size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Không thể tải ảnh',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ),

            // Định mức tồn kho
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minStockController,
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
                    controller: _maxStockController,
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
            ),
            const SizedBox(height: 24),

            // Đơn vị quy đổi
            const Divider(),
            Row(
              children: [
                const Icon(Icons.swap_horiz, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Đơn vị quy đổi',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Thêm các đơn vị quy đổi (VD: 1 Thùng = 24 Lon)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            if (_units.isEmpty)
              TextButton.icon(
                onPressed: () => _showAddUnitDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Thêm đơn vị quy đổi'),
              ),
            if (_units.isNotEmpty) ...[
              ..._units.asMap().entries.map((entry) {
                final index = entry.key;
                final unit = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      unit.unitName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hệ số: ${unit.conversionValue}'),
                        Text('Giá bán: ${unit.price.toStringAsFixed(0)} đ'),
                        if (unit.barcode != null)
                          Text('Mã vạch: ${unit.barcode}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showAddUnitDialog(index: index),
                          tooltip: 'Sửa',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _units.removeAt(index);
                            });
                          },
                          tooltip: 'Xóa',
                        ),
                      ],
                    ),
                  ),
                );
              }),
              ElevatedButton.icon(
                onPressed: () => _showAddUnitDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Thêm đơn vị quy đổi'),
              ),
            ],
            const SizedBox(height: 24),

            // Cấu hình Loại hình sản phẩm
            const Divider(),
            Row(
              children: [
                const Icon(Icons.settings, color: Colors.orange),
                const SizedBox(width: 8),
                const Text(
                  'Cấu hình loại hình',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('Quản lý tồn kho'),
              subtitle: const Text('Theo dõi số lượng tồn kho'),
              value: _isInventoryManaged,
              onChanged: (value) {
                setState(() {
                  _isInventoryManaged = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Quản lý IMEI'),
              subtitle: const Text('Cho hàng công nghệ (điện thoại, máy tính...)'),
              value: _isImeiManaged,
              onChanged: (value) {
                setState(() {
                  _isImeiManaged = value;
                });
              },
            ),
            SwitchListTile(
              title: const Text('Quản lý lô hạn sử dụng'),
              subtitle: const Text('Cho hàng thực phẩm, thuốc có hạn sử dụng'),
              value: _isBatchManaged,
              onChanged: (value) {
                setState(() {
                  _isBatchManaged = value;
                });
              },
            ),
            const SizedBox(height: 16),

            // Nhà sản xuất
            TextFormField(
              controller: _manufacturerController,
              decoration: const InputDecoration(
                labelText: 'Nhà sản xuất',
                hintText: 'Tên nhà sản xuất',
                prefixIcon: Icon(Icons.business),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Biến thể sản phẩm
            const Divider(),
            Row(
              children: [
                const Icon(Icons.style, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  'Biến thể sản phẩm',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Thêm các biến thể như: Size (S, M, L), Màu sắc, v.v.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            if (_variants.isEmpty)
              TextButton.icon(
                onPressed: () => _showAddVariantDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Thêm biến thể đầu tiên'),
              ),
            if (_variants.isNotEmpty) ...[
              ..._variants.asMap().entries.map((entry) {
                final index = entry.key;
                final variant = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      variant.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('SKU: ${variant.sku}'),
                        Text('Giá: ${variant.price.toStringAsFixed(0)} đ'),
                        Text('Tồn kho: ${variant.stock.toStringAsFixed(0)}'),
                        if (variant.barcode != null)
                          Text('Mã vạch: ${variant.barcode}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showAddVariantDialog(index: index),
                          tooltip: 'Sửa',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _variants.removeAt(index);
                              _updateStockDisplay();
                            });
                          },
                          tooltip: 'Xóa',
                        ),
                      ],
                    ),
                  ),
                );
              }),
              ElevatedButton.icon(
                onPressed: () => _showAddVariantDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Thêm biến thể'),
              ),
            ],
            const SizedBox(height: 24),

            // Nút Lưu
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isLoading ? null : _saveProductAndContinue,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text(
                            'Lưu và thêm tiếp',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveProduct,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isEdit ? 'Cập nhật' : 'Thêm sản phẩm',
                            style: const TextStyle(fontSize: 16),
                          ),
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
                color: Colors.black.withOpacity(0.7),
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

