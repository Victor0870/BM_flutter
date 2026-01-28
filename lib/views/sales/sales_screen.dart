import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../controllers/sales_provider.dart';
import '../../controllers/product_provider.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../models/product_model.dart';
import '../../models/sale_model.dart';
import '../../models/branch_model.dart';
import '../../models/shop_model.dart';
import '../../models/customer_model.dart';
import '../../services/payment_service.dart';
import '../../widgets/payment_qr_dialog.dart';
import '../../widgets/branch_selection_dialog.dart';
import '../../core/routes.dart';

/// Model cho một tab hóa đơn
class InvoiceTab {
  final int id;
  final String name;
  final SalesProvider salesProvider;

  InvoiceTab({
    required this.id,
    required this.name,
    required this.salesProvider,
  });
}

/// Màn hình bán hàng (POS) - Thiết kế mới theo React
class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final TextEditingController _productSearchController = TextEditingController();
  final TextEditingController _customerSearchController = TextEditingController();
  final TextEditingController _customerNameController = TextEditingController();
  final TextEditingController _customerPhoneController = TextEditingController();
  final TextEditingController _customerAddressController = TextEditingController();
  final TextEditingController _promoCodeController = TextEditingController();
  
  // State để quản lý việc mở/đóng phần thông tin khách hàng
  bool _isCustomerInfoExpanded = false;
  
  // Debounce timer cho tìm kiếm khách hàng
  Timer? _customerSearchDebounce;
  
  // Quản lý tabs
  final List<InvoiceTab> _tabs = [];
  int _activeTabId = 0;
  int _nextTabId = 1;
  bool _hasCheckedBranchSelection = false; // Flag để chỉ kiểm tra một lần

  @override
  void initState() {
    super.initState();
    // Tạo tab đầu tiên
    final salesProvider = context.read<SalesProvider>();
    _tabs.add(InvoiceTab(
      id: 0,
      name: 'Hóa đơn 1',
      salesProvider: salesProvider,
    ));
    _activeTabId = 0;
    
    // Load products và set active tab sau khi build xong
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Đảm bảo tab 0 tồn tại trong SalesProvider (sau khi build xong)
      if (mounted) {
        salesProvider.setActiveTab(0);
      }
      final productProvider = context.read<ProductProvider>();
      if (!productProvider.isLoading) {
        productProvider.loadProducts();
      }
      
      // Kiểm tra và hiển thị dialog chọn chi nhánh cho Admin
      _checkAndShowBranchSelectionDialog();
    });
  }

  /// Kiểm tra và hiển thị dialog chọn chi nhánh cho Admin nếu cần
  Future<void> _checkAndShowBranchSelectionDialog() async {
    if (_hasCheckedBranchSelection) return;
    _hasCheckedBranchSelection = true;

    if (!mounted) return;

    final authProvider = context.read<AuthProvider>();
    final branchProvider = context.read<BranchProvider>();
    final userProfile = authProvider.userProfile;

    // Chỉ xử lý cho Admin
    if (userProfile == null || !userProfile.isAdmin) {
      return;
    }

    // Đảm bảo branches đã được load
    if (branchProvider.branches.isEmpty && !branchProvider.isLoading) {
      await branchProvider.loadBranches();
    }

    // Đợi một chút để đảm bảo branches đã load xong
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final branches = branchProvider.branches.where((b) => b.isActive).toList();
    final currentBranchId = branchProvider.currentBranchId;

    // Nếu chỉ có 1 chi nhánh, tự động chọn
    if (branches.length == 1) {
      if (currentBranchId != branches.first.id) {
        await branchProvider.setSelectedBranch(branches.first.id);
      }
      return;
    }

    // Nếu có >= 2 chi nhánh và chưa có chi nhánh nào được chọn, hiển thị dialog
    if (branches.length >= 2 && (currentBranchId == null || currentBranchId.isEmpty)) {
      final selectedBranchId = await BranchSelectionDialog.show(
        context,
        branches: branches,
        currentBranchId: currentBranchId,
      );

      if (selectedBranchId != null && mounted) {
        await branchProvider.setSelectedBranch(selectedBranchId);
        
        // Refresh products để lọc theo chi nhánh mới
        final productProvider = context.read<ProductProvider>();
        await productProvider.loadProducts();
      }
    }
  }

  @override
  void dispose() {
    _customerSearchDebounce?.cancel();
    _productSearchController.dispose();
    _customerSearchController.dispose();
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _customerAddressController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  void _addNewTab() {
    setState(() {
      final salesProvider = context.read<SalesProvider>();
      final newTabId = salesProvider.createNewTab();
      _tabs.add(InvoiceTab(
        id: newTabId,
        name: 'Hóa đơn $_nextTabId',
        salesProvider: salesProvider,
      ));
      _activeTabId = newTabId;
      _nextTabId++;
    });
  }

  void _removeTab(int id) {
    if (_tabs.length <= 1) return; // Không cho xóa tab cuối cùng
    
    setState(() {
      final salesProvider = context.read<SalesProvider>();
      salesProvider.removeTab(id);
      _tabs.removeWhere((tab) => tab.id == id);
      if (_activeTabId == id) {
        _activeTabId = _tabs.first.id;
        salesProvider.setActiveTab(_activeTabId);
      }
    });
  }

  void _setActiveTab(int id) {
    setState(() {
      _activeTabId = id;
      // Đảm bảo SalesProvider biết tab hiện tại
      final salesProvider = context.read<SalesProvider>();
      salesProvider.setActiveTab(id);
    });
  }
  
  /// Xử lý khi nhập số điện thoại - Tìm kiếm và tự động điền thông tin
  void _onCustomerPhoneChanged(String phone) {
    _customerSearchDebounce?.cancel();
    
    // Chỉ tìm kiếm khi số điện thoại có ít nhất 10 ký tự
    if (phone.trim().length < 10) {
      // Nếu số điện thoại ngắn, xóa customer đã chọn và cho phép nhập mới
      final salesProvider = context.read<SalesProvider>();
      if (salesProvider.getSelectedCustomer(_activeTabId) != null) {
        salesProvider.setSelectedCustomer(null, tabId: _activeTabId);
        // Xóa các trường nếu không có customer
        if (_customerNameController.text.isNotEmpty && 
            _customerNameController.text == salesProvider.getCustomerName(_activeTabId)) {
          _customerNameController.clear();
        }
        if (_customerAddressController.text.isNotEmpty && 
            _customerAddressController.text == salesProvider.getCustomerAddress(_activeTabId)) {
          _customerAddressController.clear();
        }
      }
      return;
    }
    
    _customerSearchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      
      final salesProvider = context.read<SalesProvider>();
      final customers = await salesProvider.searchCustomers(phone.trim());
      
      if (!mounted) return;
      
      if (customers.isNotEmpty) {
        // Tìm thấy khách hàng - Tự động điền thông tin
        final customer = customers.first;
        await _selectCustomer(customer, salesProvider);
      } else {
        // Không tìm thấy - Xóa customer đã chọn, cho phép nhập mới
        salesProvider.setSelectedCustomer(null, tabId: _activeTabId);
        // Giữ nguyên số điện thoại đã nhập, xóa các trường khác nếu chúng từ customer cũ
        // (Các trường sẽ trống và cho phép nhập thông tin mới)
      }
    });
  }
  
  /// Chọn khách hàng và tự động điền thông tin
  Future<void> _selectCustomer(CustomerModel customer, SalesProvider salesProvider) async {
    // Set customer trong provider và áp dụng chiết khấu
    // setSelectedCustomerWithDiscount sẽ tự động điền name, phone, address
    await salesProvider.setSelectedCustomerWithDiscount(customer, tabId: _activeTabId);
    
    // Điền thông tin vào các trường input (để hiển thị trong form)
    _customerNameController.text = customer.name;
    _customerPhoneController.text = customer.phone;
    _customerAddressController.text = customer.address ?? '';
    
    // Tự động mở phần thông tin khách hàng nếu chưa mở
    if (!_isCustomerInfoExpanded) {
      setState(() {
        _isCustomerInfoExpanded = true;
      });
    }
  }
  
  /// Xử lý sau khi thanh toán thành công
  /// Tự động đóng tab nếu không phải là tab duy nhất, hoặc reset về trạng thái trống
  void _handlePostCheckout(int tabId) {
    setState(() {
      if (_tabs.length > 1) {
        // Nếu có nhiều tab, đóng tab vừa thanh toán
        _tabs.removeWhere((tab) => tab.id == tabId);
        
        // Chuyển sang tab khác
        if (_tabs.isNotEmpty) {
          _activeTabId = _tabs.first.id;
          final salesProvider = context.read<SalesProvider>();
          salesProvider.setActiveTab(_activeTabId);
        } else {
          // Nếu không còn tab nào, tạo tab mới
          final salesProvider = context.read<SalesProvider>();
          final newTabId = salesProvider.createNewTab();
          _tabs.add(InvoiceTab(
            id: newTabId,
            name: 'Hóa đơn $_nextTabId',
            salesProvider: salesProvider,
          ));
          _activeTabId = newTabId;
          _nextTabId++;
        }
      } else {
        // Nếu chỉ có 1 tab, chỉ reset về trạng thái trống (giỏ hàng đã được clear)
        // Không cần làm gì thêm vì clearCart đã được gọi
      }
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
      _productSearchController.text = result;
      _searchAndAddProduct(result);
    }
  }

  Future<void> _searchAndAddProduct(String query) async {
    if (query.trim().isEmpty) return;
    
    final productProvider = context.read<ProductProvider>();
    final salesProvider = _getActiveSalesProvider();

    // Đảm bảo products đã được load
    if (productProvider.products.isEmpty && !productProvider.isLoading) {
      await productProvider.loadProducts();
    }

    // Tìm kiếm sản phẩm
    final searchQuery = query.trim().toLowerCase();
    final allProducts = productProvider.products
        .where((p) => p.isSellable && p.isActive)
        .toList();
    
    final matchingProducts = allProducts.where((p) {
      final nameMatch = p.name.toLowerCase().contains(searchQuery);
      final barcodeMatch = p.barcode?.toLowerCase().contains(searchQuery) ?? false;
      final skuMatch = p.id.toLowerCase().contains(searchQuery);
      return nameMatch || barcodeMatch || skuMatch;
    }).toList();

    if (matchingProducts.isNotEmpty) {
      // Nếu chỉ có 1 sản phẩm, thêm trực tiếp
      if (matchingProducts.length == 1) {
        salesProvider.addToCart(matchingProducts.first, tabId: _activeTabId);
        _productSearchController.clear();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã thêm ${matchingProducts.first.name} vào giỏ hàng'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } else {
        // Nếu có nhiều sản phẩm, mở màn hình chọn
        final product = await Navigator.push<ProductModel>(
          context,
          MaterialPageRoute(
            builder: (context) => ProductSelectionScreen(
              initialSearch: query,
            ),
          ),
        );
        if (product != null && mounted) {
          salesProvider.addToCart(product, tabId: _activeTabId);
          _productSearchController.clear();
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy sản phẩm'),
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
        builder: (context) => const ProductSelectionScreen(),
      ),
    );

    if (product != null && mounted) {
      _getActiveSalesProvider().addToCart(product, tabId: _activeTabId);
    }
  }

  SalesProvider _getActiveSalesProvider() {
    return context.read<SalesProvider>(); // Tạm thời dùng chung, có thể mở rộng sau
  }

  String _formatPrice(double price) {
    return NumberFormat('#,###').format(price);
  }

  Future<void> _handleCheckout() async {
    final salesProvider = _getActiveSalesProvider();
    final authProvider = context.read<AuthProvider>();
    final currentTabId = _activeTabId;

    // Kiểm tra giỏ hàng của tab hiện tại
    if (salesProvider.isCartEmptyForTab(currentTabId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giỏ hàng trống'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Hiển thị dialog chọn phương thức thanh toán
    final paymentMethod = await showDialog<PaymentMethodType>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn phương thức thanh toán'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.money, color: Colors.green),
              title: const Text('Tiền mặt'),
              onTap: () => Navigator.pop(context, PaymentMethodType.cash),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.qr_code, color: Colors.blue),
              title: const Text('Chuyển khoản QR'),
              onTap: () => Navigator.pop(context, PaymentMethodType.transfer),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
        ],
      ),
    );

    if (paymentMethod == null) return;

    if (paymentMethod == PaymentMethodType.cash) {
      salesProvider.setPaymentMethod('CASH', tabId: currentTabId);
      await _processCashPayment(salesProvider, currentTabId);
    } else if (paymentMethod == PaymentMethodType.transfer) {
      await _processTransferPayment(salesProvider, authProvider, currentTabId);
    }
  }

  Future<void> _processCashPayment(SalesProvider salesProvider, int tabId) async {
    // Lấy tổng tiền từ tab hiện tại
    final finalTotal = salesProvider.getFinalTotal(tabId);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận thanh toán'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tổng tiền: ${_formatPrice(finalTotal)} đ'),
            const SizedBox(height: 8),
            const Text('Phương thức: Tiền mặt'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await salesProvider.checkout(tabId: tabId);
      if (mounted) {
        if (success) {
          // Trừ kho đã được xử lý trong checkout() của SalesProvider
          // Xóa giỏ hàng của tab hiện tại
          salesProvider.clearCart(tabId: tabId);
          
          // Tự động đóng tab hoặc reset về trạng thái trống
          _handlePostCheckout(tabId);
          
          final productProvider = context.read<ProductProvider>();
          await productProvider.loadProducts();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Thanh toán thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(salesProvider.errorMessage ?? 'Thanh toán thất bại'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _processTransferPayment(
    SalesProvider salesProvider,
    AuthProvider authProvider,
    int tabId,
  ) async {
    final shop = authProvider.shop;
    final paymentConfig = shop?.paymentConfig;
    
    if (kDebugMode) {
      debugPrint('🔍 Checking payment config:');
      debugPrint('  - shop: ${shop != null ? "exists" : "null"}');
      debugPrint('  - paymentConfig: ${paymentConfig != null ? "exists" : "null"}');
      if (paymentConfig != null) {
        debugPrint('  - provider: ${paymentConfig.provider}');
        debugPrint('  - isConfigured: ${paymentConfig.isConfigured}');
        debugPrint('  - bankBin: ${paymentConfig.bankBin}');
        debugPrint('  - bankAccountNumber: ${paymentConfig.bankAccountNumber}');
        debugPrint('  - payosClientId: ${paymentConfig.payosClientId != null ? "exists" : "null"}');
      }
    }
    
    final hasPayOSConfig = paymentConfig != null && 
                          paymentConfig.isConfigured &&
                          paymentConfig.provider == PaymentProvider.payos;
    
    final hasBankInfo = paymentConfig != null &&
                        paymentConfig.bankBin != null &&
                        paymentConfig.bankBin!.isNotEmpty &&
                        paymentConfig.bankAccountNumber != null &&
                        paymentConfig.bankAccountNumber!.isNotEmpty;
    
    if (kDebugMode) {
      debugPrint('  - hasPayOSConfig: $hasPayOSConfig');
      debugPrint('  - hasBankInfo: $hasBankInfo');
    }

    // Lấy tổng tiền từ tab hiện tại
    final totalAmount = salesProvider.getFinalTotal(tabId);
    
    // Trường hợp 1: Không có cấu hình gì - Tạo đơn hàng thủ công
    if (!hasPayOSConfig && !hasBankInfo) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Thanh toán chuyển khoản'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tổng tiền: ${_formatPrice(totalAmount)} đ'),
              const SizedBox(height: 16),
              const Text(
                '⚠️ Vui lòng tự kiểm tra xác nhận thanh toán từ khách hàng trước khi hoàn tất đơn hàng.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange,
                  fontStyle: FontStyle.italic,
                ),
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
              child: const Text('Tạo đơn hàng'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        final orderId = await salesProvider.checkoutWithTransferManual(tabId: tabId);
        if (mounted && orderId != null) {
          // Xóa giỏ hàng của tab hiện tại sau khi tạo đơn hàng thành công
          salesProvider.clearCart(tabId: tabId);
          
          // Tự động đóng tab hoặc reset về trạng thái trống
          _handlePostCheckout(tabId);
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đơn hàng đã được tạo. Vui lòng kiểm tra tài khoản và xác nhận khi đã nhận tiền.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
      return;
    }

    // Trường hợp 2: Có cấu hình PayOS hoặc Bank Info - Tạo QR code
    // paymentConfig không thể null ở đây vì hasPayOSConfig hoặc hasBankInfo đều yêu cầu nó
    // Sử dụng biến local để giúp analyzer hiểu rằng paymentConfig không null
    final config = paymentConfig;
    final paymentService = PaymentService(config: config);
    
    // Tạo đơn hàng trước
    final orderId = hasPayOSConfig
        ? await salesProvider.checkoutWithTransfer(tabId: tabId)
        : await salesProvider.checkoutWithTransferManual(tabId: tabId);

    if (orderId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(salesProvider.errorMessage ?? 'Không thể tạo đơn hàng'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Tạo QR code
    if (kDebugMode) {
      debugPrint('🔄 Creating payment QR for order: $orderId, amount: $totalAmount');
    }
    
    final qrData = await paymentService.createPaymentQR(
      amount: totalAmount,
      orderId: orderId,
      description: 'Don hang $orderId',
    );

    if (qrData == null || qrData.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể tạo mã QR. Vui lòng kiểm tra cấu hình thanh toán trong Cài đặt.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (kDebugMode) {
      debugPrint('✅ QR code created successfully, length: ${qrData.length}');
    }

    // Hiển thị dialog QR code
    if (mounted) {
      final productProvider = context.read<ProductProvider>();
      
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => PaymentQRDialog(
          orderId: orderId,
          amount: totalAmount,
          qrData: qrData,
          paymentService: paymentService,
          salesProvider: salesProvider,
          autoConfirm: hasPayOSConfig ? config.autoConfirmPayment : false,
          onCancel: () {
            // Có thể hủy đơn hàng hoặc giữ nguyên
          },
          onPaymentSuccess: () {
            if (mounted) {
              // Trừ kho đã được xử lý trong completeTransferPayment() của SalesProvider
              // Xóa giỏ hàng của tab hiện tại
              salesProvider.clearCart(tabId: tabId);
              
              // Tự động đóng tab hoặc reset về trạng thái trống
              _handlePostCheckout(tabId);
              
              productProvider.loadProducts();
              
              // Hiển thị thông báo về hóa đơn điện tử nếu có
              final invoiceUrl = salesProvider.lastInvoiceUrl;
              if (invoiceUrl != null && invoiceUrl.isNotEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Thanh toán thành công! Hóa đơn điện tử đã được tạo.'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'Mở hóa đơn',
                      textColor: Colors.white,
                      onPressed: () async {
                        try {
                          final url = Uri.parse(invoiceUrl);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Không thể mở link: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Thanh toán thành công!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            }
          },
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final branchProvider = context.watch<BranchProvider>();
    
    // Lấy thông tin chi nhánh từ BranchProvider.currentBranchId
    final currentBranchId = branchProvider.currentBranchId;
    final branch = currentBranchId != null
        ? branchProvider.branches.firstWhere(
            (b) => b.id == currentBranchId,
            orElse: () => BranchModel(
              id: 'default',
              name: 'Cửa hàng chính',
              address: 'Quận 1 - TP. Hồ Chí Minh',
            ),
          )
        : BranchModel(
            id: 'default',
            name: 'Chưa chọn chi nhánh',
            address: 'Vui lòng chọn chi nhánh',
          );
    
    // Lấy tên nhân viên
    final employeeName = authProvider.userProfile?.displayName ?? 
                        authProvider.user?.email?.split('@').first ?? 
                        'Nhân viên';
    
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9), // slate-100
      body: Column(
        children: [
          // Top Header: Staff & Branch Info
          _buildTopHeader(branch, employeeName, authProvider),
          
          // Main Content
          Expanded(
            child: Row(
              children: [
                // Left Side (75%) - Cart & Search
                Expanded(
                  flex: 3,
                  child: _buildLeftPanel(),
                ),
                
                // Right Side (25%) - Payment Panel
                SizedBox(
                  width: 380,
                  child: _buildRightPanel(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(BranchModel branch, String employeeName, AuthProvider authProvider) {
    return Container(
      height: 40,
      color: const Color(0xFF1E293B), // slate-800
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              // Branch Info
              Row(
                children: [
                  const Icon(
                    LucideIcons.mapPin,
                    size: 14,
                    color: Color(0xFF60A5FA), // blue-400
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Chi nhánh: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[300],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    branch.name, // Hiển thị tên chi nhánh rõ ràng
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (branch.address != null && branch.address!.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      '(${branch.address})',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 16),
              // Date
              Row(
                children: [
                  const Icon(
                    LucideIcons.clock,
                    size: 14,
                    color: Color(0xFF60A5FA),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Ngày: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[300],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          // Employee Info
          Row(
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF3B82F6), // blue-500
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        employeeName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Nhân viên: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[300],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    employeeName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF60A5FA),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Container(
                width: 1,
                height: 12,
                color: Colors.grey[600],
              ),
              const SizedBox(width: 16),
              TextButton(
                onPressed: () => authProvider.signOut(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'Đăng xuất',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftPanel() {
    return Column(
      children: [
        // Tab Bar & Search
        Container(
          color: Colors.white,
          child: Column(
            children: [
              // Tab Bar
              Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _tabs.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _tabs.length) {
                            // Add new tab button
                            return IconButton(
                              icon: const Icon(LucideIcons.plus, size: 20),
                              color: Colors.grey[400],
                              onPressed: _addNewTab,
                            );
                          }
                          
                          final tab = _tabs[index];
                          final isActive = tab.id == _activeTabId;
                          
                          return GestureDetector(
                            onTap: () => _setActiveTab(tab.id),
                            child: Container(
                              margin: const EdgeInsets.only(right: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive ? const Color(0xFFEFF6FF) : Colors.transparent,
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(8),
                                  topRight: Radius.circular(8),
                                ),
                                border: Border(
                                  bottom: BorderSide(
                                    color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    tab.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                      color: isActive ? const Color(0xFF2563EB) : Colors.grey[500],
                                    ),
                                  ),
                                  if (_tabs.length > 1) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _removeTab(tab.id),
                                      child: Icon(
                                        LucideIcons.x,
                                        size: 14,
                                        color: isActive ? const Color(0xFF2563EB) : Colors.grey[400],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    // History & Settings buttons
                    IconButton(
                      icon: const Icon(LucideIcons.history, size: 20),
                      color: Colors.grey[500],
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.salesHistory);
                      },
                      tooltip: 'Lịch sử bán hàng',
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.house, size: 20),
                      color: Colors.grey[500],
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          AppRoutes.home,
                          (route) => false,
                        );
                      },
                      tooltip: 'Về trang tổng quan',
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.settings, size: 20),
                      color: Colors.grey[500],
                      onPressed: () {
                        Navigator.pushNamed(context, AppRoutes.shopSettings);
                      },
                      tooltip: 'Cài đặt',
                    ),
                  ],
                ),
              ),
              
              // Product Search
              Container(
                padding: const EdgeInsets.all(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC), // slate-50
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _productSearchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm sản phẩm (F2) - quét mã vạch hoặc nhập tên...',
                      prefixIcon: IconButton(
                        icon: const Icon(LucideIcons.search, size: 20, color: Color(0xFF94A3B8)),
                        onPressed: () {
                          final query = _productSearchController.text.trim();
                          if (query.isNotEmpty) {
                            _searchAndAddProduct(query);
                          }
                        },
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(LucideIcons.qrCode, size: 20),
                            color: Colors.grey[400],
                            onPressed: _scanBarcode,
                            tooltip: 'Quét mã vạch',
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.list, size: 20),
                            color: Colors.grey[400],
                            onPressed: _showProductSelection,
                            tooltip: 'Chọn sản phẩm',
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        _searchAndAddProduct(value.trim());
                      }
                    },
                    onChanged: (value) {
                      // Có thể thêm tìm kiếm real-time ở đây nếu cần
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Cart Items Table
        Expanded(
          child: Consumer<SalesProvider>(
            builder: (context, salesProvider, child) {
              // Lấy giỏ hàng của tab hiện tại
              final cart = salesProvider.getCart(_activeTabId);
              if (cart.isEmpty) {
                return Container(
                  color: Colors.white,
                  margin: const EdgeInsets.all(16),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.shoppingCart,
                          size: 64,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có sản phẩm nào trong giỏ hàng',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              
              return Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFF1F5F9)),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 48, child: Center(child: _buildTableHeader('#'))),
                          SizedBox(width: 64, child: Center(child: _buildTableHeader('Xóa'))),
                          Expanded(child: _buildTableHeader('Tên hàng')),
                          SizedBox(width: 80, child: Center(child: _buildTableHeader('ĐVT'))),
                          SizedBox(width: 128, child: Center(child: _buildTableHeader('Số lượng'))),
                          SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: _buildTableHeader('Đơn giá'))),
                          SizedBox(width: 120, child: Align(alignment: Alignment.centerRight, child: _buildTableHeader('Thành tiền'))),
                        ],
                      ),
                    ),
                    
                    // Table Body
                    Expanded(
                      child: ListView.builder(
                        itemCount: cart.values.length,
                        itemBuilder: (context, index) {
                          final item = cart.values.toList()[index];
                          return _buildCartItemRow(index + 1, item, salesProvider);
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        
        // Bottom Action Bar
        Container(
          height: 80,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Consumer<SalesProvider>(
            builder: (context, salesProvider, child) {
              // Lấy giỏ hàng của tab hiện tại
              // 4 nút co dãn: Khuyến mãi, In, Chọn bảng giá, Giao hàng
              return Row(
                children: [
                  Expanded(
                    child: _buildExpandableButton(
                      icon: LucideIcons.tag,
                      label: 'Khuyến mãi',
                      onTap: () => _showDiscountDialog(salesProvider),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildExpandableButton(
                      icon: LucideIcons.printer,
                      label: 'In',
                      onTap: () {
                        // TODO: Implement print feature
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tính năng đang phát triển'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildExpandableButton(
                      icon: LucideIcons.dollarSign,
                      label: 'Chọn bảng giá',
                      onTap: () {
                        // TODO: Implement price table selection
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tính năng đang phát triển'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildExpandableButton(
                      icon: LucideIcons.truck,
                      label: 'Giao hàng',
                      onTap: () {
                        // TODO: Implement delivery feature
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tính năng đang phát triển'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: Colors.grey[500],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCartItemRow(int index, SaleItem item, SalesProvider salesProvider) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {},
          hoverColor: const Color(0xFFEFF6FF).withOpacity(0.3),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Center(
                    child: Text(
                      '$index',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Center(
                    child: IconButton(
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      color: Colors.grey[300],
                      onPressed: () => salesProvider.removeFromCart(item.productId, tabId: _activeTabId),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SKU: ${item.productId}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Cái', // TODO: Get from product
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 128,
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Text('-', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              if (item.quantity > 1) {
                                salesProvider.updateCartItemQuantity(item.productId, item.quantity - 1.0, tabId: _activeTabId);
                              } else {
                                salesProvider.removeFromCart(item.productId, tabId: _activeTabId);
                              }
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 20,
                          ),
                          Container(
                            width: 40,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: Text(
                                item.quantity.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Text('+', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              salesProvider.updateCartItemQuantity(item.productId, item.quantity + 1.0, tabId: _activeTabId);
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () => _showItemPriceDiscountDialog(item, salesProvider),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.discount != null && item.discount! > 0
                              ? const Color(0xFFFFF4ED)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: item.discount != null && item.discount! > 0
                                ? const Color(0xFFF97316)
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatPrice(item.price),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: item.discount != null && item.discount! > 0
                                    ? const Color(0xFFF97316)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            if (item.discount != null && item.discount! > 0) ...[
                              const SizedBox(height: 2),
                              Text(
                                '-${_formatPrice(item.discountAmount)}',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFFF97316),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 120,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${_formatPrice(item.subtotal)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Customer Section - Nút "Thông tin khách hàng"
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9)),
              ),
            ),
            child: Column(
              children: [
                // Nút "Thông tin khách hàng"
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _isCustomerInfoExpanded = !_isCustomerInfoExpanded;
                      });
                    },
                    icon: Icon(
                      _isCustomerInfoExpanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                    ),
                    label: const Text('Thông tin khách hàng'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      alignment: Alignment.centerLeft,
                      backgroundColor: const Color(0xFFF8FAFC),
                      foregroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                    ),
                  ),
                ),
                // Expandable Content
                ClipRect(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: _isCustomerInfoExpanded
                        ? Container(
                            padding: const EdgeInsets.only(top: 12),
                            child: Consumer<SalesProvider>(
                              builder: (context, salesProvider, child) {
                                final customer = salesProvider.getSelectedCustomer(_activeTabId);
                                final customerName = salesProvider.getCustomerName(_activeTabId);
                                final customerPhone = salesProvider.getCustomerPhone(_activeTabId);
                                final customerAddress = salesProvider.getCustomerAddress(_activeTabId);
                                
                                // Sync controllers với provider
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (customer != null) {
                                    if (_customerNameController.text != customer.name) {
                                      _customerNameController.text = customer.name;
                                    }
                                    if (_customerPhoneController.text != customer.phone) {
                                      _customerPhoneController.text = customer.phone;
                                    }
                                    if (_customerAddressController.text != (customer.address ?? '')) {
                                      _customerAddressController.text = customer.address ?? '';
                                    }
                                  } else {
                                    // Nếu không có customer, sync với provider values
                                    if (customerName != null && _customerNameController.text != customerName) {
                                      _customerNameController.text = customerName;
                                    }
                                    if (customerPhone != null && _customerPhoneController.text != customerPhone) {
                                      _customerPhoneController.text = customerPhone;
                                    }
                                    if (customerAddress != null && _customerAddressController.text != customerAddress) {
                                      _customerAddressController.text = customerAddress;
                                    }
                                  }
                                });
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Số điện thoại - Ở trên cùng
                                    TextField(
                                      controller: _customerPhoneController,
                                      keyboardType: TextInputType.phone,
                                      decoration: InputDecoration(
                                        labelText: 'Số điện thoại',
                                        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        isDense: true,
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                      onChanged: (value) {
                                        salesProvider.setCustomerPhone(value.isEmpty ? null : value, tabId: _activeTabId);
                                        // Tìm kiếm khách hàng theo số điện thoại
                                        _onCustomerPhoneChanged(value);
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    // Tên khách hàng
                                    TextField(
                                      controller: _customerNameController,
                                      decoration: InputDecoration(
                                        labelText: 'Tên khách hàng',
                                        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        isDense: true,
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                      onChanged: (value) {
                                        salesProvider.setCustomerName(value.isEmpty ? null : value, tabId: _activeTabId);
                                      },
                                    ),
                                    const SizedBox(height: 10),
                                    // Địa chỉ
                                    TextField(
                                      controller: _customerAddressController,
                                      decoration: InputDecoration(
                                        labelText: 'Địa chỉ',
                                        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(6),
                                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                                        ),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        isDense: true,
                                      ),
                                      style: const TextStyle(fontSize: 14),
                                      onChanged: (value) {
                                        salesProvider.setCustomerAddress(value.isEmpty ? null : value, tabId: _activeTabId);
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    // Nút Xác nhận để ẩn lại
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: () {
                                          setState(() {
                                            _isCustomerInfoExpanded = false;
                                          });
                                        },
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          'Xác nhận',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF2563EB),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          )
                        : const SizedBox(height: 0),
                  ),
                ),
              ],
            ),
          ),
          
          // Invoice Config & Summary
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary
                  Container(
                    padding: const EdgeInsets.only(top: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: Color(0xFFE2E8F0), style: BorderStyle.solid, width: 1),
                      ),
                    ),
                    child: Consumer<SalesProvider>(
                      builder: (context, salesProvider, child) {
                        // Sử dụng calculateTotals để lấy đầy đủ thông tin
                        final totals = salesProvider.calculateTotals(_activeTabId);
                        final totalBeforeDiscount = totals['totalBeforeDiscount'] ?? 0.0;
                        final discountAmount = totals['discountAmount'] ?? 0.0;
                        final finalTotal = totals['finalTotal'] ?? 0.0;
                        
                        return Column(
                          children: [
                            _buildSummaryRow('Tổng tiền hàng', '${_formatPrice(totalBeforeDiscount)}đ', Colors.grey[600]!),
                            const SizedBox(height: 12),
                            // Row chiết khấu có thể nhấn vào
                            InkWell(
                              onTap: () => _showDiscountDialog(salesProvider),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: discountAmount > 0 
                                      ? const Color(0xFFFFF4ED) 
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: discountAmount > 0 
                                        ? const Color(0xFFF97316) 
                                        : const Color(0xFFE2E8F0),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          discountAmount > 0 
                                              ? LucideIcons.tag 
                                              : LucideIcons.plus,
                                          size: 16,
                                          color: discountAmount > 0 
                                              ? const Color(0xFFF97316) 
                                              : Colors.grey[400],
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Giảm giá',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: discountAmount > 0 
                                                ? const Color(0xFFF97316) 
                                                : Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Text(
                                          discountAmount > 0 
                                              ? '-${_formatPrice(discountAmount)}đ' 
                                              : 'Nhấn để thêm',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: discountAmount > 0 
                                                ? const Color(0xFFF97316) 
                                                : Colors.grey[400],
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          LucideIcons.chevronRight,
                                          size: 16,
                                          color: Colors.grey[400],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryRow('Phí vận chuyển', '0đ', Colors.grey[600]!),
                            const SizedBox(height: 12),
                            _buildSummaryRow('Tổng cộng', '${_formatPrice(finalTotal)}đ', const Color(0xFF2563EB)),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Payment Section
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Consumer<SalesProvider>(
              builder: (context, salesProvider, child) {
                // Lấy tổng tiền từ tab hiện tại
                final finalTotal = salesProvider.getFinalTotal(_activeTabId);
                
                return Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'KHÁCH CẦN TRẢ',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                            letterSpacing: 0.5,
                          ),
                        ),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatPrice(finalTotal),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF2563EB),
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'đ',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Payment Options
                    // Big Checkout Button
                    Container(
                      width: double.infinity,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF2563EB).withOpacity(0.4),
                            blurRadius: 25,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _handleCheckout,
                          borderRadius: BorderRadius.circular(24),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  LucideIcons.zap,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'THANH TOÁN (F9)',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
    );
  }

  Widget _buildExpandableButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }


  /// Hiển thị dialog chỉnh sửa giá và chiết khấu cho từng sản phẩm
  Future<void> _showItemPriceDiscountDialog(SaleItem item, SalesProvider salesProvider) async {
    final priceController = TextEditingController(
      text: item.price.toStringAsFixed(0),
    );
    final discountController = TextEditingController(
      text: item.discount != null && item.discount! > 0 
          ? item.discount!.toStringAsFixed(0) 
          : '',
    );
    
    bool discountTypeIsPercentage = item.isDiscountPercentage ?? false;
    
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(LucideIcons.pencil, size: 20, color: const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.productName,
                      style: const TextStyle(fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Giá bán
                    const Text(
                      'Giá bán (VNĐ)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: 'Nhập giá bán',
                        prefixIcon: const Icon(LucideIcons.coins, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Chiết khấu
                    const Text(
                      'Chiết khấu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Chọn loại chiết khấu
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => discountTypeIsPercentage = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: discountTypeIsPercentage 
                                      ? const Color(0xFFEFF6FF) 
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: discountTypeIsPercentage 
                                        ? const Color(0xFF2563EB) 
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.percent,
                                      size: 16,
                                      color: discountTypeIsPercentage 
                                          ? const Color(0xFF2563EB) 
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      '%',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () => setState(() => discountTypeIsPercentage = false),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                decoration: BoxDecoration(
                                  color: !discountTypeIsPercentage 
                                      ? const Color(0xFFEFF6FF) 
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: !discountTypeIsPercentage 
                                        ? const Color(0xFF2563EB) 
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      LucideIcons.coins,
                                      size: 16,
                                      color: !discountTypeIsPercentage 
                                          ? const Color(0xFF2563EB) 
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'VNĐ',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: discountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        hintText: discountTypeIsPercentage 
                            ? 'Nhập % (ví dụ: 10)' 
                            : 'Nhập số tiền (ví dụ: 50000)',
                        prefixIcon: Icon(
                          discountTypeIsPercentage ? LucideIcons.percent : LucideIcons.coins,
                          size: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                        ),
                      ),
                    ),
                    if (discountController.text.isNotEmpty && priceController.text.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final price = double.tryParse(priceController.text) ?? 0.0;
                          final discountValue = double.tryParse(discountController.text) ?? 0.0;
                          final quantity = item.quantity;
                          
                          double itemDiscountAmount = 0.0;
                          double itemSubtotal = price * quantity;
                          
                          if (discountValue > 0) {
                            if (discountTypeIsPercentage) {
                              itemDiscountAmount = itemSubtotal * (discountValue / 100);
                              if (discountValue > 100) {
                                itemDiscountAmount = itemSubtotal;
                              }
                            } else {
                              itemDiscountAmount = discountValue > itemSubtotal ? itemSubtotal : discountValue;
                            }
                            itemSubtotal = itemSubtotal - itemDiscountAmount;
                          }
                          
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFDBEAFE)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Số lượng: ${quantity.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Giá gốc: ${_formatPrice(price * quantity)}đ',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                if (itemDiscountAmount > 0) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Giảm giá: -${_formatPrice(itemDiscountAmount)}đ',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFF97316),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Thành tiền: ${_formatPrice(itemSubtotal)}đ',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    priceController.dispose();
                    discountController.dispose();
                    Navigator.pop(context);
                  },
                  child: const Text('Hủy'),
                ),
                TextButton(
                  onPressed: () {
                    // Xóa chiết khấu
                    salesProvider.updateCartItemDiscount(
                      item.productId,
                      null,
                      null,
                      tabId: _activeTabId,
                    );
                    priceController.dispose();
                    discountController.dispose();
                    Navigator.pop(context);
                  },
                  child: const Text('Xóa chiết khấu', style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: () {
                    final newPrice = double.tryParse(priceController.text) ?? item.price;
                    final discountValue = discountController.text.isNotEmpty
                        ? double.tryParse(discountController.text)
                        : null;
                    
                    if (newPrice < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Giá bán không được âm'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    if (discountValue != null && discountValue < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chiết khấu không được âm'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    if (discountTypeIsPercentage && discountValue != null && discountValue > 100) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Phần trăm giảm giá không được vượt quá 100%'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    
                    // Cập nhật giá
                    salesProvider.updateCartItemPrice(item.productId, newPrice, tabId: _activeTabId);
                    
                    // Cập nhật chiết khấu
                    salesProvider.updateCartItemDiscount(
                      item.productId,
                      discountValue,
                      discountValue != null ? discountTypeIsPercentage : null,
                      tabId: _activeTabId,
                    );
                    
                    priceController.dispose();
                    discountController.dispose();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Xác nhận'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Hiển thị dialog nhập chiết khấu
  Future<void> _showDiscountDialog(SalesProvider salesProvider) async {
    final currentDiscountValue = salesProvider.getOrderDiscountValue(_activeTabId);
    final isPercentage = salesProvider.getIsDiscountPercentage(_activeTabId);
    final totalBeforeDiscount = salesProvider.getTotalBeforeDiscount(_activeTabId);
    
    // Controller cho giá trị chiết khấu
    final discountController = TextEditingController(
      text: currentDiscountValue > 0 ? currentDiscountValue.toStringAsFixed(0) : '',
    );
    
    // State cho loại chiết khấu
    bool discountTypeIsPercentage = isPercentage;
    
    // Biến để track xem đã thêm listener chưa
    bool listenerAdded = false;
    
    await showDialog(
      context: context,
      builder: (dialogContext) {
        // StatefulBuilder để rebuild khi state thay đổi
        return StatefulBuilder(
          builder: (context, setState) {
            // Thêm listener một lần để cập nhật preview khi text thay đổi
            if (!listenerAdded) {
              discountController.addListener(() {
                setState(() {}); // Rebuild để cập nhật preview
              });
              listenerAdded = true;
            }
            
            return AlertDialog(
          title: const Row(
            children: [
              Icon(LucideIcons.tag, size: 20, color: Color(0xFFF97316)),
              SizedBox(width: 8),
              Text('Chiết khấu đơn hàng'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Chọn loại chiết khấu
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => discountTypeIsPercentage = true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: discountTypeIsPercentage 
                                ? const Color(0xFFEFF6FF) 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: discountTypeIsPercentage 
                                  ? const Color(0xFF2563EB) 
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                discountTypeIsPercentage 
                                    ? LucideIcons.percent 
                                    : LucideIcons.percent,
                                size: 16,
                                color: discountTypeIsPercentage 
                                    ? const Color(0xFF2563EB) 
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Phần trăm (%)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: discountTypeIsPercentage 
                                      ? FontWeight.bold 
                                      : FontWeight.normal,
                                  color: discountTypeIsPercentage 
                                      ? const Color(0xFF2563EB) 
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => discountTypeIsPercentage = false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: !discountTypeIsPercentage 
                                ? const Color(0xFFEFF6FF) 
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !discountTypeIsPercentage 
                                  ? const Color(0xFF2563EB) 
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                LucideIcons.coins,
                                size: 16,
                                color: !discountTypeIsPercentage 
                                    ? const Color(0xFF2563EB) 
                                    : Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Số tiền (VNĐ)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: !discountTypeIsPercentage 
                                      ? FontWeight.bold 
                                      : FontWeight.normal,
                                  color: !discountTypeIsPercentage 
                                      ? const Color(0xFF2563EB) 
                                      : Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Ô nhập giá trị
              TextField(
                controller: discountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: discountTypeIsPercentage ? 'Phần trăm giảm giá (%)' : 'Số tiền giảm giá (VNĐ)',
                  hintText: discountTypeIsPercentage ? 'Nhập % (ví dụ: 10)' : 'Nhập số tiền (ví dụ: 50000)',
                  prefixIcon: Icon(
                    discountTypeIsPercentage ? LucideIcons.percent : LucideIcons.coins,
                    size: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
                  ),
                ),
              ),
              if (discountController.text.isNotEmpty) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final value = double.tryParse(discountController.text) ?? 0.0;
                    double discountAmount = 0.0;
                    double finalTotal = totalBeforeDiscount;
                    
                    if (value > 0) {
                      if (discountTypeIsPercentage) {
                        discountAmount = totalBeforeDiscount * (value / 100);
                        // Giới hạn phần trăm không vượt quá 100%
                        if (value > 100) {
                          discountAmount = totalBeforeDiscount;
                        }
                      } else {
                        discountAmount = value > totalBeforeDiscount ? totalBeforeDiscount : value;
                      }
                      finalTotal = totalBeforeDiscount - discountAmount;
                    }
                    
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng tiền hàng: ${_formatPrice(totalBeforeDiscount)}đ',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Giảm giá: -${_formatPrice(discountAmount)}đ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFF97316),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tổng cộng: ${_formatPrice(finalTotal)}đ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                discountController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () {
                // Xóa chiết khấu
                salesProvider.clearDiscount(tabId: _activeTabId);
                discountController.dispose();
                Navigator.pop(context);
              },
              child: const Text('Xóa', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                final value = double.tryParse(discountController.text) ?? 0.0;
                if (value > 0) {
                  // Validate giá trị
                  if (discountTypeIsPercentage && value > 100) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Phần trăm giảm giá không được vượt quá 100%'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  // Kiểm tra quyền phê duyệt
                  final authProvider = context.read<AuthProvider>();
                  final totals = salesProvider.calculateTotals(_activeTabId);
                  final subTotal = totals['subTotal'] ?? 0.0;
                  
                  double actualDiscountAmount = 0.0;
                  if (discountTypeIsPercentage) {
                    actualDiscountAmount = subTotal * (value / 100);
                  } else {
                    actualDiscountAmount = value > subTotal ? subTotal : value;
                  }
                  
                  double actualDiscountPercent = 0.0;
                  if (subTotal > 0) {
                    actualDiscountPercent = (actualDiscountAmount / subTotal) * 100;
                  }
                  
                  String? approvedBy;
                  // Nếu chiết khấu > 10% và user không phải admin, yêu cầu phê duyệt
                  if (actualDiscountPercent > 10.0 && !authProvider.isAdminUser) {
                    final approved = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Row(
                          children: [
                            Icon(Icons.warning, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Yêu cầu phê duyệt'),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Chiết khấu ${actualDiscountPercent.toStringAsFixed(1)}% vượt quá ngưỡng cho phép (10%).',
                              style: const TextStyle(fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Chỉ Admin/Manager mới có quyền phê duyệt chiết khấu này.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Hủy'),
                          ),
                        ],
                      ),
                    );
                    
                    if (approved != true) {
                      return; // Người dùng không phải admin, không thể phê duyệt
                    }
                  }
                  
                  // Nếu là admin, tự động phê duyệt
                  if (authProvider.isAdminUser && actualDiscountPercent > 10.0) {
                    approvedBy = authProvider.userProfile?.displayName ?? authProvider.user?.email ?? 'Admin';
                  }
                  
                  final success = salesProvider.setOrderDiscount(
                    value,
                    discountTypeIsPercentage,
                    tabId: _activeTabId,
                    approvedBy: approvedBy,
                  );
                  
                  if (!success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(salesProvider.errorMessage ?? 'Không thể áp dụng chiết khấu'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                } else {
                  salesProvider.clearDiscount(tabId: _activeTabId);
                }
                discountController.dispose();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
              ),
              child: const Text('Xác nhận'),
            ),
          ],
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

}

// Import các widget còn lại từ file cũ
class ProductSelectionScreen extends StatefulWidget {
  final String? initialSearch;
  
  const ProductSelectionScreen({super.key, this.initialSearch});

  @override
  State<ProductSelectionScreen> createState() => _ProductSelectionScreenState();
}

class _ProductSelectionScreenState extends State<ProductSelectionScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearch ?? '');
    // Tự động tìm kiếm nếu có initialSearch
    if (widget.initialSearch != null && widget.initialSearch!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final productProvider = context.read<ProductProvider>();
        productProvider.searchProducts(widget.initialSearch!);
      });
    }
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
        title: const Text('Chọn sản phẩm'),
      ),
      body: Consumer<ProductProvider>(
        builder: (context, productProvider, child) {
          if (productProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final products = productProvider.products
              .where((p) => p.isSellable && p.isActive)
              .toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm sản phẩm...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (query) => productProvider.searchProducts(query),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    // Sử dụng getStockForCurrentBranch để lấy tồn kho theo chi nhánh hiện tại
                    final stock = productProvider.getStockForCurrentBranch(product);
                    return ListTile(
                      title: Text(product.name),
                      subtitle: Text('${product.price.toStringAsFixed(0)} đ - Tồn: ${stock.toStringAsFixed(0)}'),
                      trailing: stock > 0
                          ? const Icon(Icons.add_shopping_cart)
                          : const Text('Hết hàng', style: TextStyle(color: Colors.red)),
                      onTap: stock > 0
                          ? () => Navigator.pop(context, product)
                          : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

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
        ],
      ),
    );
  }
}
