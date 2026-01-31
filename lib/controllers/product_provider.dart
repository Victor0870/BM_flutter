import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/inventory_report_model.dart';
import '../models/stock_history_model.dart';
import '../services/product_service.dart';
import '../services/stock_history_service.dart';
import 'auth_provider.dart';
import 'branch_provider.dart';

/// Provider quản lý danh sách sản phẩm và state
/// UI không cần quan tâm dữ liệu đang đến từ Cloud hay Local
class ProductProvider with ChangeNotifier {
  final AuthProvider authProvider;
  final BranchProvider? branchProvider; // Optional để tương thích ngược
  ProductService? _productService;
  StockHistoryService? _stockHistoryService;
  
  List<ProductModel> _products = [];
  bool _isLoading = false;
  String? _errorMessage;
  String? _searchQuery;
  bool _disposed = false; // Flag để kiểm tra xem provider đã bị dispose chưa
  StreamSubscription<List<ProductModel>>? _productsSubscription; // Real-time Firestore (PRO)

  // Getters
  List<ProductModel> get products => _products;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get searchQuery => _searchQuery;
  int get productCount => _products.length;

  // Category getters
  List<CategoryModel> get categories => _categories;
  bool get isLoadingCategories => _isLoadingCategories;
  String? get categoryErrorMessage => _categoryErrorMessage;

  // Categories state
  List<CategoryModel> _categories = [];
  bool _isLoadingCategories = false;
  String? _categoryErrorMessage;

  ProductProvider(this.authProvider, {this.branchProvider}) {
    // Lắng nghe thay đổi từ AuthProvider để cập nhật ProductService
    authProvider.addListener(_onAuthChanged);
    _initializeService();
    // PRO: bắt đầu lắng nghe Firestore real-time ngay khi provider khởi tạo (nếu đã đăng nhập + isPro)
    if (authProvider.user != null && authProvider.isPro) {
      startListening();
    }
    // Lắng nghe thay đổi selectedBranchId để reload products
    authProvider.addListener(_onSelectedBranchChanged);
    // Lắng nghe thay đổi currentBranchId từ BranchProvider
    if (branchProvider != null) {
      branchProvider!.addListener(_onBranchChanged);
    }
  }

  /// Khởi tạo ProductService dựa trên trạng thái auth
  void _initializeService() {
    final user = authProvider.user;
    final isPro = authProvider.isPro;

    if (user != null) {
      _productService = ProductService(
        isPro: isPro,
        userId: user.uid,
      );
      _stockHistoryService = StockHistoryService(
        isPro: isPro,
        userId: user.uid,
      );
    } else {
      _productService = null;
      _stockHistoryService = null;
      _products = [];
    }
    notifyListeners();
  }

  /// Xử lý khi auth state thay đổi
  void _onAuthChanged() {
    final user = authProvider.user;
    final isPro = authProvider.isPro;

    if (user != null) {
      final wasPro = _productService?.isPro ?? false;

      _productService = ProductService(
        isPro: isPro,
        userId: user.uid,
      );
      _stockHistoryService = StockHistoryService(
        isPro: isPro,
        userId: user.uid,
      );

      if (!wasPro && isPro) {
        migrateLocalToCloud();
      } else {
        loadProducts();
      }

      if (isPro) {
        startListening();
        // PRO: light sync từ Cloud để cập nhật tồn kho/dữ liệu mới nhất (loadProducts đã gọi ở trên khi wasPro)
        _performLightSyncFromCloud();
      } else {
        _cancelProductsSubscription();
      }
    } else {
      _cancelProductsSubscription();
      _productService = null;
      _stockHistoryService = null;
      _products = [];
      notifyListeners();
    }
  }

  /// Light sync: lấy danh sách sản phẩm từ Cloud một lần, cập nhật SQLite và _products. Chỉ cho PRO.
  void _performLightSyncFromCloud() {
    if (_productService == null || !authProvider.isPro) return;
    _productService!.fetchProductsFromCloud(includeInactive: false).then((products) {
      if (_disposed) return;
      if (products.isEmpty) return;
      _products = products;
      if (!kIsWeb) {
        _productService?.syncProductsToLocal(products);
      }
      _safeNotifyListeners();
      if (kDebugMode) {
        debugPrint('✅ ProductProvider light sync: ${products.length} products from Cloud');
      }
    }).catchError((e, st) {
      if (kDebugMode) {
        debugPrint('⚠️ ProductProvider light sync error: $e');
      }
    });
  }

