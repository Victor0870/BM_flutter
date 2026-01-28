import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../models/sale_model.dart';
import '../../models/sales_return_model.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../services/sales_service.dart';
import '../../services/sales_return_service.dart';
import '../../services/product_service.dart';
import '../../services/customer_service.dart';
import '../../widgets/responsive_container.dart';
import 'sales_history_screen.dart';

/// Màn hình tạo hóa đơn trả hàng
class SalesReturnFormScreen extends StatefulWidget {
  final String? preSelectedSaleId; // ID hóa đơn được chọn sẵn từ màn hình chi tiết

  const SalesReturnFormScreen({
    super.key,
    this.preSelectedSaleId,
  });

  @override
  State<SalesReturnFormScreen> createState() => _SalesReturnFormScreenState();
}

class _SalesReturnFormScreenState extends State<SalesReturnFormScreen> {
  final TextEditingController _saleIdController = TextEditingController();
  Map<String, TextEditingController> _returnQuantityControllers = {};
  Map<String, double> _returnQuantities = {};
  
  SaleModel? _originalSale;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isSearching = false;
  bool _showScanner = false;
  List<SaleModel> _recentSales = []; // Danh sách hóa đơn gần đây để gợi ý
  bool _isLoadingSuggestions = false;
  Timer? _searchDebounceTimer; // Timer để debounce tìm kiếm
  
  // Form fields
  String _selectedReason = 'Lỗi NSX';
  String _selectedPaymentMethod = 'CASH';
  
  // Danh sách lý do trả hàng
  final List<String> _returnReasons = [
    'Lỗi NSX',
    'Khách đổi ý',
    'Hàng hết hạn',
    'Hàng hỏng',
    'Không đúng mẫu mã',
    'Khác',
  ];
  
  // Danh sách phương thức hoàn tiền
  final List<Map<String, String>> _paymentMethods = [
    {'value': 'CASH', 'label': 'Tiền mặt'},
    {'value': 'TRANSFER', 'label': 'Chuyển khoản'},
    {'value': 'DEBT', 'label': 'Trừ vào công nợ'},
  ];

