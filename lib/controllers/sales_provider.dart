import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/customer_model.dart';
import '../services/sales_service.dart';
import '../services/product_service.dart';
import '../services/customer_service.dart';
import '../services/einvoice_service.dart';
import '../services/payment_service.dart';
import '../services/local_db_service.dart';
import 'auth_provider.dart';
import 'branch_provider.dart';
import 'product_provider.dart';

/// Provider quản lý giỏ hàng và bán hàng
class SalesProvider with ChangeNotifier {
  final AuthProvider authProvider;
  final BranchProvider? branchProvider; // Optional để tương thích ngược
  final ProductProvider? productProvider; // Optional để tương thích ngược
  SalesService? _salesService;
  ProductService? _productService;
  CustomerService? _customerService;
  final EinvoiceService _einvoiceService = EinvoiceService();
  final LocalDbService _localDb = LocalDbService();

  // Giỏ hàng đa tab - Map<tabId, Map<productId, SaleItem>>
  final Map<int, Map<String, SaleItem>> _tabsCart = {}; // Key: tabId, Value: cart của tab đó
  final Map<int, String> _tabsPaymentMethod = {}; // Key: tabId, Value: paymentMethod
  final Map<int, CustomerModel?> _tabsCustomer = {}; // Key: tabId, Value: selectedCustomer
  final Map<int, String?> _tabsCustomerName = {}; // Key: tabId, Value: customerName
  final Map<int, String?> _tabsCustomerPhone = {}; // Key: tabId, Value: customerPhone
  final Map<int, String?> _tabsCustomerTaxCode = {}; // Key: tabId, Value: customerTaxCode
  final Map<int, String?> _tabsCustomerAddress = {}; // Key: tabId, Value: customerAddress
  final Map<int, String?> _tabsNotes = {}; // Key: tabId, Value: notes
  final Map<int, double> _tabsDiscountPercent = {}; // Key: tabId, Value: discountPercent (deprecated, giữ lại để tương thích)
  // Chiết khấu mới: hỗ trợ cả % và số tiền
  final Map<int, double> _tabsOrderDiscountValue = {}; // Key: tabId, Value: giá trị chiết khấu
  final Map<int, bool> _tabsIsDiscountPercentage = {}; // Key: tabId, Value: true nếu là %, false nếu là số tiền
  final Map<int, String?> _tabsDiscountApprovedBy = {}; // Key: tabId, Value: ID hoặc tên người phê duyệt
  
  int _activeTabId = 0; // Tab hiện tại đang hoạt động
  
  // Ngưỡng chiết khấu yêu cầu phê duyệt (10%)
  static const double _discountApprovalThreshold = 10.0;

  // State
  bool _isLoading = false;
  String? _errorMessage;
  String? _lastInvoiceUrl; // Link hóa đơn điện tử vừa tạo
  /// Tăng mỗi khi checkout/completeTransferPayment thành công — HomeScreen lắng nghe để refresh dashboard.
  int _checkoutSuccessNotifyCount = 0;
  Timer? _paymentPollingTimer; // Timer để polling payment status
  // ignore: unused_field
  String? _pendingSaleId; // ID của đơn hàng đang chờ thanh toán (chỉ dùng cho PayOS auto polling)

  // Getters - Trả về giá trị dựa trên activeTabId
  int get activeTabId => _activeTabId;
  
  /// Lấy giỏ hàng của tab hiện tại
  Map<String, SaleItem> getCart(int? tabId) {
    final id = tabId ?? _activeTabId;
    return Map.unmodifiable(_tabsCart[id] ?? {});
  }
  
  Map<String, SaleItem> get cart => getCart(_activeTabId);
  List<SaleItem> get cartItems => cart.values.toList();
  int get cartItemCount => cart.length;
  
  double getCartTotal(int? tabId) {
    final id = tabId ?? _activeTabId;
    final cart = _tabsCart[id] ?? {};
    return cart.values.fold(0.0, (sum, item) => sum + item.subtotal);
  }
  
  double get cartTotal => getCartTotal(_activeTabId);
  
  /// Tính toán tổng tiền: totalBeforeDiscount, discountAmount, finalTotal
  /// Trả về Map với các key: totalBeforeDiscount, discountAmount, finalTotal, subTotal
  Map<String, double> calculateTotals(int? tabId) {
    final id = tabId ?? _activeTabId;
    // subTotal: Tổng tiền hàng sau khi trừ chiết khấu từng dòng (từ item.subtotal)
    final subTotal = getCartTotal(id);
    
    final discountValue = _tabsOrderDiscountValue[id] ?? 0.0;
    final isPercentage = _tabsIsDiscountPercentage[id] ?? false;
    
    double totalDiscountAmount = 0.0;
    if (discountValue > 0) {
      if (isPercentage) {
        // Chiết khấu theo phần trăm
        totalDiscountAmount = subTotal * (discountValue / 100);
      } else {
        // Chiết khấu theo số tiền
        totalDiscountAmount = discountValue;
        // Đảm bảo không vượt quá tổng tiền (ràng buộc dữ liệu)
        if (totalDiscountAmount > subTotal) {
          totalDiscountAmount = subTotal;
        }
      }
    }
    
    // Đảm bảo totalDiscountAmount không bao giờ lớn hơn subTotal
    if (totalDiscountAmount > subTotal) {
      totalDiscountAmount = subTotal;
    }
    
    final finalTotal = subTotal - totalDiscountAmount;
    
    return {
      'subTotal': subTotal, // Tổng sau khi trừ chiết khấu từng dòng
      'totalBeforeDiscount': subTotal, // Tương thích ngược
      'discountAmount': totalDiscountAmount,
      'totalDiscountAmount': totalDiscountAmount,
      'finalTotal': finalTotal,
    };
  }
  
  /// Tổng tiền hàng gốc (trước chiết khấu)
  double getTotalBeforeDiscount(int? tabId) {
    return calculateTotals(tabId)['totalBeforeDiscount'] ?? 0.0;
  }
  
  double get totalBeforeDiscount => getTotalBeforeDiscount(_activeTabId);
  