  /// Hủy subscription real-time (khi logout hoặc chuyển BASIC).
  void _cancelProductsSubscription() {
    _productsSubscription?.cancel();
    _productsSubscription = null;
  }

  /// Xử lý khi selectedBranchId thay đổi
  void _onSelectedBranchChanged() {
    // Reload products khi chi nhánh được chọn thay đổi
    if (_productService != null && authProvider.selectedBranchId != null) {
      loadProducts();
    }
  }

  /// Xử lý khi currentBranchId từ BranchProvider thay đổi
  void _onBranchChanged() {
    // Reload products khi chi nhánh hiện tại thay đổi
    if (_productService != null && branchProvider?.currentBranchId != null) {
      loadProducts();
      notifyListeners(); // Thông báo để UI cập nhật tồn kho
    }
  }

  /// Lấy tồn kho của sản phẩm theo chi nhánh hiện tại
  /// Nếu không có branchProvider hoặc currentBranchId, trả về tổng tồn kho
  double getStockForCurrentBranch(ProductModel product) {
    if (branchProvider?.currentBranchId != null) {
      final branchId = branchProvider!.currentBranchId!;
      return product.branchStock[branchId] ?? 0.0;
    }
    // Fallback: trả về tổng tồn kho nếu không có chi nhánh được chọn
    return product.stock;
  }

  /// Trừ tồn kho sản phẩm theo chi nhánh
  /// Gọi service để cập nhật database và cập nhật state cục bộ để UI đồng bộ ngay lập tức
  /// [productId] ID của sản phẩm cần trừ kho
  /// [branchId] ID của chi nhánh cần trừ kho
  /// [amount] Số lượng cần trừ (phải là số dương)
  Future<bool> decreaseStock(
    String productId,
    String branchId,
    double amount,
  ) async {
    if (_productService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    if (amount <= 0) {
      _errorMessage = 'Số lượng trừ phải lớn hơn 0';
      notifyListeners();
      return false;
    }

    try {
      // Kiểm tra tồn kho trước khi trừ
      final productIndex = _products.indexWhere((p) => p.id == productId);
      if (productIndex != -1) {
        final product = _products[productIndex];
        final currentStock = product.branchStock[branchId] ?? 0.0;
        
        // Đảm bảo không âm trước khi trừ
        if (currentStock < amount) {
          _errorMessage = 'Tồn kho không đủ. Tồn kho hiện tại: $currentStock, cần trừ: $amount';
          notifyListeners();
          return false;
        }
      }

      // Gọi service để cập nhật database (số âm để trừ)
      await _productService!.updateProductStock(productId, branchId, -amount);

      // Cập nhật state cục bộ để UI đồng bộ ngay lập tức
      // Lấy lại sản phẩm từ SQLite để đảm bảo đồng bộ (hoặc tính toán dựa trên giá trị đã trừ)
      if (productIndex != -1) {
        final product = _products[productIndex];
        final currentStock = product.branchStock[branchId] ?? 0.0;
        final newStock = currentStock - amount; // Tính toán dựa trên giá trị hiện tại trong memory
        
        // Cập nhật branchStock trong memory
        final updatedBranchStock = Map<String, double>.from(product.branchStock);
        updatedBranchStock[branchId] = newStock;
        
        // Cập nhật sản phẩm trong danh sách
        _products[productIndex] = product.copyWith(branchStock: updatedBranchStock);
        
        if (kDebugMode) {
          debugPrint('✅ Product stock decreased locally: $productId, branchId=$branchId, oldStock=$currentStock, newStock=$newStock');
        }
      } else {
        // Nếu không tìm thấy trong memory, reload từ SQLite
        try {
          final updatedProduct = await _productService!.getProductById(productId);
          if (updatedProduct != null) {
            // Tìm và cập nhật trong danh sách
            final index = _products.indexWhere((p) => p.id == productId);
            if (index != -1) {
              _products[index] = updatedProduct;
            }
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Could not reload product from SQLite: $e');
          }
        }
      }

      _errorMessage = null;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi khi trừ tồn kho: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider decreaseStock error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Đồng bộ toàn bộ dữ liệu từ Firestore về SQLite
  /// Được gọi khi khởi tạo ứng dụng hoặc khi người dùng nhấn 'Đồng bộ'
  Future<void> syncAllFromCloud() async {
    if (_productService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _safeNotifyListeners();

      await _productService!.syncAllFromCloud();

      // Sau khi sync, reload products từ SQLite
      await loadProducts();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi đồng bộ dữ liệu: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider syncAllFromCloud error: $_errorMessage');
      }
      notifyListeners();
    }
  }

  /// Load danh sách sản phẩm
  Future<void> loadProducts({bool includeInactive = false}) async {
    if (_productService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _safeNotifyListeners();

      // Truyền selectedBranchId để filter theo chi nhánh
      _products = await _productService!.getProducts(
        includeInactive: includeInactive,
        activeBranchId: authProvider.selectedBranchId,
      );

      _isLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi tải danh sách sản phẩm: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider loadProducts error: $_errorMessage');
      }
      _safeNotifyListeners();
    }
  }

  /// Tìm kiếm sản phẩm
  Future<void> searchProducts(String query) async {
    if (_productService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return;
    }

    if (query.trim().isEmpty) {
      _searchQuery = null;
      await loadProducts();
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _searchQuery = query;
      notifyListeners();

      // Truyền selectedBranchId để filter theo chi nhánh
      _products = await _productService!.searchProducts(
        query,
        activeBranchId: authProvider.selectedBranchId,
      );

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi tìm kiếm sản phẩm: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider searchProducts error: $_errorMessage');
      }
      notifyListeners();
    }
  }