  @override
  void initState() {
    super.initState();
    // Nếu có preSelectedSaleId, tự động load hóa đơn đó
    if (widget.preSelectedSaleId != null) {
      _saleIdController.text = widget.preSelectedSaleId!;
      // Đợi một chút để đảm bảo widget đã build xong
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchSale();
      });
    }
    
    // Load danh sách hóa đơn gần đây khi khởi tạo
    _loadRecentSales();
    
    // Lắng nghe thay đổi trong TextField để tìm kiếm gợi ý
    _saleIdController.addListener(_onSearchTextChanged);
  }

  @override
  void dispose() {
    _saleIdController.removeListener(_onSearchTextChanged);
    _searchDebounceTimer?.cancel();
    _saleIdController.dispose();
    for (var controller in _returnQuantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Load danh sách hóa đơn gần đây (30 ngày gần nhất)
  Future<void> _loadRecentSales() async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user == null) return;

      setState(() {
        _isLoadingSuggestions = true;
      });

      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );

      final endDate = DateTime.now();
      final startDate = endDate.subtract(const Duration(days: 30));

      final sales = await salesService.getSales(
        startDate: startDate,
        endDate: endDate,
      );

      // Sắp xếp theo thời gian mới nhất
      sales.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _recentSales = sales;
        _isLoadingSuggestions = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSuggestions = false;
      });
    }
  }

  /// Xử lý khi text thay đổi trong TextField (với debounce)
  void _onSearchTextChanged() {
    // Hủy timer cũ nếu có
    _searchDebounceTimer?.cancel();
    
    // Tạo timer mới với delay 300ms
    _searchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
      final query = _saleIdController.text.trim();
      if (query.isEmpty) {
        // Nếu rỗng, load lại danh sách gần đây
        _loadRecentSales();
      }
      // Autocomplete sẽ tự động cập nhật khi text thay đổi
    });
  }

  /// Tìm kiếm hóa đơn theo từ khóa
  List<SaleModel> _getSuggestions(String query) {
    if (query.isEmpty) {
      // Trả về 10 hóa đơn gần nhất
      return _recentSales.take(10).toList();
    }

    final lowerQuery = query.toLowerCase();
    return _recentSales.where((sale) {
      // Tìm theo ID (8 ký tự đầu)
      final saleIdShort = sale.id.substring(0, sale.id.length > 8 ? 8 : sale.id.length).toLowerCase();
      if (saleIdShort.contains(lowerQuery)) return true;

      // Tìm theo tên khách hàng
      if (sale.customerName != null && sale.customerName!.toLowerCase().contains(lowerQuery)) {
        return true;
      }

      // Tìm theo ID đầy đủ
      if (sale.id.toLowerCase().contains(lowerQuery)) return true;

      return false;
    }).take(10).toList();
  }

  /// Tìm kiếm hóa đơn gốc
  Future<void> _searchSale() async {
    final saleId = _saleIdController.text.trim();
    if (saleId.isEmpty) {
      setState(() {
        _errorMessage = 'Vui lòng nhập mã hóa đơn';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _originalSale = null;
      _returnQuantities.clear();
      for (var controller in _returnQuantityControllers.values) {
        controller.dispose();
      }
      _returnQuantityControllers.clear();
    });

    try {
      final authProvider = context.read<AuthProvider>();
      if (authProvider.user == null) {
        setState(() {
          _errorMessage = 'Chưa đăng nhập';
          _isSearching = false;
        });
        return;
      }

      final salesService = SalesService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );

      final sale = await salesService.getSaleById(saleId);
      
      if (sale == null) {
        setState(() {
          _errorMessage = 'Không tìm thấy hóa đơn với mã: $saleId';
          _isSearching = false;
        });
        return;
      }

      // Khởi tạo controllers và quantities cho từng item
      final quantities = <String, double>{};
      final controllers = <String, TextEditingController>{};
      
      for (var item in sale.items) {
        quantities[item.productId] = 0.0;
        controllers[item.productId] = TextEditingController(text: '0');
        controllers[item.productId]!.addListener(() {
          _updateReturnQuantity(item.productId, controllers[item.productId]!.text);
        });
      }

      setState(() {
        _originalSale = sale;
        _returnQuantities = quantities;
        _returnQuantityControllers = controllers;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi tìm kiếm hóa đơn: $e';
        _isSearching = false;
      });
    }
  }

  /// Cập nhật số lượng trả
  void _updateReturnQuantity(String productId, String value) {
    final quantity = double.tryParse(value) ?? 0.0;
    setState(() {
      _returnQuantities[productId] = quantity;
    });
  }

  /// Tính tổng tiền hoàn trả
  double _calculateTotalRefund() {
    if (_originalSale == null) return 0.0;
    
    double total = 0.0;
    for (var item in _originalSale!.items) {
      final returnQty = _returnQuantities[item.productId] ?? 0.0;
      if (returnQty > 0) {
        // Tính theo giá gốc của item (đã bao gồm chiết khấu nếu có)
        total += item.subtotal * (returnQty / item.quantity);
      }
    }
    return total;
  }

  /// Lấy danh sách items cần trả (có số lượng > 0)
  List<SaleItem> _getReturnItems() {
    if (_originalSale == null) return [];
    
    return _originalSale!.items.where((item) {
      final returnQty = _returnQuantities[item.productId] ?? 0.0;
      return returnQty > 0;
    }).map((item) {
      final returnQty = _returnQuantities[item.productId] ?? 0.0;
      return item.copyWith(quantity: returnQty);
    }).toList();
  }

  /// Kiểm tra tính hợp lệ của form
  bool _validateForm() {
    if (_originalSale == null) {
      _errorMessage = 'Vui lòng tìm hóa đơn gốc';
      return false;
    }

    final returnItems = _getReturnItems();
    if (returnItems.isEmpty) {
      _errorMessage = 'Vui lòng chọn ít nhất một sản phẩm để trả';
      return false;
    }

    // Kiểm tra số lượng trả không vượt quá số lượng đã mua
    for (var item in _originalSale!.items) {
      final returnQty = _returnQuantities[item.productId] ?? 0.0;
      if (returnQty > item.quantity) {
        _errorMessage = 'Số lượng trả của "${item.productName}" không được vượt quá ${item.quantity}';
        return false;
      }
    }

    if (_selectedReason.isEmpty) {
      _errorMessage = 'Vui lòng chọn lý do trả hàng';
      return false;
    }

    return true;
  }

  /// Hiển thị dialog xác nhận
  Future<bool> _showConfirmationDialog() async {
    final returnItems = _getReturnItems();
    final totalRefund = _calculateTotalRefund();
    final branchProvider = context.read<BranchProvider>();
    final branchId = branchProvider.currentBranchId ?? '';
    String branchName = 'chi nhánh hiện tại';
    if (branchId.isNotEmpty && branchProvider.branches.isNotEmpty) {
      final branch = branchProvider.branches.firstWhere(
        (b) => b.id == branchId,
        orElse: () => branchProvider.branches.first,
      );
      branchName = branch.name;
    }
    
    // Đếm số sản phẩm cần cộng lại vào kho (chỉ những sản phẩm có isInventoryManaged = true)
    int inventoryItemsCount = 0;
    final productService = ProductService(
      isPro: context.read<AuthProvider>().isPro,
      userId: context.read<AuthProvider>().user!.uid,
    );
    
    for (var item in returnItems) {
      try {
        final product = await productService.getProductById(item.productId);
        if (product != null && product.isInventoryManaged) {
          inventoryItemsCount++;
        }
      } catch (e) {
        // Bỏ qua nếu không tìm thấy sản phẩm
      }
    }

    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận trả hàng'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bạn có chắc chắn muốn trả hàng?'),
            const SizedBox(height: 16),
            if (inventoryItemsCount > 0)
              Text(
                '• Sẽ cộng lại $inventoryItemsCount sản phẩm vào kho $branchName',
                style: const TextStyle(fontSize: 14),
              ),
            Text(
              '• Sẽ hoàn trả ${NumberFormat.currency(locale: 'vi_VN', symbol: '₫').format(totalRefund)} cho khách hàng',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Lý do: $_selectedReason',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
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
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    ) ?? false;
  }

  /// Lưu hóa đơn trả hàng
  Future<void> _saveSalesReturn() async {
    if (!_validateForm()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? 'Vui lòng kiểm tra lại thông tin'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final branchProvider = context.read<BranchProvider>();
      
      if (authProvider.user == null) {
        throw Exception('Chưa đăng nhập');
      }

      final returnItems = _getReturnItems();
      final totalRefund = _calculateTotalRefund();
      final branchId = branchProvider.currentBranchId ?? authProvider.selectedBranchId ?? '';

      if (branchId.isEmpty) {
        throw Exception('Chưa chọn chi nhánh');
      }

      // Tạo SalesReturnModel
      final salesReturn = SalesReturnModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        originalSaleId: _originalSale!.id,
        customerId: _originalSale!.customerId,
        branchId: branchId,
        items: returnItems,
        totalRefundAmount: totalRefund,
        reason: _selectedReason,
        paymentMethod: _selectedPaymentMethod,
        timestamp: DateTime.now(),
        userId: authProvider.user!.uid,
      );

      // Khởi tạo services
      final productService = ProductService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );

      final customerService = CustomerService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
      );

      final salesReturnService = SalesReturnService(
        isPro: authProvider.isPro,
        userId: authProvider.user!.uid,
        productService: productService,
      );

      // Lưu hóa đơn trả hàng (sẽ tự động cập nhật kho và công nợ)
      await salesReturnService.saveSalesReturn(
        salesReturn,
        customerService: customerService,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trả hàng thành công!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Điều hướng về màn hình lịch sử bán hàng
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const SalesHistoryScreen(),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Lỗi khi lưu hóa đơn trả hàng: $e';
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage ?? 'Có lỗi xảy ra'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trả hàng'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ResponsiveContainer(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Phần tìm kiếm hóa đơn
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Tìm hóa đơn gốc',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Autocomplete<SaleModel>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return _getSuggestions('');
                                }
                                return _getSuggestions(textEditingValue.text);
                              },
                              displayStringForOption: (SaleModel sale) {
                                // Hiển thị mã hóa đơn (8 ký tự đầu) và tên khách hàng nếu có
                                final saleIdShort = sale.id.substring(0, sale.id.length > 8 ? 8 : sale.id.length).toUpperCase();
                                if (sale.customerName != null && sale.customerName!.isNotEmpty) {
                                  return '$saleIdShort - ${sale.customerName}';
                                }
                                return saleIdShort;
                              },
                              onSelected: (SaleModel sale) {
                                _saleIdController.text = sale.id;
                                _searchSale();
                              },
                              fieldViewBuilder: (
                                BuildContext context,
                                TextEditingController textEditingController,
                                FocusNode focusNode,
                                VoidCallback onFieldSubmitted,
                              ) {
                                // Sử dụng controller của chúng ta
                                return TextField(
                                  controller: _saleIdController,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Mã hóa đơn',
                                    hintText: 'Nhập hoặc quét mã hóa đơn',
                                    border: const OutlineInputBorder(),
                                    prefixIcon: const Icon(Icons.receipt),
                                    suffixIcon: _isLoadingSuggestions
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: Padding(
                                              padding: EdgeInsets.all(12),
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          )
                                        : null,
                                  ),
                                  onSubmitted: (_) {
                                    onFieldSubmitted();
                                    _searchSale();
                                  },
                                );
                              },
                              optionsViewBuilder: (
                                BuildContext context,
                                AutocompleteOnSelected<SaleModel> onSelected,
                                Iterable<SaleModel> options,
                              ) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    borderRadius: BorderRadius.circular(8),
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxHeight: 200),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        padding: EdgeInsets.zero,
                                        itemCount: options.length,
                                        itemBuilder: (BuildContext context, int index) {
                                          final sale = options.elementAt(index);
                                          final saleIdShort = sale.id.substring(0, sale.id.length > 8 ? 8 : sale.id.length).toUpperCase();
                                          
                                          return InkWell(
                                            onTap: () => onSelected(sale),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border(
                                                  bottom: BorderSide(
                                                    color: Colors.grey.shade200,
                                                    width: index < options.length - 1 ? 1 : 0,
                                                  ),
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.receipt,
                                                    size: 20,
                                                    color: Colors.blue.shade600,
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          saleIdShort,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        if (sale.customerName != null && sale.customerName!.isNotEmpty) ...[
                                                          const SizedBox(height: 2),
                                                          Text(
                                                            sale.customerName!,
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color: Colors.grey.shade600,
                                                            ),
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    DateFormat('dd/MM/yyyy').format(sale.timestamp),
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey.shade500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(_showScanner ? Icons.close : Icons.qr_code_scanner),
                            onPressed: () {
                              setState(() {
                                _showScanner = !_showScanner;
                              });
                            },
                            tooltip: 'Quét mã',
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: _isSearching ? null : _searchSale,
                            icon: _isSearching
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.search),
                            label: const Text('Tìm'),
                          ),
                        ],
                      ),
                      if (_showScanner) ...[
                        const SizedBox(height: 16),
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: MobileScanner(
                              onDetect: (capture) {
                                final List<Barcode> barcodes = capture.barcodes;
                                for (final barcode in barcodes) {
                                  if (barcode.rawValue != null) {
                                    _saleIdController.text = barcode.rawValue!;
                                    setState(() {
                                      _showScanner = false;
                                    });
                                    _searchSale();
                                    break;
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                      if (_errorMessage != null && _originalSale == null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Hiển thị thông tin hóa đơn và danh sách sản phẩm
              if (_originalSale != null) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hóa đơn #${_originalSale!.id.substring(0, 8).toUpperCase()}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('dd/MM/yyyy HH:mm').format(_originalSale!.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            if (_originalSale!.customerName != null)
                              Chip(
                                label: Text('KH: ${_originalSale!.customerName}'),
                                backgroundColor: Colors.blue[50],
                              ),
                          ],
                        ),
                        const Divider(height: 24),
                        const Text(
                          'Danh sách sản phẩm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Header bảng
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            children: [
                              Expanded(
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
                              Expanded(
                                child: Text(
                                  'Đã mua',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              Expanded(
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
                              Expanded(
                                child: Text(
                                  'Trả',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Danh sách items
                        ..._originalSale!.items.map((item) {
                          final returnQty = _returnQuantities[item.productId] ?? 0.0;
                          final controller = _returnQuantityControllers[item.productId];
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: Row(
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
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    child: TextField(
                                      controller: controller,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        errorText: returnQty > item.quantity
                                            ? 'Vượt quá'
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),

                // Phần tổng hợp và form
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Thông tin trả hàng',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Dropdown lý do trả hàng
                        DropdownButtonFormField<String>(
                          value: _selectedReason,
                          decoration: const InputDecoration(
                            labelText: 'Lý do trả hàng',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.info_outline),
                          ),
                          items: _returnReasons.map((reason) {
                            return DropdownMenuItem(
                              value: reason,
                              child: Text(reason),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedReason = value ?? 'Lỗi NSX';
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Dropdown phương thức hoàn tiền
                        DropdownButtonFormField<String>(
                          value: _selectedPaymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Phương thức hoàn tiền',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payment),
                          ),
                          items: _paymentMethods.map((method) {
                            return DropdownMenuItem(
                              value: method['value'],
                              child: Text(method['label']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedPaymentMethod = value ?? 'CASH';
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        // Tổng tiền hoàn trả
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Tổng tiền hoàn trả:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                NumberFormat.currency(
                                  locale: 'vi_VN',
                                  symbol: '₫',
                                ).format(_calculateTotalRefund()),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Nút xác nhận
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _saveSalesReturn,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Xác nhận trả hàng',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