  /// Số tiền được giảm
  double getDiscountAmount(int? tabId) {
    return calculateTotals(tabId)['discountAmount'] ?? 0.0;
  }
  
  double get discountAmount => getDiscountAmount(_activeTabId);
  
  /// Tổng tiền sau khi áp dụng giảm giá
  double getFinalTotal(int? tabId) {
    return calculateTotals(tabId)['finalTotal'] ?? 0.0;
  }
  
  double get finalTotal => getFinalTotal(_activeTabId);
  
  /// Phần trăm giảm giá hiện tại (deprecated, giữ lại để tương thích)
  double getDiscountPercent(int? tabId) {
    final id = tabId ?? _activeTabId;
    // Nếu đang dùng chiết khấu mới, tính lại từ giá trị
    final discountValue = _tabsOrderDiscountValue[id] ?? 0.0;
    final isPercentage = _tabsIsDiscountPercentage[id] ?? false;
    if (discountValue > 0 && isPercentage) {
      return discountValue;
    }
    return _tabsDiscountPercent[id] ?? 0.0;
  }
  
  double get discountPercent => getDiscountPercent(_activeTabId);
  
  /// Giá trị chiết khấu hiện tại
  double getOrderDiscountValue(int? tabId) {
    final id = tabId ?? _activeTabId;
    return _tabsOrderDiscountValue[id] ?? 0.0;
  }
  
  double get orderDiscountValue => getOrderDiscountValue(_activeTabId);
  
  /// Loại chiết khấu (true = %, false = số tiền)
  bool getIsDiscountPercentage(int? tabId) {
    final id = tabId ?? _activeTabId;
    return _tabsIsDiscountPercentage[id] ?? false;
  }
  
  bool get isDiscountPercentage => getIsDiscountPercentage(_activeTabId);
  
  String getPaymentMethod(int? tabId) {
    final id = tabId ?? _activeTabId;
    return _tabsPaymentMethod[id] ?? 'CASH';
  }
  
  String get paymentMethod => getPaymentMethod(_activeTabId);
  
  CustomerModel? getSelectedCustomer(int? tabId) {
    final id = tabId ?? _activeTabId;
    return _tabsCustomer[id];
  }
  
  CustomerModel? get selectedCustomer => getSelectedCustomer(_activeTabId);
  
  String? getCustomerName(int? tabId) {
    final id = tabId ?? _activeTabId;
    return _tabsCustomerName[id];
  }
  
  String? get customerName => getCustomerName(_activeTabId);
  
  String? getCustomerPhone(int? tabId) {
    final id = tabId ?? _activeTabId;
    return _tabsCustomerPhone[id];
  }
  
  String? get customerPhone => getCustomerPhone(_activeTabId);
  
  String? getCustomerTaxCode(int? tabId) {
    final id = tabId ?? _activeTabId;
    return _tabsCustomerTaxCode[id];
  }
  
  String? get customerTaxCode => getCustomerTaxCode(_activeTabId);
  
  String? getCustomerAddress(int? tabId) {
    final id = tabId ?? _activeTabId;
    return _tabsCustomerAddress[id];
  }
  
  String? get customerAddress => getCustomerAddress(_activeTabId);
  
  String? getNotes(int? tabId) {
    final id = tabId ?? _activeTabId;
    return _tabsNotes[id];
  }
  
  String? get notes => getNotes(_activeTabId);
  
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get lastInvoiceUrl => _lastInvoiceUrl;
  /// Số lần bán hàng thành công; thay đổi khi checkout/completeTransferPayment thành công.
  int get checkoutSuccessNotifyCount => _checkoutSuccessNotifyCount;
  
  bool isCartEmptyForTab(int? tabId) {
    final id = tabId ?? _activeTabId;
    final cart = _tabsCart[id] ?? {};
    return cart.isEmpty;
  }
  
  bool get isCartEmpty => isCartEmptyForTab(_activeTabId);
  
  /// Lấy danh sách tất cả tab IDs
  List<int> get tabIds => _tabsCart.keys.toList()..sort();

  SalesProvider(this.authProvider, {this.branchProvider, this.productProvider}) {
    authProvider.addListener(_onAuthChanged);
    _initializeServices();
  }

  /// Khởi tạo services dựa trên trạng thái auth
  void _initializeServices() {
    final user = authProvider.user;
    final isPro = authProvider.isPro;

    if (user != null) {
      _productService = ProductService(
        isPro: isPro,
        userId: user.uid,
      );
      _customerService = CustomerService(
        isPro: isPro,
        userId: user.uid,
      );
      _salesService = SalesService(
        isPro: isPro,
        userId: user.uid,
        productService: _productService!,
      );
    } else {
      _productService = null;
      _customerService = null;
      _salesService = null;
      _tabsCart.clear();
      _tabsPaymentMethod.clear();
      _tabsCustomer.clear();
      _tabsCustomerName.clear();
      _tabsCustomerPhone.clear();
      _tabsCustomerTaxCode.clear();
      _tabsCustomerAddress.clear();
      _tabsNotes.clear();
      _tabsDiscountPercent.clear();
    }
    notifyListeners();
  }

  /// Xử lý khi auth state thay đổi
  void _onAuthChanged() {
    _initializeServices();
  }

  /// Thêm sản phẩm vào giỏ hàng
  void addToCart(ProductModel product, {double quantity = 1, int? tabId}) {
    final id = tabId ?? _activeTabId;
    
    // Đảm bảo cart của tab tồn tại
    _tabsCart[id] ??= {};
    
    // Kiểm tra cấu hình allowNegativeStock
    final shop = authProvider.shop;
    final allowNegativeStock = shop?.allowNegativeStock ?? false;
    
    final cart = _tabsCart[id]!;
    
    if (cart.containsKey(product.id)) {
      // Tăng số lượng nếu sản phẩm đã có trong giỏ
      final existingItem = cart[product.id]!;
      final newQuantity = existingItem.quantity + quantity;
      
      // Kiểm tra stock nếu không cho phép bán âm kho
      if (!allowNegativeStock && newQuantity > product.stock) {
        _errorMessage = 'Không đủ hàng trong kho. Tồn kho: ${product.stock}';
        notifyListeners();
        return;
      }

      cart[product.id] = existingItem.copyWith(quantity: newQuantity);
    } else {
      // Thêm sản phẩm mới vào giỏ
      // Kiểm tra stock nếu không cho phép bán âm kho
      if (!allowNegativeStock && quantity > product.stock) {
        _errorMessage = 'Không đủ hàng trong kho. Tồn kho: ${product.stock}';
        notifyListeners();
        return;
      }

      cart[product.id] = SaleItem(
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        price: product.price,
      );
    }

    _errorMessage = null;
    notifyListeners();
  }

