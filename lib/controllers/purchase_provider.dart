import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../models/purchase_model.dart';
import '../services/purchase_service.dart';
import '../services/product_service.dart';
import 'auth_provider.dart';
import 'branch_provider.dart';

/// Provider quản lý giỏ hàng nhập kho và phiếu nhập
class PurchaseProvider with ChangeNotifier {
  final AuthProvider authProvider;
  final BranchProvider? branchProvider; // Optional để tương thích ngược
  PurchaseService? _purchaseService;
  ProductService? _productService;

  // Giỏ hàng nhập kho
  final Map<String, PurchaseItem> _cart = {}; // Key: productId
  String _supplierName = '';

  // State
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  Map<String, PurchaseItem> get cart => Map.unmodifiable(_cart);
  List<PurchaseItem> get cartItems => _cart.values.toList();
  int get cartItemCount => _cart.length;
  double get cartTotal {
    return _cart.values.fold(0.0, (sum, item) => sum + item.subtotal);
  }
  String get supplierName => _supplierName;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isCartEmpty => _cart.isEmpty;

  PurchaseProvider(this.authProvider, {this.branchProvider}) {
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
      _purchaseService = PurchaseService(
        isPro: isPro,
        userId: user.uid,
        productService: _productService!,
      );
    } else {
      _productService = null;
      _purchaseService = null;
      _cart.clear();
    }
    notifyListeners();
  }

  /// Xử lý khi auth state thay đổi
  void _onAuthChanged() {
    _initializeServices();
  }

  /// Thêm sản phẩm vào giỏ hàng nhập kho
  void addToCart(ProductModel product, {double quantity = 1, double? importPrice}) {
    final price = importPrice ?? product.importPrice;

    if (_cart.containsKey(product.id)) {
      // Cập nhật số lượng và giá nhập nếu sản phẩm đã có trong giỏ
      final existingItem = _cart[product.id]!;
      final newQuantity = existingItem.quantity + quantity;
      
      _cart[product.id] = existingItem.copyWith(
        quantity: newQuantity,
        importPrice: price, // Cập nhật giá nhập mới nhất
      );
    } else {
      // Thêm sản phẩm mới vào giỏ
      _cart[product.id] = PurchaseItem(
        productId: product.id,
        productName: product.name,
        quantity: quantity,
        importPrice: price,
      );
    }

    _errorMessage = null;
    notifyListeners();
  }

  /// Cập nhật số lượng và giá nhập sản phẩm trong giỏ
  void updateCartItem(String productId, {double? quantity, double? importPrice}) {
    if (!_cart.containsKey(productId)) return;

    final item = _cart[productId]!;
    _cart[productId] = item.copyWith(
      quantity: quantity ?? item.quantity,
      importPrice: importPrice ?? item.importPrice,
    );

    // Nếu số lượng <= 0, xóa khỏi giỏ
    if (_cart[productId]!.quantity <= 0) {
      removeFromCart(productId);
      return;
    }

    notifyListeners();
  }

  /// Xóa sản phẩm khỏi giỏ hàng
  void removeFromCart(String productId) {
    _cart.remove(productId);
    notifyListeners();
  }

  /// Xóa toàn bộ giỏ hàng
  void clearCart() {
    _cart.clear();
    _supplierName = '';
    _errorMessage = null;
    notifyListeners();
  }

  /// Cập nhật tên nhà cung cấp
  void setSupplierName(String name) {
    _supplierName = name;
    notifyListeners();
  }

  /// Lưu phiếu nhập (DRAFT hoặc COMPLETED)
  Future<bool> savePurchase({bool complete = false}) async {
    if (_purchaseService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    if (_cart.isEmpty) {
      _errorMessage = 'Giỏ hàng trống';
      notifyListeners();
      return false;
    }

    if (_supplierName.trim().isEmpty) {
      _errorMessage = 'Vui lòng nhập tên nhà cung cấp';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      // Tạo phiếu nhập
      final purchase = PurchaseModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        supplierName: _supplierName.trim(),
        timestamp: DateTime.now(),
        totalAmount: cartTotal,
        items: cartItems,
        status: complete ? 'COMPLETED' : 'DRAFT',
        userId: authProvider.user!.uid,
        branchId: branchProvider?.currentBranchId ?? authProvider.selectedBranchId ?? '',
      );

      // Lưu phiếu nhập (nếu COMPLETED sẽ tự động cập nhật stock)
      await _purchaseService!.savePurchase(purchase);

      // Xóa giỏ hàng sau khi lưu thành công
      clearCart();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi lưu phiếu nhập: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('PurchaseProvider savePurchase error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    authProvider.removeListener(_onAuthChanged);
    super.dispose();
  }
}

