import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../controllers/purchase_provider.dart';
import '../../controllers/product_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../controllers/auth_provider.dart';
import '../../models/product_model.dart';
import '../../models/purchase_model.dart';
import '../../models/branch_model.dart';
import '../../models/unit_conversion.dart';
import '../../widgets/responsive_container.dart';
import '../../widgets/ad_banner_widget.dart';

/// Màn hình nhập kho
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _supplierNameController = TextEditingController();

  @override
  void dispose() {
    _barcodeController.dispose();
    _supplierNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Load products và sync controller với provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = context.read<ProductProvider>();
      final purchaseProvider = context.read<PurchaseProvider>();
      
      // Luôn load products khi mở PurchaseScreen để đảm bảo có dữ liệu mới nhất
      if (!productProvider.isLoading) {
        productProvider.loadProducts();
      }
      
      // Sync controller với provider
      _supplierNameController.text = purchaseProvider.supplierName;
    });
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(),
      ),
    );

    if (result != null && result is String) {
      _barcodeController.text = result;
      _searchAndAddProduct(result);
    }
  }

  Future<void> _searchAndAddProduct(String barcode) async {
    final productProvider = context.read<ProductProvider>();

    // Đảm bảo products đã được load trước khi tìm kiếm
    if (productProvider.products.isEmpty && !productProvider.isLoading) {
      await productProvider.loadProducts();
    }

    // Tìm sản phẩm theo barcode
    await productProvider.searchProducts(barcode);
    final products = productProvider.products
        .where((p) => p.barcode?.toLowerCase() == barcode.toLowerCase())
        .toList();

    if (products.isNotEmpty) {
      _showPurchaseItemDialog(products.first);
      _barcodeController.clear();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy sản phẩm với mã vạch này'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _showProductSelection() async {
    final product = await Navigator.push<ProductModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const PurchaseProductSelectionScreen(),
      ),
    );

    if (product != null && mounted) {
      _showPurchaseItemDialog(product);
    }
  }

  Future<void> _showPurchaseItemDialog(ProductModel product) async {
    final purchaseProvider = context.read<PurchaseProvider>();
    final existingItem = purchaseProvider.cart[product.id];

    final quantityController = TextEditingController(
      text: existingItem?.quantity.toStringAsFixed(0) ?? '1',
    );
    final importPriceController = TextEditingController(
      text: existingItem?.importPrice.toStringAsFixed(0) ?? product.importPrice.toStringAsFixed(0),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nhập hàng: ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: quantityController,
              decoration: const InputDecoration(
                labelText: 'Số lượng nhập',
                hintText: 'Nhập số lượng',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: importPriceController,
              decoration: const InputDecoration(
                labelText: 'Giá nhập',
                hintText: 'Nhập giá nhập',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            if (existingItem != null) ...[
              const SizedBox(height: 8),
              Text(
                'Giá nhập hiện tại: ${product.importPrice.toStringAsFixed(0)} đ',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = double.tryParse(quantityController.text) ?? 0;
              final importPrice = double.tryParse(importPriceController.text) ?? 0;

              if (quantity <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Số lượng phải lớn hơn 0'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (importPrice < 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Giá nhập không hợp lệ'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              purchaseProvider.addToCart(
                product,
                quantity: quantity,
                importPrice: importPrice,
              );

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Đã thêm vào giỏ nhập kho'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );

    quantityController.dispose();
    importPriceController.dispose();
  }

  Future<void> _handleSavePurchase({bool complete = false}) async {
    final purchaseProvider = context.read<PurchaseProvider>();

    if (purchaseProvider.supplierName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng nhập tên nhà cung cấp'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Hiển thị dialog xác nhận
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(complete ? 'Xác nhận nhập kho' : 'Lưu nháp'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhà cung cấp: ${purchaseProvider.supplierName}'),
            const SizedBox(height: 8),
            Text('Tổng tiền: ${_formatPrice(purchaseProvider.cartTotal)} đ'),
            const SizedBox(height: 8),
            Text('Số sản phẩm: ${purchaseProvider.cartItemCount}'),
            if (complete) ...[
              const SizedBox(height: 8),
              const Text(
                '⚠️ Lưu ý: Khi xác nhận, số lượng sẽ được cộng vào tồn kho!',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: complete ? Colors.green : Colors.blue,
            ),
            child: Text(complete ? 'Xác nhận' : 'Lưu'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await purchaseProvider.savePurchase(complete: complete);
      if (mounted) {
        if (success) {
          // Reload products để cập nhật stock mới
          final productProvider = context.read<ProductProvider>();
          await productProvider.loadProducts();
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                complete
                    ? 'Nhập kho thành công! Số lượng đã được cập nhật.'
                    : 'Đã lưu nháp thành công!',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );

          // Quay lại màn hình trước
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                purchaseProvider.errorMessage ?? 'Lưu phiếu nhập thất bại',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhập kho'),
        actions: [
          if (!isMobile(context))
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
              },
              tooltip: 'Về trang chủ',
            ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.pushNamed(context, '/purchase-history');
            },
            tooltip: 'Lịch sử nhập kho',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ResponsiveContainer(
              maxWidth: 800,
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  // Thanh tìm kiếm mã vạch và nhà cung cấp (responsive)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < kBreakpointMobile;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.grey[100],
                        child: Column(
                          children: [
                            // Nhà cung cấp
                            TextField(
                    controller: _supplierNameController,
                    decoration: InputDecoration(
                      labelText: 'Nhà cung cấp *',
                      hintText: 'Nhập tên nhà cung cấp',
                      prefixIcon: const Icon(Icons.business),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      context.read<PurchaseProvider>().setSupplierName(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Chi nhánh nhập kho
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Consumer2<AuthProvider, BranchProvider>(
                      builder: (context, authProvider, branchProvider, child) {
                        final branches = branchProvider.branches
                            .where((b) => b.isActive)
                            .toList();
                        final selectedBranchId = authProvider.selectedBranchId;

                        return SizedBox(
                          width: isNarrow ? double.infinity : 320,
                          child: DropdownButtonFormField<String?>(
                            initialValue: selectedBranchId,
                            decoration: InputDecoration(
                              labelText: 'Chi nhánh nhập *',
                              prefixIcon: const Icon(Icons.store),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: [
                              // Không có option "Không có" nữa, mặc định là "Cửa hàng chính"
                              ...branches.map(
                                (branch) => DropdownMenuItem<String?>(
                                  value: branch.id,
                                  child: Text(branch.name),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              // Nếu value null, mặc định là "Cửa hàng chính"
                              authProvider.setSelectedBranchId(value ?? kMainStoreBranchId);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tìm kiếm mã vạch (trên mobile xuống dòng)
                  isNarrow
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _barcodeController,
                              decoration: InputDecoration(
                                hintText: 'Nhập hoặc quét mã vạch',
                                prefixIcon: const Icon(Icons.qr_code_scanner),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.camera_alt),
                                  onPressed: _scanBarcode,
                                  tooltip: 'Quét mã vạch',
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onSubmitted: _searchAndAddProduct,
                            ),
                            const SizedBox(height: 8),
                            IconButton(
                              icon: const Icon(Icons.list),
                              onPressed: _showProductSelection,
                              tooltip: 'Chọn sản phẩm',
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _barcodeController,
                                decoration: InputDecoration(
                                  hintText: 'Nhập hoặc quét mã vạch',
                                  prefixIcon: const Icon(Icons.qr_code_scanner),
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.camera_alt),
                                    onPressed: _scanBarcode,
                                    tooltip: 'Quét mã vạch',
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onSubmitted: _searchAndAddProduct,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.list),
                              onPressed: _showProductSelection,
                              tooltip: 'Chọn sản phẩm',
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(16),
                              ),
                            ),
                          ],
                        ),
                            ],
                          ),
                        );
                      },
                    ),
                  // Giỏ hàng nhập kho
                  Expanded(
            child: Consumer<PurchaseProvider>(
              builder: (context, purchaseProvider, child) {
                if (purchaseProvider.isCartEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Giỏ nhập kho trống',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Quét mã vạch hoặc chọn sản phẩm để bắt đầu',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Danh sách sản phẩm trong giỏ
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: purchaseProvider.cartItems.length,
                        itemBuilder: (context, index) {
                          final item = purchaseProvider.cartItems[index];
                          return _PurchaseItemCard(
                            item: item,
                            onEdit: () {
                              // Lấy product để edit
                              context.read<ProductProvider>().loadProducts();
                              final products = context.read<ProductProvider>().products;
                              final product = products.firstWhere(
                              (p) => p.id == item.productId,
                              orElse: () => ProductModel(
                                id: item.productId,
                                name: item.productName,
                                units: [
                                  UnitConversion(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                    unitName: 'cái',
                                    conversionValue: 1.0,
                                    price: 0,
                                  )
                                ],
                                branchPrices: {'default': 0},
                                importPrice: item.importPrice,
                                branchStock: {'default': 0},
                              ),
                              );
                              _showPurchaseItemDialog(product);
                            },
                            onRemove: () {
                              purchaseProvider.removeFromCart(item.productId);
                            },
                            onUpdate: (quantity, importPrice) {
                              purchaseProvider.updateCartItem(
                                item.productId,
                                quantity: quantity,
                                importPrice: importPrice,
                              );
                            },
                          );
                        },
                      ),
                    ),

                    // Tổng tiền và nút lưu
                    SafeArea(
                      top: false,
                      bottom: true, // Đảm bảo nội dung không bị che bởi thanh điều hướng hệ thống
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tổng tiền:',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_formatPrice(purchaseProvider.cartTotal)} đ',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: purchaseProvider.isLoading
                                      ? null
                                      : () => _handleSavePurchase(complete: false),
                                  child: const Text('Lưu nháp'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: purchaseProvider.isLoading
                                      ? null
                                      : () => _handleSavePurchase(complete: true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: purchaseProvider.isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text('Xác nhận nhập'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
        ),
        ),
      ),
      const SafeArea(
        top: false,
        child: AdBannerWidget(),
      ),
      ],
      ),
    );
  }
}

/// Widget hiển thị một item trong giỏ nhập kho với khả năng chỉnh sửa nhanh
class _PurchaseItemCard extends StatefulWidget {
  final PurchaseItem item;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final Function(double, double) onUpdate; // quantity, importPrice

  const _PurchaseItemCard({
    required this.item,
    required this.onEdit,
    required this.onRemove,
    required this.onUpdate,
  });

  @override
  State<_PurchaseItemCard> createState() => _PurchaseItemCardState();
}

class _PurchaseItemCardState extends State<_PurchaseItemCard> {
  late TextEditingController _quantityController;
  late TextEditingController _priceController;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _quantityController = TextEditingController(
      text: widget.item.quantity.toStringAsFixed(0),
    );
    _priceController = TextEditingController(
      text: widget.item.importPrice.toStringAsFixed(0),
    );
  }

  @override
  void didUpdateWidget(_PurchaseItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.quantity != widget.item.quantity ||
        oldWidget.item.importPrice != widget.item.importPrice) {
      _quantityController.text = widget.item.quantity.toStringAsFixed(0);
      _priceController.text = widget.item.importPrice.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _saveChanges() {
    final quantity = double.tryParse(_quantityController.text) ?? 0;
    final price = double.tryParse(_priceController.text) ?? 0;
    
    if (quantity > 0 && price >= 0) {
      widget.onUpdate(quantity, price);
      setState(() {
        _isEditing = false;
      });
    } else {
      // Reset về giá trị cũ nếu không hợp lệ
      _quantityController.text = widget.item.quantity.toStringAsFixed(0);
      _priceController.text = widget.item.importPrice.toStringAsFixed(0);
      setState(() {
        _isEditing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giá trị không hợp lệ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tên sản phẩm
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.item.productName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (!_isEditing)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () {
                          setState(() {
                            _isEditing = true;
                          });
                        },
                        tooltip: 'Sửa nhanh',
                        color: Colors.blue,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        color: Colors.red,
                        onPressed: widget.onRemove,
                        tooltip: 'Xóa',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, size: 20),
                        color: Colors.green,
                        onPressed: _saveChanges,
                        tooltip: 'Lưu',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        color: Colors.grey,
                        onPressed: () {
                          _quantityController.text = widget.item.quantity.toStringAsFixed(0);
                          _priceController.text = widget.item.importPrice.toStringAsFixed(0);
                          setState(() {
                            _isEditing = false;
                          });
                        },
                        tooltip: 'Hủy',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Thông tin số lượng và giá
            if (_isEditing) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Số lượng',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Giá nhập',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SL: ${widget.item.quantity.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Giá nhập: ${widget.item.importPrice.toStringAsFixed(0)} đ',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Thành tiền: ${widget.item.subtotal.toStringAsFixed(0)} đ',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Màn hình chọn sản phẩm để nhập kho
class PurchaseProductSelectionScreen extends StatefulWidget {
  const PurchaseProductSelectionScreen({super.key});

  @override
  State<PurchaseProductSelectionScreen> createState() => _PurchaseProductSelectionScreenState();
}

class _PurchaseProductSelectionScreenState extends State<PurchaseProductSelectionScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load products khi mở màn hình chọn sản phẩm nhập kho
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final productProvider = context.read<ProductProvider>();
      // Luôn load products khi mở màn hình này để đảm bảo có dữ liệu mới nhất
      productProvider.loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chọn sản phẩm nhập kho'),
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm sản phẩm...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          context.read<ProductProvider>().clearSearch();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (query) {
                context.read<ProductProvider>().searchProducts(query);
              },
            ),
          ),
          // Danh sách sản phẩm
          Expanded(
            child: Consumer<ProductProvider>(
              builder: (context, productProvider, child) {
                if (productProvider.isLoading && productProvider.products.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (productProvider.products.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: () => productProvider.loadProducts(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.7,
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Chưa có sản phẩm nào',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Kéo xuống để làm mới',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => productProvider.loadProducts(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: productProvider.products.length,
                    itemBuilder: (context, index) {
                      final product = productProvider.products[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: const Icon(
                            Icons.inventory_2,
                            color: Colors.blue,
                          ),
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          'Giá nhập: ${product.importPrice.toStringAsFixed(0)} đ - Tồn: ${product.stock.toStringAsFixed(0)} ${product.unit}',
                        ),
                        trailing: const Icon(Icons.add_shopping_cart),
                        onTap: () => Navigator.pop(context, product),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Màn hình quét mã vạch (reuse từ sales_screen)
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