  /// Cập nhật số lượng sản phẩm trong giỏ
  void updateCartItemQuantity(String productId, double quantity, {int? tabId}) {
    final id = tabId ?? _activeTabId;
    final cart = _tabsCart[id];
    if (cart == null || !cart.containsKey(productId)) return;

    if (quantity <= 0) {
      // Xóa khỏi giỏ nếu số lượng <= 0
      removeFromCart(productId, tabId: id);
      return;
    }

    // Kiểm tra stock nếu không cho phép bán âm kho
    // Lưu ý: Cần lấy product từ ProductProvider để kiểm tra stock
    // Tạm thời chỉ cập nhật, sẽ kiểm tra kỹ hơn khi checkout
    final item = cart[productId]!;
    cart[productId] = item.copyWith(quantity: quantity);
    notifyListeners();
  }

  /// Xóa sản phẩm khỏi giỏ hàng
  void removeFromCart(String productId, {int? tabId}) {
    final id = tabId ?? _activeTabId;
    _tabsCart[id]?.remove(productId);
    notifyListeners();
  }

  /// Cập nhật giá bán của sản phẩm trong giỏ
  void updateCartItemPrice(String productId, double newPrice, {int? tabId}) {
    final id = tabId ?? _activeTabId;
    final cart = _tabsCart[id];
    if (cart == null || !cart.containsKey(productId)) return;

    if (newPrice < 0) {
      _errorMessage = 'Giá bán không được âm';
      notifyListeners();
      return;
    }

    cart[productId] = cart[productId]!.copyWith(price: newPrice);
    _errorMessage = null;
    notifyListeners();
  }

  /// Cập nhật chiết khấu cho sản phẩm trong giỏ
  /// [discount] Giá trị chiết khấu
  /// [isPercentage] true nếu là phần trăm, false nếu là số tiền
  void updateCartItemDiscount(String productId, double? discount, bool? isPercentage, {int? tabId}) {
    final id = tabId ?? _activeTabId;
    final cart = _tabsCart[id];
    if (cart == null || !cart.containsKey(productId)) return;

    if (discount != null && discount < 0) {
      _errorMessage = 'Chiết khấu không được âm';
      notifyListeners();
      return;
    }

    cart[productId] = cart[productId]!.copyWith(
      discount: discount,
      isDiscountPercentage: isPercentage,
    );
    _errorMessage = null;
    notifyListeners();
  }

  /// Xóa toàn bộ giỏ hàng của tab
  void clearCart({int? tabId}) {
    final id = tabId ?? _activeTabId;
    _tabsCart[id]?.clear();
    _tabsCustomer[id] = null;
    _tabsDiscountPercent[id] = 0.0;
    _tabsOrderDiscountValue[id] = 0.0;
    _tabsIsDiscountPercentage[id] = false;
    _tabsDiscountApprovedBy[id] = null;
    _tabsCustomerName[id] = null;
    _tabsCustomerPhone[id] = null;
    _tabsCustomerTaxCode[id] = null;
    _tabsCustomerAddress[id] = null;
    _tabsNotes[id] = null;
    _tabsPaymentMethod[id] = 'CASH';
    _errorMessage = null;
    _lastInvoiceUrl = null;
    notifyListeners();
  }
  
  /// Xóa tab và tất cả dữ liệu liên quan
  void removeTab(int tabId) {
    _tabsCart.remove(tabId);
    _tabsPaymentMethod.remove(tabId);
    _tabsCustomer.remove(tabId);
    _tabsCustomerName.remove(tabId);
    _tabsCustomerPhone.remove(tabId);
    _tabsCustomerTaxCode.remove(tabId);
    _tabsCustomerAddress.remove(tabId);
    _tabsNotes.remove(tabId);
    _tabsDiscountPercent.remove(tabId);
    _tabsOrderDiscountValue.remove(tabId);
    _tabsIsDiscountPercentage.remove(tabId);
    
    // Nếu xóa tab đang active, chuyển sang tab khác hoặc tạo tab mới
    if (_activeTabId == tabId) {
      final remainingTabs = _tabsCart.keys.toList()..remove(tabId);
      if (remainingTabs.isNotEmpty) {
        _activeTabId = remainingTabs.first;
      } else {
        _activeTabId = 0;
      }
    }
    
    notifyListeners();
  }
  
  /// Chuyển sang tab khác
  void setActiveTab(int tabId) {
    if (_tabsCart.containsKey(tabId) || tabId == 0) {
      _activeTabId = tabId;
      // Đảm bảo cart của tab tồn tại
      _tabsCart[tabId] ??= {};
      notifyListeners();
    }
  }
  
  /// Tạo tab mới và trả về tabId
  int createNewTab() {
    final newTabId = (_tabsCart.keys.isEmpty ? 0 : _tabsCart.keys.reduce((a, b) => a > b ? a : b)) + 1;
    _tabsCart[newTabId] = {};
    _tabsPaymentMethod[newTabId] = 'CASH';
    _tabsCustomer[newTabId] = null;
    _tabsCustomerName[newTabId] = null;
    _tabsCustomerPhone[newTabId] = null;
    _tabsCustomerTaxCode[newTabId] = null;
    _tabsCustomerAddress[newTabId] = null;
    _tabsNotes[newTabId] = null;
    _tabsDiscountPercent[newTabId] = 0.0;
    _tabsOrderDiscountValue[newTabId] = 0.0;
    _tabsIsDiscountPercentage[newTabId] = false;
    _tabsDiscountApprovedBy[newTabId] = null;
    _activeTabId = newTabId;
    notifyListeners();
    return newTabId;
  }

