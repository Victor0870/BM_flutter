import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/sale_model.dart';
import '../../models/product_model.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/product_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../services/firebase_service.dart';
import '../../services/einvoice_service.dart';
import '../../services/sales_service.dart';
import '../../services/product_service.dart';
import '../../models/shop_model.dart';
import '../../services/printing_service.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';
import 'sales_return_form_screen.dart';

/// Màn hình hiển thị chi tiết hóa đơn (mobile/desktop theo platform).
class SaleDetailScreen extends StatefulWidget {
  final SaleModel sale;
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const SaleDetailScreen({
    super.key,
    required this.sale,
    this.forceMobile,
  });

  @override
  State<SaleDetailScreen> createState() => _SaleDetailScreenState();
}

class _SaleDetailScreenState extends State<SaleDetailScreen> {
  ShopModel? _shop;
  bool _isLoadingShop = true;
  bool _isCreatingInvoice = false;
  bool _isCreatingDraftInvoice = false;
  String? _einvoiceUrl; // Lưu link tra cứu hóa đơn điện tử
  /// Tồn kho theo productId (chỉ load khi deductStockOnEinvoiceOnly)
  Map<String, double>? _productStocks;
  /// Danh sách sản phẩm đã chỉnh sửa (chỉ dùng khi deductStockOnEinvoiceOnly)
  List<SaleItem>? _editableItems;

  /// Danh sách items hiện hiển thị (dùng _editableItems nếu có chỉnh sửa)
  List<SaleItem> get _displayItems => _editableItems ?? widget.sale.items;

  /// Tổng tiền gốc của hóa đơn
  double get _originalTotal => widget.sale.totalAmount;

  /// Tổng tiền sau khi thay đổi
  double get _newTotal =>
      _displayItems.fold(0.0, (sum, item) => sum + item.subtotal);

  /// Sai lệch (chênh lệch) giữa tổng mới và tổng gốc
  double get _totalVariance => _newTotal - _originalTotal;

  @override
  void initState() {
    super.initState();
    _loadShopInfo();
  }