  /// Lấy sản phẩm theo ID
  Future<ProductModel?> getProductById(String id) async {
    if (_productService == null) {
      return null;
    }

    try {
      return await _productService!.getProductById(id);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProductProvider getProductById error: $e');
      }
      return null;
    }
  }

  /// Thêm sản phẩm mới
  Future<bool> addProduct(ProductModel product) async {
    if (_productService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _safeNotifyListeners();

      await _productService!.addProduct(product);

      // Reload danh sách
      await loadProducts();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi thêm sản phẩm: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider addProduct error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Cập nhật sản phẩm
  /// Nếu sản phẩm có variants, tổng stock sẽ được tính tự động từ variants
  Future<bool> updateProduct(ProductModel product) async {
    if (_productService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _safeNotifyListeners();

      // Nếu có variants, tính tổng stock từ variants cho tất cả branches
      ProductModel productToUpdate = product;
      if (product.variants.isNotEmpty) {
        // Tính tổng branchStock từ tất cả variants
        Map<String, double> totalBranchStock = {};
        for (var variant in product.variants) {
          variant.branchStock.forEach((branchId, stock) {
            totalBranchStock[branchId] = (totalBranchStock[branchId] ?? 0.0) + stock;
          });
        }
        // Merge với branchStock hiện tại của product
        final mergedBranchStock = Map<String, double>.from(product.branchStock);
        totalBranchStock.forEach((branchId, stock) {
          mergedBranchStock[branchId] = stock;
        });
        productToUpdate = product.copyWith(branchStock: mergedBranchStock);
      }

      await _productService!.updateProduct(productToUpdate);

      // Cập nhật trong danh sách local
      final index = _products.indexWhere((p) => p.id == productToUpdate.id);
      if (index != -1) {
        _products[index] = productToUpdate;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi cập nhật sản phẩm: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider updateProduct error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Xóa sản phẩm (soft delete)
  Future<bool> deleteProduct(String id) async {
    if (_productService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _safeNotifyListeners();

      await _productService!.deleteProduct(id);

      // Xóa khỏi danh sách local
      _products.removeWhere((p) => p.id == id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi xóa sản phẩm: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider deleteProduct error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Xóa vĩnh viễn sản phẩm
  Future<bool> deleteProductPermanently(String id) async {
    if (_productService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _safeNotifyListeners();

      await _productService!.deleteProductPermanently(id);

      // Xóa khỏi danh sách local
      _products.removeWhere((p) => p.id == id);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi xóa vĩnh viễn sản phẩm: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider deleteProductPermanently error: $_errorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Migrate dữ liệu từ Local DB lên Firestore
  /// Được gọi tự động khi user nâng cấp từ BASIC lên PRO
  Future<void> migrateLocalToCloud() async {
    if (_productService == null) {
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;
      _safeNotifyListeners();

      await _productService!.migrateLocalToCloud();

      // Reload products sau khi migrate
      await loadProducts();

      _isLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Lỗi khi đồng bộ dữ liệu: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider migrateLocalToCloud error: $_errorMessage');
      }
      _safeNotifyListeners();
    }
  }

  /// Lắng nghe thay đổi real-time từ Firestore (chỉ cho PRO). Tự cập nhật _products và UI.
  void startListening() {
    if (_productService == null || !authProvider.isPro) return;

    _cancelProductsSubscription();

    final stream = _productService!.watchProducts();
    if (stream == null) return;

    _productsSubscription = stream.listen(
      (products) {
        if (_disposed) return;
        _products = products;
        _safeNotifyListeners();
        // Đồng bộ xuống SQLite để khi mất mạng vẫn có dữ liệu mới nhất (không chạy trên web)
        if (!kIsWeb) {
          _productService?.syncProductsToLocal(products);
        }
      },
      onError: (Object e, StackTrace st) {
        if (kDebugMode) {
          debugPrint('ProductProvider watchProducts error: $e');
        }
      },
    );
  }

  /// Clear search query
  void clearSearch() {
    _searchQuery = null;
    loadProducts();
  }

  // ==================== STOCK FILTERING ====================

  /// Lọc sản phẩm theo trạng thái tồn kho
  /// [selectedBranchId] ID của chi nhánh cần lọc (null = tất cả chi nhánh)
  /// [filterType] Loại lọc: 'all', 'low_stock', 'out_of_stock'
  List<ProductModel> getFilteredProductsByStock({
    String? selectedBranchId,
    String filterType = 'all',
  }) {
    if (filterType == 'all') {
      return _products;
    }

    return _products.where((product) {
      double stock = 0.0;
      
      // Lấy tồn kho theo chi nhánh
      if (selectedBranchId != null && selectedBranchId.isNotEmpty) {
        if (product.variants.isNotEmpty) {
          for (final variant in product.variants) {
            stock += variant.branchStock[selectedBranchId] ?? 0.0;
          }
        } else {
          stock = product.branchStock[selectedBranchId] ?? 0.0;
        }
      } else {
        // Tổng tồn kho tất cả chi nhánh
        stock = product.stock;
      }

      final minStock = product.minStock ?? 0.0;

      switch (filterType) {
        case 'low_stock':
          // Sắp hết: tồn kho <= minStock và > 0
          return stock > 0 && stock <= minStock;
        case 'out_of_stock':
          // Hết hàng: tồn kho <= 0
          return stock <= 0;
        default:
          return true;
      }
    }).toList();
  }

  /// Đếm số sản phẩm cần nhập thêm (Low stock)
  /// [selectedBranchId] ID của chi nhánh cần kiểm tra (null = tất cả chi nhánh)
  int getLowStockCount({String? selectedBranchId}) {
    return getFilteredProductsByStock(
      selectedBranchId: selectedBranchId,
      filterType: 'low_stock',
    ).length;
  }

  /// Đếm số sản phẩm hết hàng (Out of stock)
  /// [selectedBranchId] ID của chi nhánh cần kiểm tra (null = tất cả chi nhánh)
  int getOutOfStockCount({String? selectedBranchId}) {
    return getFilteredProductsByStock(
      selectedBranchId: selectedBranchId,
      filterType: 'out_of_stock',
    ).length;
  }

  /// Cập nhật tồn kho sản phẩm (Quick Adjust)
  /// [productId] ID của sản phẩm
  /// [branchId] ID của chi nhánh
  /// [amount] Số lượng thay đổi (có thể âm hoặc dương)
  /// [type] Loại thay đổi tồn kho (mặc định: adjustment)
  /// [note] Ghi chú cho thay đổi tồn kho
  Future<bool> adjustProductStock(
    String productId,
    String branchId,
    double amount, {
    StockHistoryType type = StockHistoryType.adjustment,
    String note = '',
  }) async {
    if (_productService == null) {
      _errorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      await _productService!.updateProductStock(
        productId,
        branchId,
        amount,
        type: type,
        note: note,
      );
      
      // Reload products để cập nhật UI
      await loadProducts();
      
      return true;
    } catch (e) {
      _errorMessage = 'Lỗi khi điều chỉnh tồn kho: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  // ==================== CATEGORY OPERATIONS ====================

  /// Load danh sách categories
  Future<void> loadCategories() async {
    if (_productService == null) {
      _categoryErrorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return;
    }

    try {
      _isLoadingCategories = true;
      _categoryErrorMessage = null;
      notifyListeners();

      _categories = await _productService!.getCategories();

      _isLoadingCategories = false;
      notifyListeners();
    } catch (e) {
      _isLoadingCategories = false;
      _categoryErrorMessage = 'Lỗi khi tải danh sách nhóm hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider loadCategories error: $_categoryErrorMessage');
      }
      notifyListeners();
    }
  }

  /// Lấy category theo ID
  Future<CategoryModel?> getCategoryById(String id) async {
    if (_productService == null) {
      return null;
    }

    try {
      return await _productService!.getCategoryById(id);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProductProvider getCategoryById error: $e');
      }
      return null;
    }
  }

  /// Thêm category mới
  Future<bool> addCategory(CategoryModel category) async {
    if (_productService == null) {
      _categoryErrorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _isLoadingCategories = true;
      _categoryErrorMessage = null;
      notifyListeners();

      await _productService!.addCategory(category);

      // Reload danh sách
      await loadCategories();

      _isLoadingCategories = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoadingCategories = false;
      _categoryErrorMessage = 'Lỗi khi thêm nhóm hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider addCategory error: $_categoryErrorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Cập nhật category
  Future<bool> updateCategory(CategoryModel category) async {
    if (_productService == null) {
      _categoryErrorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _isLoadingCategories = true;
      _categoryErrorMessage = null;
      notifyListeners();

      await _productService!.updateCategory(category);

      // Cập nhật trong danh sách local
      final index = _categories.indexWhere((c) => c.id == category.id);
      if (index != -1) {
        _categories[index] = category;
      }

      _isLoadingCategories = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoadingCategories = false;
      _categoryErrorMessage = 'Lỗi khi cập nhật nhóm hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider updateCategory error: $_categoryErrorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  /// Xóa category
  Future<bool> deleteCategory(String id) async {
    if (_productService == null) {
      _categoryErrorMessage = 'Chưa đăng nhập';
      notifyListeners();
      return false;
    }

    try {
      _isLoadingCategories = true;
      _categoryErrorMessage = null;
      notifyListeners();

      await _productService!.deleteCategory(id);

      // Xóa khỏi danh sách local
      _categories.removeWhere((c) => c.id == id);

      _isLoadingCategories = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoadingCategories = false;
      _categoryErrorMessage = 'Lỗi khi xóa nhóm hàng: ${e.toString()}';
      if (kDebugMode) {
        debugPrint('ProductProvider deleteCategory error: $_categoryErrorMessage');
      }
      notifyListeners();
      return false;
    }
  }

  // ==================== INVENTORY REPORT ====================

  /// Lấy báo cáo Xuất - Nhập - Tồn
  /// [startDate] Ngày bắt đầu kỳ báo cáo
  /// [endDate] Ngày kết thúc kỳ báo cáo
  /// [branchId] ID chi nhánh (null = tất cả chi nhánh)
  /// Trả về InventoryReport chứa danh sách các sản phẩm với:
  /// - Tồn đầu kỳ (trước startDate)
  /// - Nhập trong kỳ (từ startDate đến endDate)
  /// - Xuất trong kỳ (từ startDate đến endDate)
  /// - Tồn cuối kỳ (tại endDate)
  Future<InventoryReport> getInventoryReport(
    DateTime startDate,
    DateTime endDate, {
    String? branchId,
  }) async {
    if (_productService == null || _stockHistoryService == null) {
      throw Exception('Chưa đăng nhập hoặc service chưa được khởi tạo');
    }

    try {
      // Lấy tất cả sản phẩm
      List<ProductModel> products;
      if (branchId != null && branchId.isNotEmpty) {
        products = await _productService!.getProducts(
          includeInactive: false,
          activeBranchId: branchId,
        );
      } else {
        products = await _productService!.getProducts(includeInactive: false);
      }

      // Tính toán báo cáo cho từng sản phẩm
      List<InventoryReportItem> reportItems = [];

      for (final product in products) {
        // Xác định branchId để truy vấn
        final targetBranchId = branchId ?? (branchProvider?.currentBranchId ?? 'default');

        // Lấy tất cả lịch sử tồn kho của sản phẩm trong chi nhánh
        final allHistory = await _stockHistoryService!.getStockHistoryByProductId(
          product.id,
          branchId: targetBranchId,
        );

        // Tính toán tồn đầu kỳ: Lấy bản ghi cuối cùng trước startDate
        double openingStock = 0.0;
        final historyBeforeStart = allHistory
            .where((h) => h.timestamp.isBefore(startDate))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        if (historyBeforeStart.isNotEmpty) {
          // afterQuantity của bản ghi cuối cùng trước startDate chính là tồn tại thời điểm startDate
          openingStock = historyBeforeStart.first.afterQuantity;
        } else {
          // Nếu không có lịch sử trước startDate, lấy từ product hiện tại (có thể không chính xác)
          // Hoặc tìm bản ghi đầu tiên trong kỳ và lấy beforeQuantity
          final firstHistoryInPeriod = allHistory
              .where((h) => h.timestamp.isAtSameMomentAs(startDate) ||
                  (h.timestamp.isAfter(startDate) && h.timestamp.isBefore(endDate) || h.timestamp.isAtSameMomentAs(endDate)))
              .toList()
            ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          if (firstHistoryInPeriod.isNotEmpty) {
            openingStock = firstHistoryInPeriod.first.beforeQuantity;
          } else {
            // Fallback: Lấy tồn kho hiện tại từ product
            openingStock = product.branchStock[targetBranchId] ?? 0.0;
          }
        }

        // Lấy lịch sử trong kỳ (từ startDate đến endDate)
        final historyInPeriod = allHistory
            .where((h) =>
                (h.timestamp.isAfter(startDate) || h.timestamp.isAtSameMomentAs(startDate)) &&
                (h.timestamp.isBefore(endDate) || h.timestamp.isAtSameMomentAs(endDate)))
            .toList();

        // Tính nhập trong kỳ: Tổng quantityChange > 0
        double incomingStock = historyInPeriod
            .where((h) => h.quantityChange > 0)
            .fold(0.0, (sum, h) => sum + h.quantityChange);

        // Tính xuất trong kỳ: Tổng |quantityChange| với quantityChange < 0
        double outgoingStock = historyInPeriod
            .where((h) => h.quantityChange < 0)
            .fold(0.0, (sum, h) => sum + h.quantityChange.abs());

        // Tính tồn cuối kỳ: Lấy bản ghi cuối cùng có timestamp <= endDate
        double closingStock = openingStock; // Mặc định bằng tồn đầu kỳ
        final historyUpToEnd = allHistory
            .where((h) => h.timestamp.isBefore(endDate) || h.timestamp.isAtSameMomentAs(endDate))
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        if (historyUpToEnd.isNotEmpty) {
          // afterQuantity của bản ghi cuối cùng <= endDate chính là tồn tại thời điểm endDate
          closingStock = historyUpToEnd.first.afterQuantity;
        } else {
          // Nếu không có lịch sử, tính bằng công thức
          closingStock = openingStock + incomingStock - outgoingStock;
        }

        // Chỉ thêm vào báo cáo nếu có lịch sử hoặc có tồn kho
        if (allHistory.isNotEmpty || openingStock > 0 || incomingStock > 0 || outgoingStock > 0) {
          reportItems.add(
            InventoryReportItem(
              product: product,
              branchId: targetBranchId,
              openingStock: openingStock,
              incomingStock: incomingStock,
              outgoingStock: outgoingStock,
              closingStock: closingStock,
            ),
          );
        }
      }

      return InventoryReport(
        startDate: startDate,
        endDate: endDate,
        branchId: branchId,
        items: reportItems,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ProductProvider getInventoryReport error: $e');
      }
      rethrow;
    }
  }

  /// Helper method để gọi notifyListeners() an toàn (kiểm tra disposed)
  void _safeNotifyListeners() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true; // Đánh dấu đã dispose
    authProvider.removeListener(_onAuthChanged);
    authProvider.removeListener(_onSelectedBranchChanged);
    if (branchProvider != null) {
      branchProvider!.removeListener(_onBranchChanged);
    }
    super.dispose();
  }
}