  /// Cập nhật phương thức thanh toán
  void setPaymentMethod(String method, {int? tabId}) {
    final id = tabId ?? _activeTabId;
    _tabsPaymentMethod[id] = method;
    notifyListeners();
  }

  /// Cập nhật tên khách hàng
  void setCustomerName(String? name, {int? tabId}) {
    final id = tabId ?? _activeTabId;
    _tabsCustomerName[id] = name;
    notifyListeners();
  }

  /// Cập nhật số điện thoại khách hàng
  void setCustomerPhone(String? phone, {int? tabId}) {
    final id = tabId ?? _activeTabId;
    _tabsCustomerPhone[id] = phone;
    notifyListeners();
  }

  /// Cập nhật MST khách hàng
  void setCustomerTaxCode(String? taxCode, {int? tabId}) {
    final id = tabId ?? _activeTabId;
    _tabsCustomerTaxCode[id] = taxCode;
    notifyListeners();
  }

  /// Cập nhật địa chỉ khách hàng
  void setCustomerAddress(String? address, {int? tabId}) {
    final id = tabId ?? _activeTabId;
    _tabsCustomerAddress[id] = address;
    notifyListeners();
  }

  /// Cập nhật ghi chú
  void setNotes(String? notes, {int? tabId}) {
    final id = tabId ?? _activeTabId;
    _tabsNotes[id] = notes;
    notifyListeners();
  }

  /// Cập nhật khách hàng đã chọn
  void setSelectedCustomer(CustomerModel? customer, {int? tabId}) {
    final id = tabId ?? _activeTabId;
    _tabsCustomer[id] = customer;
    if (customer != null) {
      _tabsCustomerName[id] = customer.name;
      _tabsCustomerPhone[id] = customer.phone;
      _tabsCustomerAddress[id] = customer.address;
      _tabsCustomerTaxCode[id] = null; // CustomerModel không có taxCode, để user nhập nếu cần
      
      // Cập nhật discountPercent từ customer group
      if (customer.groupId != null && _customerService != null) {
        // Lưu ý: Cần load customer group để lấy discountPercent
        // Tạm thời để 0, sẽ cập nhật sau khi load group
        _tabsDiscountPercent[id] = 0.0;
        _tabsOrderDiscountValue[id] = 0.0;
        _tabsIsDiscountPercentage[id] = false;
      } else {
        _tabsDiscountPercent[id] = 0.0;
        _tabsOrderDiscountValue[id] = 0.0;
        _tabsIsDiscountPercentage[id] = false;
      }
    } else {
      _tabsDiscountPercent[id] = 0.0;
    }
    notifyListeners();
  }

  /// Cập nhật phần trăm giảm giá
  void setDiscountPercent(double percent, {int? tabId}) {
    final id = tabId ?? _activeTabId;
    _tabsDiscountPercent[id] = percent;
    // Cập nhật chiết khấu mới để tương thích
    _tabsOrderDiscountValue[id] = percent;
    _tabsIsDiscountPercentage[id] = true;
    notifyListeners();
  }
  
  /// Thiết lập chiết khấu mới (hỗ trợ cả % và số tiền)
  /// [value] Giá trị chiết khấu
  /// [isPercentage] true nếu là phần trăm, false nếu là số tiền
  /// [approvedBy] ID hoặc tên người phê duyệt (nếu chiết khấu cao)
  /// Trả về true nếu thành công, false nếu cần phê duyệt
  bool setOrderDiscount(double value, bool isPercentage, {int? tabId, String? approvedBy}) {
    final id = tabId ?? _activeTabId;
    final subTotal = getCartTotal(id);
    
    // Tính toán số tiền chiết khấu thực tế
    double actualDiscountAmount = 0.0;
    if (value > 0) {
      if (isPercentage) {
        actualDiscountAmount = subTotal * (value / 100);
      } else {
        actualDiscountAmount = value > subTotal ? subTotal : value;
      }
    }
    
    // Tính phần trăm chiết khấu thực tế
    double actualDiscountPercent = 0.0;
    if (subTotal > 0) {
      actualDiscountPercent = (actualDiscountAmount / subTotal) * 100;
    }
    
    // Kiểm tra nếu chiết khấu vượt quá ngưỡng và chưa có phê duyệt
    if (actualDiscountPercent > _discountApprovalThreshold && approvedBy == null) {
      _errorMessage = 'Chiết khấu vượt quá $_discountApprovalThreshold% cần được phê duyệt bởi Admin/Manager';
      notifyListeners();
      return false; // Yêu cầu phê duyệt
    }
    
    // Ràng buộc: đảm bảo totalDiscountAmount không vượt quá subTotal
    if (actualDiscountAmount > subTotal) {
      _errorMessage = 'Chiết khấu không được vượt quá tổng tiền hàng';
      notifyListeners();
      return false;
    }
    
    _tabsOrderDiscountValue[id] = value;
    _tabsIsDiscountPercentage[id] = isPercentage;
    _tabsDiscountApprovedBy[id] = approvedBy;
    
    // Cập nhật discountPercent để tương thích ngược
    if (isPercentage) {
      _tabsDiscountPercent[id] = value;
    } else {
      _tabsDiscountPercent[id] = 0.0; // Không thể chuyển đổi số tiền thành % mà không biết tổng
    }
    
    _errorMessage = null;
    notifyListeners();
    return true;
  }
  
  /// Lấy thông tin người phê duyệt chiết khấu
  String? getDiscountApprovedBy(int? tabId) {
    final id = tabId ?? _activeTabId;
    return _tabsDiscountApprovedBy[id];
  }
  