  Future<void> _loadProductStocks() async {
    if (_shop == null || !_shop!.deductStockOnEinvoiceOnly) return;
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user == null) return;
      final productService = ProductService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );
      final branchId = widget.sale.branchId.isNotEmpty
          ? widget.sale.branchId
          : authProvider.selectedBranchId ?? 'default';
      final stocks = <String, double>{};
      for (final item in _displayItems) {
        final product = await productService.getProductById(item.productId);
        if (product != null) {
          final stock = branchId.isNotEmpty
              ? (product.branchStock[branchId] ?? product.stock)
              : product.stock;
          stocks[item.productId] = stock;
        }
      }
      if (mounted) setState(() => _productStocks = stocks);
    } catch (_) {}
  }

  void _ensureEditableItems() {
    if (_editableItems == null) {
      setState(() {
        _editableItems = List<SaleItem>.from(widget.sale.items);
      });
    }
  }

  Future<void> _showEditItemDialog(SaleItem item, int index) async {
    if (_shop?.deductStockOnEinvoiceOnly != true) return;
    _ensureEditableItems();
    final productProvider = context.read<ProductProvider>();
    await productProvider.loadProducts();
    if (!mounted) return;
    final qtyController = TextEditingController(text: item.quantity.toStringAsFixed(0));
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Chỉnh sửa dòng'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  title: Text(item.productName),
                  subtitle: Text('Đơn giá: ${NumberFormat('#,###').format(item.price)} đ'),
                  trailing: IconButton(
                    icon: const Icon(Icons.swap_horiz),
                    onPressed: () async {
                      final newProduct = await _showProductPicker();
                      if (newProduct != null && ctx.mounted) {
                        Navigator.pop(ctx, {
                          'action': 'change_product',
                          'product': newProduct,
                          'quantity': double.tryParse(qtyController.text.trim()) ?? item.quantity,
                        });
                      }
                    },
                    tooltip: 'Đổi sản phẩm',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: qtyController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Số lượng',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, {'action': 'delete', 'index': index}),
              child: Text('Xóa dòng', style: TextStyle(color: Colors.red[700])),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                final qty = double.tryParse(qtyController.text.trim()) ?? 0;
                if (qty <= 0) {
                  Navigator.pop(ctx, {'action': 'delete', 'index': index});
                  return;
                }
                Navigator.pop(ctx, {
                  'action': 'update',
                  'productId': item.productId,
                  'productName': item.productName,
                  'price': item.price,
                  'quantity': qty,
                  'vatRate': item.vatRate,
                  'discount': item.discount,
                  'isDiscountPercentage': item.isDiscountPercentage,
                });
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
    qtyController.dispose();
    if (result != null && mounted) {
      setState(() {
        if (result['action'] == 'delete') {
          _editableItems!.removeAt(index);
          if (_editableItems!.isEmpty) _editableItems = null;
        } else if (result['action'] == 'change_product') {
          final p = result['product'] as ProductModel;
          final qty = (result['quantity'] as num).toDouble();
          final branchId = widget.sale.branchId.isNotEmpty
              ? widget.sale.branchId
              : context.read<BranchProvider>().currentBranchId ?? 'default';
          final price = branchId.isNotEmpty && p.branchPrices.containsKey(branchId)
              ? p.branchPrices[branchId]!
              : p.price;
          _editableItems![index] = SaleItem(
            productId: p.id,
            productName: p.name,
            quantity: qty,
            price: price,
            vatRate: widget.sale.vatRate ?? 10.0,
          );
        } else if (result['action'] == 'update') {
          _editableItems![index] = item.copyWith(
            quantity: (result['quantity'] as num).toDouble(),
          );
        }
      });
      _loadProductStocks();
    }
  }

  Future<ProductModel?> _showProductPicker() async {
    await context.read<ProductProvider>().loadProducts();
    if (!mounted) return null;
    final productProvider = context.read<ProductProvider>();
    final branchId = widget.sale.branchId.isNotEmpty
        ? widget.sale.branchId
        : context.read<BranchProvider>().currentBranchId ?? 'default';
    final products = productProvider.products
        .where((p) => p.isSellable && p.isActive)
        .toList();
    return showDialog<ProductModel>(
      context: context,
      builder: (ctx) => _ProductPickerDialog(
        products: products,
        branchId: branchId,
        productProvider: productProvider,
      ),
    );
  }

  Future<void> _showAddItemDialog() async {
    if (_shop?.deductStockOnEinvoiceOnly != true) return;
    _ensureEditableItems();
    final product = await _showProductPicker();
    if (product == null || !mounted) return;
    final branchId = widget.sale.branchId.isNotEmpty
        ? widget.sale.branchId
        : context.read<BranchProvider>().currentBranchId ?? 'default';
    final price = branchId.isNotEmpty && product.branchPrices.containsKey(branchId)
        ? product.branchPrices[branchId]!
        : product.price;
    final qtyController = TextEditingController(text: '1');
    final result = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Thêm: ${product.name}'),
        content: TextField(
          controller: qtyController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Số lượng',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () {
              final qty = double.tryParse(qtyController.text.trim()) ?? 0;
              Navigator.pop(ctx, qty > 0 ? qty : 0.0);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    qtyController.dispose();
    if (result != null && result > 0 && mounted) {
      setState(() {
        _editableItems!.add(SaleItem(
          productId: product.id,
          productName: product.name,
          quantity: result,
          price: price,
          vatRate: widget.sale.vatRate ?? 10.0,
        ));
      });
      _loadProductStocks();
    }
  }

  Future<void> _loadShopInfo() async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user != null) {
        final firebaseService = FirebaseService();
        final shop = await firebaseService.getShopData(authProvider.user!.uid);
        if (!mounted) return;
        setState(() {
          _shop = shop;
          _isLoadingShop = false;
        });
        if (shop?.deductStockOnEinvoiceOnly == true) {
          _loadProductStocks();
        }
      } else {
        setState(() {
          _isLoadingShop = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingShop = false;
      });
    }
  }

  String _formatPaymentMethod(String method) {
    return PaymentMethodType.fromString(method).displayName;
  }

  void _handlePrint() {
    PrintingService.requestPrint(
      context,
      sale: widget.sale,
      shop: _shop,
    );
  }

  Future<void> _createEinvoice() async {
    if (_shop == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không tìm thấy thông tin shop'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Kiểm tra cấu hình hóa đơn điện tử
    if (_shop!.stax == null || _shop!.stax!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấu hình mã số thuế trong Cài đặt Shop'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_shop!.serial == null || _shop!.serial!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấu hình ký hiệu hóa đơn trong Cài đặt Shop'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    if (_shop!.einvoiceConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấu hình thông tin đăng nhập FPT trong Cài đặt Shop'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    setState(() {
      _isCreatingInvoice = true;
    });

    try {
      final einvoiceService = EinvoiceService();
      final authProvider = context.read<AuthProvider>();
      final productService = ProductService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );
      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
        productService: productService,
      );
      
      // Dùng hóa đơn đã chỉnh sửa nếu có
      final saleToUse = _editableItems != null
          ? widget.sale.copyWith(items: _editableItems!)
          : widget.sale;
      final invoiceInfo = await einvoiceService.createInvoice(
        sale: saleToUse,
        shop: _shop!,
        salesService: salesService,
      );

      final link = invoiceInfo['link'] ?? '';
      final finalLink = link.isNotEmpty && link.startsWith('http') ? link : null;
      
      if (!mounted) return;
      
      setState(() {
        _isCreatingInvoice = false;
        _einvoiceUrl = finalLink;
      });
      
      // Hiển thị dialog với link tra cứu
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Tạo hóa đơn điện tử thành công!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hóa đơn điện tử đã được tạo thành công.'),
                const SizedBox(height: 12),
                if (_einvoiceUrl != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Link tra cứu:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _einvoiceUrl!,
                        style: TextStyle(color: Colors.blue[700], fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
              if (_einvoiceUrl != null)
                ElevatedButton(
                  onPressed: () async {
                    final uri = Uri.parse(_einvoiceUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                  child: const Text('Mở link'),
                ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isCreatingInvoice = false;
      });

      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '').replaceFirst('DioException [bad response]: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tạo hóa đơn điện tử: $msg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Xuất hóa đơn nháp (chỉ FPT): tạo trên FPT với trạng thái Chờ phát hành, không cấp số, dùng để test.
  Future<void> _createDraftInvoice() async {
    if (_shop == null || !mounted) return;
    if (_shop!.stax == null || _shop!.stax!.isEmpty || _shop!.serial == null || _shop!.serial!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấu hình mã số thuế và ký hiệu hóa đơn trong Cài đặt Shop'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    if (_shop!.einvoiceConfig == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng cấu hình thông tin đăng nhập FPT trong Cài đặt Shop'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    if (_shop!.einvoiceConfig!.provider != EinvoiceProvider.fpt) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hóa đơn nháp chỉ hỗ trợ FPT. Nhà cung cấp hiện tại: ${_shop!.einvoiceConfig!.provider.label}.'),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    setState(() => _isCreatingDraftInvoice = true);
    try {
      final einvoiceService = EinvoiceService();
      final saleToUse = _editableItems != null
          ? widget.sale.copyWith(items: _editableItems!)
          : widget.sale;
      await einvoiceService.createDraftInvoice(sale: saleToUse, shop: _shop!);
      if (!mounted) return;
      setState(() => _isCreatingDraftInvoice = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo hóa đơn nháp (Chờ phát hành). Bạn có thể xóa trên portal FPT nếu cần.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => _isCreatingDraftInvoice = false);
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '').replaceFirst('DioException [bad response]: ', '');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tạo hóa đơn nháp: $msg'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết hóa đơn'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: _handlePrint,
            tooltip: 'In hóa đơn',
          ),
        ],
      ),
      body: _isLoadingShop
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveContainer(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header - Thông tin shop
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _shop?.name.isNotEmpty == true
                              ? _shop!.name
                              : 'Tên cửa hàng',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_shop?.phone != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'ĐT: ${_shop!.phone}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                        if (_shop?.address != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _shop!.address!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Thông tin đơn hàng
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mã đơn: #${widget.sale.id.substring(0, 8).toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(widget.sale.timestamp)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (widget.sale.customerName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Text(
                            'KH: ${widget.sale.customerName}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blue[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const Divider(height: 32),

                  // Danh sách sản phẩm
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Sản phẩm:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_shop?.deductStockOnEinvoiceOnly == true)
                        TextButton.icon(
                          onPressed: _showAddItemDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Thêm dòng'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Header bảng
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 3,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text(
                              'Tên SP',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Text(
                            'SL',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (_shop?.deductStockOnEinvoiceOnly == true)
                          const Expanded(
                            child: Text(
                              'Tồn kho',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Đơn giá',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Expanded(
                          flex: 1,
                          child: Text(
                            'Giảm giá',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'Thành tiền',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Danh sách items: tên, SL, đơn giá, giảm giá dòng, thành tiền, ghi chú
                  ..._displayItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final stock = _productStocks?[item.productId];
                    final hasInsufficientStock = _shop?.deductStockOnEinvoiceOnly == true &&
                        stock != null &&
                        stock < item.quantity;
                    final isEditable = _shop?.deductStockOnEinvoiceOnly == true;
                    final discountText = item.discount != null && item.discount! > 0
                        ? (item.isDiscountPercentage == true
                            ? '-${item.discount!.toInt()}%'
                            : '-${NumberFormat('#,###', 'vi_VN').format(item.discountAmount.toInt())}đ')
                        : '—';
                    return InkWell(
                      onTap: isEditable ? () => _showEditItemDialog(item, index) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey[200]!,
                              width: 1,
                            ),
                          ),
                          color: isEditable ? Colors.grey[50] : null,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    child: Text(
                                      item.productName,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item.quantity.toStringAsFixed(0),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                if (_shop?.deductStockOnEinvoiceOnly == true)
                                  Expanded(
                                    child: Text(
                                      stock != null
                                          ? stock.toStringAsFixed(0)
                                          : '—',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: hasInsufficientStock
                                            ? Colors.red
                                            : null,
                                        fontWeight: hasInsufficientStock
                                            ? FontWeight.bold
                                            : null,
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    NumberFormat.currency(
                                      locale: 'vi_VN',
                                      symbol: '₫',
                                    ).format(item.price),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    discountText,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: item.discount != null && item.discount! > 0
                                          ? Colors.orange[800]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    NumberFormat.currency(
                                      locale: 'vi_VN',
                                      symbol: '₫',
                                    ).format(item.subtotal),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (item.notes != null && item.notes!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(left: 8, top: 4),
                                child: Text(
                                  'Ghi chú: ${item.notes!}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const Divider(height: 32),

                  // Tổng cộng
                  if (_shop?.deductStockOnEinvoiceOnly == true &&
                      _editableItems != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tổng gốc (hóa đơn):'),
                              Text(
                                NumberFormat.currency(
                                  locale: 'vi_VN',
                                  symbol: '₫',
                                ).format(_originalTotal),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tổng sau thay đổi:'),
                              Text(
                                NumberFormat.currency(
                                  locale: 'vi_VN',
                                  symbol: '₫',
                                ).format(_newTotal),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Chênh lệch:'),
                              Text(
                                '${_totalVariance >= 0 ? '+' : ''}${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(_totalVariance)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _totalVariance > 0
                                      ? Colors.green[700]
                                      : _totalVariance < 0
                                          ? Colors.red[700]
                                          : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _shop?.deductStockOnEinvoiceOnly == true && _editableItems != null
                            ? 'Tổng cộng (gốc):'
                            : 'Tổng cộng:',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        NumberFormat.currency(
                          locale: 'vi_VN',
                          symbol: '₫',
                        ).format(widget.sale.totalAmount),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Phương thức thanh toán
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Thanh toán:',
                        style: TextStyle(fontSize: 14),
                      ),
                      Text(
                        _formatPaymentMethod(widget.sale.paymentMethod),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  if (widget.sale.statusValue != null && widget.sale.statusValue!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Trạng thái:', style: TextStyle(fontSize: 14)),
                        Text(
                          orderStatusDisplayName(widget.sale.statusValue),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (widget.sale.totalPayment != null && widget.sale.totalPayment != widget.sale.totalAmount) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Khách thanh toán:', style: TextStyle(fontSize: 14)),
                        Text(
                          NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(widget.sale.totalPayment!),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],

                  if (widget.sale.notes != null && widget.sale.notes!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ghi chú:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.sale.notes!,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Link tra cứu hóa đơn điện tử (nếu có)
                  if (_einvoiceUrl != null) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.receipt_long, color: Colors.blue[700], size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                'Link tra cứu hóa đơn điện tử:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _einvoiceUrl!,
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final uri = Uri.parse(_einvoiceUrl!);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                } else {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Không thể mở link'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.open_in_browser),
                              label: const Text('Xem hóa đơn online'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue[700],
                                side: BorderSide(color: Colors.blue[300]!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),

                  // Nút Tạo hóa đơn điện tử
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isCreatingInvoice ? null : _createEinvoice,
                      icon: _isCreatingInvoice
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.receipt_long),
                      label: Text(
                        _isCreatingInvoice
                            ? 'Đang tạo hóa đơn...'
                            : 'Tạo hóa đơn điện tử',
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  if (_shop?.einvoiceConfig?.provider == EinvoiceProvider.fpt) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: (_isCreatingDraftInvoice || _isCreatingInvoice) ? null : _createDraftInvoice,
                        icon: _isCreatingDraftInvoice
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.edit_note),
                        label: Text(
                          _isCreatingDraftInvoice ? 'Đang tạo nháp...' : 'Xuất hóa đơn nháp',
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          foregroundColor: Colors.orange[800],
                          side: BorderSide(color: Colors.orange.shade300),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Nút Trả hàng
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Điều hướng đến màn hình trả hàng với hóa đơn đã chọn
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SalesReturnFormScreen(
                              preSelectedSaleId: widget.sale.id,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.undo),
                      label: const Text('Trả hàng'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Nút In
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _handlePrint,
                      icon: const Icon(Icons.print),
                      label: const Text('In hóa đơn'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}

/// Dialog chọn sản phẩm thay thế
class _ProductPickerDialog extends StatefulWidget {
  final List<ProductModel> products;
  final String branchId;
  final ProductProvider productProvider;

  const _ProductPickerDialog({
    required this.products,
    required this.branchId,
    required this.productProvider,
  });

  @override
  State<_ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<_ProductPickerDialog> {
  late List<ProductModel> _filtered;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.products);
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Chọn sản phẩm thay thế'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Tìm sản phẩm...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (q) {
                setState(() {
                  _filtered = q.trim().isEmpty
                      ? List.from(widget.products)
                      : widget.products
                          .where((p) =>
                              p.name.toLowerCase().contains(q.toLowerCase()))
                          .toList();
                });
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (_, i) {
                  final p = _filtered[i];
                  final price = widget.branchId.isNotEmpty &&
                          p.branchPrices.containsKey(widget.branchId)
                      ? p.branchPrices[widget.branchId]!
                      : p.price;
                  final stock = widget.branchId.isNotEmpty &&
                          p.branchStock.containsKey(widget.branchId)
                      ? p.branchStock[widget.branchId]!
                      : p.stock;
                  return ListTile(
                    title: Text(p.name),
                    subtitle: Text(
                      '${NumberFormat('#,###').format(price.toInt())} đ • Tồn: ${stock.toStringAsFixed(0)}',
                    ),
                    onTap: () => Navigator.pop(context, p),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Hủy'),
        ),
      ],
    );
  }
}