  /// Kiểm tra xem chiết khấu hiện tại có cần phê duyệt không
  bool requiresDiscountApproval(int? tabId) {
    final id = tabId ?? _activeTabId;
    final subTotal = getCartTotal(id);
    final discountValue = _tabsOrderDiscountValue[id] ?? 0.0;
    final isPercentage = _tabsIsDiscountPercentage[id] ?? false;
    
    if (discountValue == 0 || subTotal == 0) return false;
    
    double actualDiscountAmount = 0.0;
    if (isPercentage) {
      actualDiscountAmount = subTotal * (discountValue / 100);
    } else {
      actualDiscountAmount = discountValue > subTotal ? subTotal : discountValue;
    }
    
    double actualDiscountPercent = (actualDiscountAmount / subTotal) * 100;
    return actualDiscountPercent > _discountApprovalThreshold && _tabsDiscountApprovedBy[id] == null;
  }
  
  /// Xóa chiết khấu
  void clearDiscount({int? tabId}) {
    final id = tabId ?? _activeTabId;
    _tabsOrderDiscountValue[id] = 0.0;
    _tabsIsDiscountPercentage[id] = false;
    _tabsDiscountPercent[id] = 0.0;
    notifyListeners();
  }
  
  /// Đặt khách hàng được chọn và tự động áp dụng giảm giá
  Future<void> setSelectedCustomerWithDiscount(CustomerModel? customer, {int? tabId}) async {
    final id = tabId ?? _activeTabId;
    setSelectedCustomer(customer, tabId: id);
    await applyCustomerDiscount(tabId: id);
  }

  /// Áp dụng giảm giá từ nhóm khách hàng
  Future<void> applyCustomerDiscount({int? tabId}) async {
    final id = tabId ?? _activeTabId;
    final customer = _tabsCustomer[id];
    
    if (customer == null || _customerService == null) {
      _tabsDiscountPercent[id] = 0.0;
      notifyListeners();
      return;
    }

    // Nếu khách hàng không có nhóm, không có giảm giá
    if (customer.groupId == null || customer.groupId!.isEmpty) {
      _tabsDiscountPercent[id] = 0.0;
      if (kDebugMode) {
        debugPrint('Customer ${customer.name} has no group, no discount applied');
      }
      notifyListeners();
      return;
    }

    try {
      // Lấy thông tin nhóm khách hàng từ SQLite
      final customerGroup = await _customerService!.getCustomerGroupById(customer.groupId!);
      
      if (customerGroup != null) {
        _tabsDiscountPercent[id] = customerGroup.discountPercent;
        if (kDebugMode) {
          debugPrint('Applied discount ${customerGroup.discountPercent}% from customer group: ${customerGroup.name}');
        }
      } else {
        _tabsDiscountPercent[id] = 0.0;
        _tabsOrderDiscountValue[id] = 0.0;
        _tabsIsDiscountPercentage[id] = false;
        if (kDebugMode) {
          debugPrint('Customer group not found, no discount applied');
        }
      }
    } catch (e) {
      _tabsDiscountPercent[id] = 0.0;
      if (kDebugMode) {
        debugPrint('Error applying customer discount: $e');
      }
    }
    
    notifyListeners();
  }

  /// Tìm kiếm khách hàng (gọi từ UI)
  Future<List<CustomerModel>> searchCustomers(String query) async {
    if (_customerService == null || query.trim().isEmpty) {
      return [];
    }

    try {
      return await _customerService!.searchCustomers(query.trim());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error searching customers: $e');
      }
      return [];
    }
  }

  /// Thanh toán - Lưu đơn hàng và cập nhật stock
  Future<bool> checkout({int? tabId}) async {
    if (_salesService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    final id = tabId ?? _activeTabId;
    final cart = _tabsCart[id] ?? {};
    
    if (cart.isEmpty) {
      _errorMessage = 'Giỏ hàng trống';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Tính tổng tiền sau giảm giá
      final totalAmount = getFinalTotal(id);
      final cartItems = cart.values.toList();

      // Lấy thông tin seller
      final sellerId = authProvider.user!.uid;
      final sellerName = authProvider.userProfile?.displayName ?? 
                        authProvider.user?.email?.split('@').first ?? 
                        'Nhân viên';

      // Tạo đơn hàng với đầy đủ thông tin
      // Tính toán chi tiết chiết khấu
      final totals = calculateTotals(id);
      final subTotal = totals['subTotal'] ?? 0.0;
      final totalDiscountAmount = totals['totalDiscountAmount'] ?? 0.0;
      final orderDiscountValue = _tabsOrderDiscountValue[id] ?? 0.0;
      final isDiscountPercentage = _tabsIsDiscountPercentage[id] ?? false;
      final discountApprovedBy = _tabsDiscountApprovedBy[id];
      
      final sale = SaleModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        timestamp: DateTime.now(),
        totalAmount: totalAmount,
        items: cartItems,
        paymentMethod: getPaymentMethod(id),
        userId: authProvider.user!.uid,
        customerId: getSelectedCustomer(id)?.id,
        customerName: getCustomerName(id),
        customerTaxCode: getCustomerTaxCode(id),
        customerAddress: getCustomerAddress(id),
        notes: getNotes(id),
        branchId: branchProvider?.currentBranchId ?? authProvider.selectedBranchId ?? '',
        sellerId: sellerId, // ID của nhân viên bán hàng
        sellerName: sellerName, // Tên nhân viên bán hàng
        subTotal: subTotal, // Tổng tiền hàng sau khi trừ chiết khấu từng dòng
        orderDiscountValue: orderDiscountValue > 0 ? orderDiscountValue : null,
        orderDiscountType: orderDiscountValue > 0 
            ? (isDiscountPercentage ? 'percentage' : 'amount')
            : null,
        totalDiscountAmount: totalDiscountAmount > 0 ? totalDiscountAmount : null,
        discountApprovedBy: discountApprovedBy,
        // Tương thích ngược
        totalBeforeDiscount: subTotal,
        discountAmount: totalDiscountAmount > 0 ? totalDiscountAmount : null,
      );

      // Lưu đơn hàng (saveSale tự động cập nhật stock khi paymentStatus = COMPLETED; không trừ kho thêm)
      await _salesService!.saveSale(
        sale.copyWith(isStockUpdated: true),
        customerService: _customerService,
      );

      // Tự động lưu khách hàng mới nếu chưa có trong hệ thống
      final selectedCustomer = getSelectedCustomer(id);
      final customerPhone = getCustomerPhone(id);
      final customerName = getCustomerName(id);
      final customerAddress = getCustomerAddress(id);
      
      if (selectedCustomer == null &&
          customerPhone != null &&
          customerPhone.length >= 10 &&
          customerName != null &&
          customerName.isNotEmpty &&
          _customerService != null) {
        try {
          final newCustomer = CustomerModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: customerName,
            phone: customerPhone,
            address: customerAddress,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _customerService!.addCustomer(newCustomer);
          if (kDebugMode) {
            debugPrint('✅ Tự động lưu khách hàng mới: $customerName');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Lỗi khi tự động lưu khách hàng mới: $e');
          }
        }
      }

      // Tạo hóa đơn điện tử nếu đã cấu hình
      _lastInvoiceUrl = null;
      final shop = authProvider.shop;
      if (shop?.einvoiceConfig != null && 
          shop?.stax != null && 
          shop!.stax!.isNotEmpty &&
          shop.serial != null &&
          shop.serial!.isNotEmpty) {
        try {
          final invoiceInfo = await _einvoiceService.createInvoice(
            sale: sale,
            shop: shop,
          );
          _lastInvoiceUrl = invoiceInfo['link'];
          if (kDebugMode) {
            debugPrint('✅ Hóa đơn điện tử đã được tạo: ${invoiceInfo['link']}');
          }
        } catch (e) {
          // Log lỗi nhưng không chặn quá trình thanh toán
          if (kDebugMode) {
            debugPrint('⚠️ Lỗi khi tạo hóa đơn điện tử: $e');
          }
          // Lưu lỗi để hiển thị cho user
          _errorMessage = 'Thanh toán thành công nhưng không thể tạo hóa đơn điện tử: $e';
        }
      }

      // Xóa giỏ hàng sau khi thanh toán thành công
      clearCart(tabId: id);

      _checkoutSuccessNotifyCount++;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi thanh toán: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('SalesProvider checkout error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Thanh toán bằng chuyển khoản thủ công - Tạo đơn hàng với status PENDING (không cần PayOS)
  Future<String?> checkoutWithTransferManual({int? tabId}) async {
    if (_salesService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return null;
    }

    final id = tabId ?? _activeTabId;
    final cart = _tabsCart[id] ?? {};
    
    if (cart.isEmpty) {
      _errorMessage = 'Giỏ hàng trống';
      notifyListeners();
      return null;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Lấy thông tin seller
      final sellerId = authProvider.user!.uid;
      final sellerName = authProvider.userProfile?.displayName ?? 
                        authProvider.user?.email?.split('@').first ?? 
                        'Nhân viên';

      // Tạo đơn hàng với paymentStatus = PENDING
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();
      final cartItems = cart.values.toList();
      // Tính toán chi tiết chiết khấu
      final totals = calculateTotals(id);
      final subTotal = totals['subTotal'] ?? 0.0;
      final totalDiscountAmount = totals['totalDiscountAmount'] ?? 0.0;
      final orderDiscountValue = _tabsOrderDiscountValue[id] ?? 0.0;
      final isDiscountPercentage = _tabsIsDiscountPercentage[id] ?? false;
      final discountApprovedBy = _tabsDiscountApprovedBy[id];
      
      final sale = SaleModel(
        id: orderId,
        timestamp: DateTime.now(),
        totalAmount: getCartTotal(id),
        items: cartItems,
        paymentMethod: 'TRANSFER_MANUAL', // Chuyển khoản thủ công
        paymentStatus: 'PENDING', // Chưa thanh toán
        userId: authProvider.user!.uid,
        customerId: getSelectedCustomer(id)?.id,
        customerName: getCustomerName(id),
        customerTaxCode: getCustomerTaxCode(id),
        customerAddress: getCustomerAddress(id),
        notes: getNotes(id),
        branchId: branchProvider?.currentBranchId ?? authProvider.selectedBranchId ?? '',
        sellerId: sellerId, // ID của nhân viên bán hàng
        sellerName: sellerName, // Tên nhân viên bán hàng
        subTotal: subTotal,
        orderDiscountValue: orderDiscountValue > 0 ? orderDiscountValue : null,
        orderDiscountType: orderDiscountValue > 0 
            ? (isDiscountPercentage ? 'percentage' : 'amount')
            : null,
        totalDiscountAmount: totalDiscountAmount > 0 ? totalDiscountAmount : null,
        discountApprovedBy: discountApprovedBy,
        totalBeforeDiscount: subTotal,
        discountAmount: totalDiscountAmount > 0 ? totalDiscountAmount : null,
      );

      // Lưu đơn hàng với status PENDING (KHÔNG cập nhật stock ngay)
      // Chỉ cập nhật stock khi paymentStatus = COMPLETED
      await _salesService!.saveSale(sale);

      // Tự động lưu khách hàng mới nếu chưa có trong hệ thống
      final selectedCustomer = getSelectedCustomer(id);
      final customerPhone = getCustomerPhone(id);
      final customerName = getCustomerName(id);
      final customerAddress = getCustomerAddress(id);
      
      if (selectedCustomer == null &&
          customerPhone != null &&
          customerPhone.length >= 10 &&
          customerName != null &&
          customerName.isNotEmpty &&
          _customerService != null) {
        try {
          final newCustomer = CustomerModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: customerName,
            phone: customerPhone,
            address: customerAddress,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _customerService!.addCustomer(newCustomer);
          if (kDebugMode) {
            debugPrint('✅ Tự động lưu khách hàng mới: $customerName');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Lỗi khi tự động lưu khách hàng mới: $e');
          }
        }
      }

      // Xóa giỏ hàng sau khi tạo đơn hàng
      clearCart(tabId: id);

      _isLoading = false;
      notifyListeners();
      return orderId;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi tạo đơn hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('SalesProvider checkoutWithTransferManual error: $_errorMessage');
      }
      notifyListeners();
      return null;
    }
  }

  /// Thanh toán bằng chuyển khoản QR (PayOS) - Tạo đơn hàng với status PENDING và QR code
  Future<String?> checkoutWithTransfer({int? tabId}) async {
    if (_salesService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return null;
    }

    final id = tabId ?? _activeTabId;
    final cart = _tabsCart[id] ?? {};
    
    if (cart.isEmpty) {
      _errorMessage = 'Giỏ hàng trống';
      notifyListeners();
      return null;
    }

    final shop = authProvider.shop;
    if (shop?.paymentConfig == null || !shop!.paymentConfig!.isConfigured) {
      _errorMessage = 'Chưa cấu hình thông tin thanh toán PayOS. Vui lòng vào Cài đặt để cấu hình.';
      notifyListeners();
      return null;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Tính tổng tiền sau giảm giá
      final totalAmount = getFinalTotal(id);
      final cartItems = cart.values.toList();

      // Lấy thông tin seller
      final sellerId = authProvider.user!.uid;
      final sellerName = authProvider.userProfile?.displayName ?? 
                        authProvider.user?.email?.split('@').first ?? 
                        'Nhân viên';

      // Tạo đơn hàng với paymentStatus = PENDING
      final orderId = DateTime.now().millisecondsSinceEpoch.toString();
      // Tính toán chi tiết chiết khấu
      final totals = calculateTotals(id);
      final subTotal = totals['subTotal'] ?? 0.0;
      final totalDiscountAmount = totals['totalDiscountAmount'] ?? 0.0;
      final orderDiscountValue = _tabsOrderDiscountValue[id] ?? 0.0;
      final isDiscountPercentage = _tabsIsDiscountPercentage[id] ?? false;
      final discountApprovedBy = _tabsDiscountApprovedBy[id];
      
      final sale = SaleModel(
        id: orderId,
        timestamp: DateTime.now(),
        totalAmount: totalAmount,
        items: cartItems,
        paymentMethod: 'PAYOS', // Thanh toán qua PayOS QR
        paymentStatus: 'PENDING', // Chưa thanh toán
        userId: authProvider.user!.uid,
        customerId: getSelectedCustomer(id)?.id,
        customerName: getCustomerName(id),
        customerTaxCode: getCustomerTaxCode(id),
        customerAddress: getCustomerAddress(id),
        notes: getNotes(id),
        branchId: branchProvider?.currentBranchId ?? authProvider.selectedBranchId ?? '',
        sellerId: sellerId, // ID của nhân viên bán hàng
        sellerName: sellerName, // Tên nhân viên bán hàng
        subTotal: subTotal,
        orderDiscountValue: orderDiscountValue > 0 ? orderDiscountValue : null,
        orderDiscountType: orderDiscountValue > 0 
            ? (isDiscountPercentage ? 'percentage' : 'amount')
            : null,
        totalDiscountAmount: totalDiscountAmount > 0 ? totalDiscountAmount : null,
        discountApprovedBy: discountApprovedBy,
        totalBeforeDiscount: subTotal,
        discountAmount: totalDiscountAmount > 0 ? totalDiscountAmount : null,
      );

      // Lưu đơn hàng với status PENDING (KHÔNG cập nhật stock ngay)
      // Chỉ cập nhật stock khi paymentStatus = COMPLETED
      await _salesService!.saveSale(
        sale,
        customerService: _customerService,
      );

      // Lưu orderId để polling
      _pendingSaleId = orderId;

      _isLoading = false;
      notifyListeners();
      return orderId;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi tạo đơn hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('SalesProvider checkoutWithTransfer error: $_errorMessage');
      }
      notifyListeners();
      return null;
    }
  }

  /// Hoàn tất thanh toán chuyển khoản - Cập nhật status và stock
  Future<bool> completeTransferPayment(String saleId) async {
    if (_salesService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Cập nhật payment status thành COMPLETED
      await _salesService!.updateSalePaymentStatus(saleId, 'COMPLETED');

      // Lấy đơn hàng để cập nhật stock
      // Note: Để đơn giản, chúng ta sẽ lấy lại sale từ service và cập nhật stock
      // Trong thực tế, có thể cần refactor để tránh duplicate logic
      final sales = await _salesService!.getSales(
        branchId: branchProvider?.currentBranchId,
      );
      final sale = sales.firstWhere((s) => s.id == saleId, orElse: () => throw Exception('Sale not found'));
      
      // Kiểm tra flag isStockUpdated để tránh trừ kho 2 lần (double-spending)
      if (sale.isStockUpdated) {
        if (kDebugMode) {
          debugPrint('⚠️ Hóa đơn $saleId đã được trừ kho trước đó, bỏ qua trừ kho lần 2');
        }
        // Chỉ cập nhật payment status, không trừ kho nữa
        await _salesService!.updateSalePaymentStatus(saleId, 'COMPLETED');
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      // Cập nhật stock: saveSale với paymentStatus COMPLETED sẽ tự động trừ kho (chỉ một lần)
      final completedSale = SaleModel(
        id: sale.id,
        timestamp: sale.timestamp,
        totalAmount: sale.totalAmount,
        items: sale.items,
        paymentMethod: sale.paymentMethod,
        paymentStatus: 'COMPLETED',
        userId: sale.userId,
        customerId: sale.customerId,
        customerName: sale.customerName,
        customerTaxCode: sale.customerTaxCode,
        customerAddress: sale.customerAddress,
        notes: sale.notes,
        branchId: sale.branchId,
        sellerId: sale.sellerId,
        sellerName: sale.sellerName,
        isStockUpdated: true, // Đánh dấu ngay; saveSale sẽ trừ kho một lần
        subTotal: sale.subTotal,
        orderDiscountValue: sale.orderDiscountValue,
        orderDiscountType: sale.orderDiscountType,
        totalDiscountAmount: sale.totalDiscountAmount,
        discountApprovedBy: sale.discountApprovedBy,
        totalBeforeDiscount: sale.totalBeforeDiscount,
        discountAmount: sale.discountAmount,
      );

      await _salesService!.saveSale(
        completedSale,
        customerService: _customerService,
      );

      // Tự động lưu khách hàng mới nếu chưa có trong hệ thống
      // (Áp dụng cho trường hợp completeTransferPayment)
      // Lưu ý: Không có context tabId ở đây, nên chỉ lưu nếu có đủ thông tin từ sale
      if (sale.customerId == null &&
          sale.customerName != null &&
          sale.customerName!.isNotEmpty &&
          _customerService != null) {
        // Chỉ lưu nếu có đủ thông tin cơ bản
        try {
          final newCustomer = CustomerModel(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            name: sale.customerName!,
            phone: sale.customerName!, // Tạm thời dùng name làm phone, UI sẽ cập nhật sau
            address: sale.customerAddress,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _customerService!.addCustomer(newCustomer);
          if (kDebugMode) {
            debugPrint('✅ Tự động lưu khách hàng mới (completeTransferPayment): ${sale.customerName}');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Lỗi khi tự động lưu khách hàng mới (completeTransferPayment): $e');
          }
        }
      }

      // Dừng polling
      _stopPaymentPolling();

      _checkoutSuccessNotifyCount++;

      // Tạo hóa đơn điện tử nếu đã cấu hình
      _lastInvoiceUrl = null;
      final shop = authProvider.shop;
      if (shop?.einvoiceConfig != null && 
          shop?.stax != null && 
          shop!.stax!.isNotEmpty &&
          shop.serial != null &&
          shop.serial!.isNotEmpty) {
        try {
          final invoiceInfo = await _einvoiceService.createInvoice(
            sale: sale,
            shop: shop,
          );
          _lastInvoiceUrl = invoiceInfo['link'];
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Lỗi khi tạo hóa đơn điện tử: $e');
          }
        }
      }

      // Xóa giỏ hàng
      clearCart();
      _pendingSaleId = null;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi hoàn tất thanh toán: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('SalesProvider completeTransferPayment error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Bắt đầu polling để kiểm tra trạng thái thanh toán
  void startPaymentPolling(String orderId, PaymentService paymentService) {
    // Dừng polling cũ nếu có
    _stopPaymentPolling();

    _paymentPollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final isPaid = await paymentService.checkPaymentStatus(orderId);
        if (isPaid) {
          // Thanh toán thành công, hoàn tất đơn hàng
          timer.cancel();
          await completeTransferPayment(orderId);
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Payment polling error: $e');
        }
      }
    });
  }

  /// Dừng polling thanh toán
  void _stopPaymentPolling() {
    _paymentPollingTimer?.cancel();
    _paymentPollingTimer = null;
  }

  /// Kiểm tra stock của sản phẩm trong giỏ
  Future<bool> checkStock(String productId, {int? tabId}) async {
    if (_productService == null) return false;

    try {
      final product = await _productService!.getProductById(productId);
      if (product == null) return false;

      final id = tabId ?? _activeTabId;
      final cart = _tabsCart[id] ?? {};
      final cartItem = cart[productId];
      if (cartItem == null) return true;

      return product.stock >= cartItem.quantity;
    } catch (e) {
      return false;
    }
  }
  
  /// Lưu giỏ hàng tạm (draft) vào database
  Future<bool> saveDraft(int tabId) async {
    if (_salesService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      final cart = _tabsCart[tabId] ?? {};
      if (cart.isEmpty) {
        // Nếu giỏ hàng trống, xóa draft nếu có
        await _localDb.deleteDraftCart(tabId);
        return true;
      }

      // Lưu draft vào database
      await _localDb.saveDraftCart(
        tabId: tabId,
        cartItems: cart.values.toList(),
        paymentMethod: getPaymentMethod(tabId),
        customer: getSelectedCustomer(tabId),
        customerName: getCustomerName(tabId),
        customerPhone: getCustomerPhone(tabId),
        customerTaxCode: getCustomerTaxCode(tabId),
        customerAddress: getCustomerAddress(tabId),
        notes: getNotes(tabId),
        discountPercent: getDiscountPercent(tabId),
      );

      if (kDebugMode) {
        debugPrint('✅ Đã lưu draft cho tab $tabId');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Lỗi khi lưu draft: $e');
      }
      _errorMessage = 'Lỗi khi lưu giỏ hàng tạm: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  /// Tải giỏ hàng tạm (draft) từ database
  Future<bool> loadDraft(int tabId) async {
    if (_salesService == null) {
      return false;
    }

    try {
      final draft = await _localDb.getDraftCart(tabId);
      if (draft == null) {
        // Không có draft, tạo cart trống
        _tabsCart[tabId] ??= {};
        return true;
      }

      // Khôi phục giỏ hàng từ draft
      _tabsCart[tabId] = {};
      for (final item in draft['cartItems'] as List<SaleItem>) {
        _tabsCart[tabId]![item.productId] = item;
      }

      // Khôi phục các thông tin khác
      _tabsPaymentMethod[tabId] = draft['paymentMethod'] as String? ?? 'CASH';
      _tabsCustomer[tabId] = draft['customer'] as CustomerModel?;
      _tabsCustomerName[tabId] = draft['customerName'] as String?;
      _tabsCustomerPhone[tabId] = draft['customerPhone'] as String?;
      _tabsCustomerTaxCode[tabId] = draft['customerTaxCode'] as String?;
      _tabsCustomerAddress[tabId] = draft['customerAddress'] as String?;
      _tabsNotes[tabId] = draft['notes'] as String?;
      _tabsDiscountPercent[tabId] = draft['discountPercent'] as double? ?? 0.0;

      if (kDebugMode) {
        debugPrint('✅ Đã tải draft cho tab $tabId với ${_tabsCart[tabId]!.length} sản phẩm');
      }
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Lỗi khi tải draft: $e');
      }
      return false;
    }
  }
  
  /// Lấy đơn hàng theo ID (dùng khi mở chi tiết từ thông báo).
  Future<SaleModel?> getSaleById(String saleId) async {
    if (_salesService == null) return null;
    try {
      return await _salesService!.getSaleById(saleId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SalesProvider getSaleById error: $e');
      }
      return null;
    }
  }

  /// Lưu tất cả giỏ hàng tạm
  Future<void> saveAllDrafts() async {
    for (final tabId in _tabsCart.keys) {
      await saveDraft(tabId);
    }
  }

  @override
  void dispose() {
    _stopPaymentPolling();
    authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}

