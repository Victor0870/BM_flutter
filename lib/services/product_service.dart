import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../models/branch_model.dart';
import '../models/stock_history_model.dart';
import 'local_db_service.dart';
import 'stock_history_service.dart';

/// Hybrid Product Service - Quản lý sản phẩm với logic hybrid (Offline-First)
/// - Gói BASIC: Chỉ lưu vào SQLite (Local Database)
/// - Gói PRO: Lưu song song vào cả SQLite và Firestore
///   + SQLite: Dùng khi mất mạng hoặc hết hạn license
///   + Firestore: Đồng bộ đa thiết bị
///   + Khi hết hạn PRO → BASIC: Dữ liệu vẫn còn trong SQLite
class ProductService {
  final bool isPro;
  final String userId;
  final LocalDbService _localDb = LocalDbService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final StockHistoryService _stockHistoryService;

  ProductService({
    required this.isPro,
    required this.userId,
  }) {
    _stockHistoryService = StockHistoryService(isPro: isPro, userId: userId);
  }

  /// Lấy collection reference cho Firestore - Products
  CollectionReference<Map<String, dynamic>> get _productsCollection {
    return _firestore.collection('shops').doc(userId).collection('products');
  }

  /// Lấy collection reference cho Firestore - Categories
  CollectionReference<Map<String, dynamic>> get _categoriesCollection {
    return _firestore.collection('shops').doc(userId).collection('categories');
  }

  /// Lấy collection reference cho Firestore - Branches
  CollectionReference<Map<String, dynamic>> get _branchesCollection {
    return _firestore.collection('shops').doc(userId).collection('branches');
  }

  /// Lấy tất cả sản phẩm
  /// CHỈ ĐỌC TỪ SQLITE để tiết kiệm chi phí Firebase
  /// Để có dữ liệu mới nhất, gọi syncAllFromCloud() trước
  Future<List<ProductModel>> getProducts({
    bool includeInactive = false,
    String? activeBranchId,
  }) async {
    // Trên web, vẫn phải dùng Firestore vì không có SQLite
    if (kIsWeb) {
      return await _getProductsFromFirestore(includeInactive: includeInactive);
    }

    // TẤT CẢ các trường hợp khác: CHỈ đọc từ SQLite
    return await _localDb.getProducts(
      includeInactive: includeInactive,
      activeBranchId: activeBranchId,
    );
  }

  /// Đồng bộ danh sách sản phẩm vào SQLite (dự phòng). Public để ProductProvider gọi khi nhận dữ liệu real-time.
  Future<void> syncProductsToLocal(List<ProductModel> products) async {
    if (kIsWeb) return;
    try {
      for (final product in products) {
        await _localDb.addProduct(product);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error syncing products to local: $e');
      }
    }
  }

  /// Nội bộ: đồng bộ vào SQLite (gọi từ syncProductsToLocal và các chỗ khác trong service).
  Future<void> _syncProductsToLocal(List<ProductModel> products) async {
    return syncProductsToLocal(products);
  }

  /// Lấy sản phẩm từ Firestore (một lần) — dùng cho light sync PRO.
  /// Trả về danh sách từ Cloud; không ghi SQLite (caller gọi syncProductsToLocal nếu cần).
  Future<List<ProductModel>> fetchProductsFromCloud({
    bool includeInactive = false,
  }) async {
    if (!isPro && !kIsWeb) return [];
    return _getProductsFromFirestore(includeInactive: includeInactive);
  }

  /// Lấy sản phẩm từ Firestore
  Future<List<ProductModel>> _getProductsFromFirestore({
    bool includeInactive = false,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _productsCollection.orderBy('name');

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.get();
      final products = snapshot.docs
          .map((doc) => ProductModel.fromFirestore(doc.data(), doc.id))
          .toList();
      
      // Lọc chỉ sản phẩm có thể bán (isSellable = true) khi lấy từ Firestore
      // Note: UI sẽ filter lại nên không cần filter ở đây nếu muốn linh hoạt hơn
      return products;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting products from Firestore: $e');
      }
      rethrow;
    }
  }

  /// Lấy sản phẩm theo ID
  /// PRO: Ưu tiên Firestore, nếu lỗi thì fallback SQLite (không phải web)
  /// BASIC: Chỉ lấy từ SQLite (không phải web)
  /// Web: Chỉ lấy từ Firestore
  Future<ProductModel?> getProductById(String id) async {
    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _getProductByIdFromFirestore(id);
    }

    if (isPro) {
      try {
        final product = await _getProductByIdFromFirestore(id);
        if (product != null && !kIsWeb) {
          // Đồng bộ vào SQLite (chỉ khi không phải web)
          await _localDb.addProduct(product);
        }
        return product;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Firestore error, falling back to SQLite: $e');
        }
        if (!kIsWeb) {
          return await _localDb.getProductById(id);
        }
        rethrow; // Trên web, throw lại lỗi
      }
    } else {
      return await _localDb.getProductById(id);
    }
  }

  /// Lấy sản phẩm từ Firestore theo ID
  Future<ProductModel?> _getProductByIdFromFirestore(String id) async {
    try {
      final doc = await _productsCollection.doc(id).get();
      if (doc.exists && doc.data() != null) {
        return ProductModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting product from Firestore: $e');
      }
      rethrow;
    }
  }

  /// Tìm kiếm sản phẩm
  /// CHỈ ĐỌC TỪ SQLITE để tiết kiệm chi phí Firebase
  /// Để có dữ liệu mới nhất, gọi syncAllFromCloud() trước
  Future<List<ProductModel>> searchProducts(
    String query, {
    String? activeBranchId,
  }) async {
    // Trên web, vẫn phải dùng Firestore vì không có SQLite
    if (kIsWeb) {
      return await _searchProductsFromFirestore(query);
    }

    // TẤT CẢ các trường hợp khác: CHỈ đọc từ SQLite
    return await _localDb.searchProducts(
      query,
      activeBranchId: activeBranchId,
    );
  }

  /// Tìm kiếm sản phẩm trong Firestore
  Future<List<ProductModel>> _searchProductsFromFirestore(String query) async {
    try {
      // Firestore không hỗ trợ full-text search tốt, nên ta sẽ lấy tất cả rồi filter
      // Hoặc có thể dùng Algolia, Elasticsearch cho production
      final snapshot = await _productsCollection
          .where('isActive', isEqualTo: true)
          .orderBy('name')
          .get();

      final queryLower = query.toLowerCase();
      return snapshot.docs
          .where((doc) {
            final data = doc.data();
            final name = (data['name'] ?? '').toString().toLowerCase();
            final barcode = (data['barcode'] ?? '').toString().toLowerCase();
            return name.contains(queryLower) || barcode.contains(queryLower);
          })
          .map((doc) => ProductModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error searching products in Firestore: $e');
      }
      rethrow;
    }
  }

  /// Thêm sản phẩm mới
  /// CHIẾN LƯỢC: Cập nhật SQLite trước, sau đó push lên Firestore (Write once)
  /// PRO: Lưu vào SQLite trước, sau đó push lên Firestore
  /// BASIC: Chỉ lưu vào SQLite
  /// Web: Chỉ lưu vào Firestore
  Future<String> addProduct(ProductModel product) async {
    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _addProductToFirestore(product);
    }

    // TẤT CẢ: Luôn cập nhật SQLite trước (offline-first)
    await _localDb.addProduct(product);
    
    // PRO: Sau đó push lên Firestore (write once)
    if (isPro) {
      try {
        await _addProductToFirestore(product);
        if (kDebugMode) {
          debugPrint('✅ Product added to SQLite and Firestore: ${product.id}');
        }
      } catch (e) {
        // Nếu Firestore lỗi, vẫn giữ trong SQLite
        if (kDebugMode) {
          debugPrint('⚠️ Error adding to Firestore, kept in SQLite: $e');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Product added to SQLite only (BASIC package): ${product.id}');
      }
    }

    return product.id;
  }

  /// Thêm sản phẩm vào Firestore
  Future<String> _addProductToFirestore(ProductModel product) async {
    try {
      final docRef = _productsCollection.doc(product.id);
      await docRef.set(product.toFirestore());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding product to Firestore: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật sản phẩm
  /// CHIẾN LƯỢC: Cập nhật SQLite trước, sau đó push lên Firestore (Write once)
  /// PRO: Cập nhật SQLite trước, sau đó push lên Firestore
  /// BASIC: Chỉ cập nhật SQLite
  /// Web: Chỉ cập nhật Firestore
  Future<int> updateProduct(ProductModel product) async {
    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _updateProductInFirestore(product);
    }

    // TẤT CẢ: Luôn cập nhật SQLite trước (offline-first)
    await _localDb.updateProduct(product);
    
    // PRO: Sau đó push lên Firestore (write once)
    if (isPro) {
      try {
        await _updateProductInFirestore(product);
        if (kDebugMode) {
          debugPrint('✅ Product updated in SQLite and Firestore: ${product.id}');
        }
        return 1;
      } catch (e) {
        // Nếu Firestore lỗi, vẫn giữ trong SQLite
        if (kDebugMode) {
          debugPrint('⚠️ Error updating Firestore, kept in SQLite: $e');
        }
        return 1;
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Product updated in SQLite only (BASIC package): ${product.id}');
      }
      return 1;
    }
  }

  /// Cập nhật sản phẩm trong Firestore
  Future<int> _updateProductInFirestore(ProductModel product) async {
    try {
      if (kDebugMode) {
        debugPrint('☁️ Updating product in Firestore: ${product.id}, new stock: ${product.stock}');
      }
      
      await _productsCollection.doc(product.id).update(product.toFirestore());
      
      if (kDebugMode) {
        debugPrint('✅ Product updated in Firestore successfully');
      }
      
      return 1; // Firestore không trả về số lượng rows affected
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating product in Firestore: $e');
        debugPrint('Product ID: ${product.id}, Stock: ${product.stock}');
      }
      rethrow;
    }
  }

  /// Cập nhật tồn kho sản phẩm theo chi nhánh
  /// Sử dụng FieldValue.increment để đảm bảo tính toàn vẹn dữ liệu khi có nhiều giao dịch cùng lúc
  /// [quantityChange] có thể là số dương (nhập hàng) hoặc số âm (bán hàng)
  /// [type] loại thay đổi tồn kho (mặc định: adjustment)
  /// [note] ghi chú cho thay đổi tồn kho
  /// PRO: Cập nhật cả SQLite và Firestore
  /// BASIC: Chỉ cập nhật SQLite
  /// Web: Chỉ cập nhật Firestore
  /// Tự động tạo bản ghi StockHistoryModel để lưu vết
  Future<void> updateProductStock(
    String productId,
    String branchId,
    double quantityChange, {
    StockHistoryType type = StockHistoryType.adjustment,
    String note = '',
  }) async {
    if (kDebugMode) {
      debugPrint('📦 Updating product stock: productId=$productId, branchId=$branchId, quantityChange=$quantityChange, type=${type.value}');
    }

    double beforeQuantity = 0.0;
    double afterQuantity = 0.0;

    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      // Lấy sản phẩm hiện tại từ Firestore để lấy beforeQuantity
      final product = await getProductById(productId);
      if (product != null) {
        beforeQuantity = product.branchStock[branchId] ?? 0.0;
        afterQuantity = beforeQuantity + quantityChange;
        
        if (afterQuantity < 0) {
          throw Exception('Tồn kho không đủ. Tồn kho hiện tại: $beforeQuantity, cần trừ: ${-quantityChange}');
        }
      }
      
      await _updateProductStockInFirestore(productId, branchId, quantityChange);
      
      // Tạo bản ghi StockHistoryModel
      if (product != null) {
        await _createStockHistory(
          productId: productId,
          branchId: branchId,
          type: type,
          quantityChange: quantityChange,
          beforeQuantity: beforeQuantity,
          afterQuantity: afterQuantity,
          note: note,
        );
      }
      return;
    }

    // TẤT CẢ: Cập nhật SQLite trước (offline-first)
    try {
      // Lấy sản phẩm hiện tại từ SQLite
      final product = await _localDb.getProductById(productId);
      if (product != null) {
        // Lưu số lượng trước khi thay đổi
        beforeQuantity = product.branchStock[branchId] ?? 0.0;
        
        // Cập nhật branchStock trong memory
        final updatedBranchStock = Map<String, double>.from(product.branchStock);
        final newStock = beforeQuantity + quantityChange;
        
        // Đảm bảo không âm
        if (newStock < 0) {
          throw Exception('Tồn kho không đủ. Tồn kho hiện tại: $beforeQuantity, cần trừ: ${-quantityChange}');
        }
        
        afterQuantity = newStock;
        updatedBranchStock[branchId] = afterQuantity;
        
        // Cập nhật sản phẩm trong SQLite
        final updatedProduct = product.copyWith(branchStock: updatedBranchStock);
        await _localDb.updateProduct(updatedProduct);
        
        if (kDebugMode) {
          debugPrint('✅ Product stock updated in SQLite: $productId, branchId=$branchId, newStock=$afterQuantity');
        }

        // Tạo bản ghi StockHistoryModel
        await _createStockHistory(
          productId: productId,
          branchId: branchId,
          type: type,
          quantityChange: quantityChange,
          beforeQuantity: beforeQuantity,
          afterQuantity: afterQuantity,
          note: note,
        );
      } else {
        throw Exception('Không tìm thấy sản phẩm với ID: $productId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating product stock in SQLite: $e');
      }
      rethrow;
    }

    // PRO: Sau đó cập nhật Firestore sử dụng FieldValue.increment
    if (isPro) {
      try {
        await _updateProductStockInFirestore(productId, branchId, quantityChange);
        if (kDebugMode) {
          debugPrint('✅ Product stock updated in Firestore: $productId, branchId=$branchId');
        }
      } catch (e) {
        // Nếu Firestore lỗi, vẫn giữ trong SQLite
        if (kDebugMode) {
          debugPrint('⚠️ Error updating Firestore, kept in SQLite: $e');
        }
        // Không throw, vì đã cập nhật SQLite thành công
      }
    }
  }

  /// Tạo bản ghi StockHistoryModel
  Future<void> _createStockHistory({
    required String productId,
    required String branchId,
    required StockHistoryType type,
    required double quantityChange,
    required double beforeQuantity,
    required double afterQuantity,
    required String note,
  }) async {
    try {
      final history = StockHistoryModel(
        id: '${DateTime.now().millisecondsSinceEpoch}_${productId}_$branchId',
        productId: productId,
        branchId: branchId,
        type: type,
        quantityChange: quantityChange,
        beforeQuantity: beforeQuantity,
        afterQuantity: afterQuantity,
        note: note,
        timestamp: DateTime.now(),
      );

      await _stockHistoryService.addStockHistory(history);
      
      if (kDebugMode) {
        debugPrint('✅ Stock history created: ${history.id}, type=${type.value}, change=$quantityChange');
      }
    } catch (e) {
      // Không throw lỗi, chỉ log để không ảnh hưởng đến quá trình cập nhật tồn kho
      if (kDebugMode) {
        debugPrint('⚠️ Error creating stock history: $e');
      }
    }
  }

  /// Cập nhật tồn kho sản phẩm trong Firestore sử dụng FieldValue.increment
  Future<void> _updateProductStockInFirestore(
    String productId,
    String branchId,
    double quantityChange,
  ) async {
    try {
      final docRef = _productsCollection.doc(productId);
      
      // FieldValue.increment: tránh race condition khi nhiều thiết bị cập nhật cùng lúc.
      // FieldValue.serverTimestamp(): thiết bị khác đang listen sẽ nhận snapshot mới ngay, tránh xung đột dữ liệu cũ.
      await docRef.update({
        'branchStock.$branchId': FieldValue.increment(quantityChange),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      if (kDebugMode) {
        debugPrint('✅ Product stock incremented in Firestore: $productId, branchId=$branchId, change=$quantityChange');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating product stock in Firestore: $e');
        debugPrint('Product ID: $productId, Branch ID: $branchId, Quantity Change: $quantityChange');
      }
      rethrow;
    }
  }

  /// Xóa sản phẩm (soft delete)
  /// PRO: Xóa song song trong cả SQLite và Firestore
  /// BASIC: Chỉ xóa trong SQLite
  /// Web: Chỉ xóa trong Firestore
  Future<int> deleteProduct(String id) async {
    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _deleteProductFromFirestore(id);
    }

    if (isPro) {
      // PRO: Xóa trong SQLite trước (offline-first)
      await _localDb.deleteProduct(id);
      
      try {
        // Sau đó xóa trong Firestore
        return await _deleteProductFromFirestore(id);
      } catch (e) {
        // Nếu Firestore lỗi, vẫn giữ trong SQLite
        if (kDebugMode) {
          debugPrint('Error deleting from Firestore, kept in SQLite: $e');
        }
        return 1;
      }
    } else {
      // BASIC: Chỉ xóa trong SQLite
      return await _localDb.deleteProduct(id);
    }
  }

  /// Xóa sản phẩm từ Firestore (soft delete)
  Future<int> _deleteProductFromFirestore(String id) async {
    try {
      await _productsCollection.doc(id).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return 1;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting product from Firestore: $e');
      }
      rethrow;
    }
  }

  /// Xóa vĩnh viễn sản phẩm
  /// PRO: Xóa song song trong cả SQLite và Firestore
  /// BASIC: Chỉ xóa trong SQLite
  /// Web: Chỉ xóa trong Firestore
  Future<int> deleteProductPermanently(String id) async {
    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _deleteProductPermanentlyFromFirestore(id);
    }

    if (isPro) {
      // PRO: Xóa trong SQLite trước (offline-first)
      await _localDb.deleteProductPermanently(id);
      
      try {
        // Sau đó xóa trong Firestore
        return await _deleteProductPermanentlyFromFirestore(id);
      } catch (e) {
        // Nếu Firestore lỗi, vẫn giữ trong SQLite
        if (kDebugMode) {
          debugPrint('Error permanently deleting from Firestore, kept in SQLite: $e');
        }
        return 1;
      }
    } else {
      // BASIC: Chỉ xóa trong SQLite
      return await _localDb.deleteProductPermanently(id);
    }
  }

  /// Xóa vĩnh viễn sản phẩm từ Firestore
  Future<int> _deleteProductPermanentlyFromFirestore(String id) async {
    try {
      await _productsCollection.doc(id).delete();
      return 1;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error permanently deleting product from Firestore: $e');
      }
      rethrow;
    }
  }

  /// Lấy số lượng sản phẩm
  /// Web: Chỉ dùng Firestore
  Future<int> getProductCount({bool includeInactive = false}) async {
    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _getProductCountFromFirestore(includeInactive: includeInactive);
    }

    if (isPro) {
      return await _getProductCountFromFirestore(includeInactive: includeInactive);
    } else {
      return await _localDb.getProductCount(includeInactive: includeInactive);
    }
  }

  /// Lấy số lượng sản phẩm từ Firestore
  Future<int> _getProductCountFromFirestore({bool includeInactive = false}) async {
    try {
      Query<Map<String, dynamic>> query = _productsCollection;

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting product count from Firestore: $e');
      }
      return 0;
    }
  }

  /// Đồng bộ toàn bộ dữ liệu từ Firestore về SQLite (1 lần duy nhất)
  /// Hàm này được gọi khi khởi tạo ứng dụng hoặc khi người dùng nhấn 'Đồng bộ'
  /// TIẾT KIỆM CHI PHÍ: Chỉ đọc Firestore 1 lần, sau đó tất cả operations chỉ dùng SQLite
  Future<void> syncAllFromCloud() async {
    // Không sync trên web (web không có SQLite)
    if (kIsWeb) {
      if (kDebugMode) {
        debugPrint('⚠️ syncAllFromCloud: Skipping on web platform');
      }
      return;
    }

    // Chỉ sync nếu là PRO hoặc đã đăng nhập
    if (!isPro) {
      if (kDebugMode) {
        debugPrint('⚠️ syncAllFromCloud: Skipping for BASIC package');
      }
      return;
    }

    try {
      if (kDebugMode) {
        debugPrint('🔄 Starting sync all data from Firestore to SQLite...');
      }

      // 1. Sync Products
      try {
        final products = await _getProductsFromFirestore(includeInactive: true);
        await _syncProductsToLocal(products);
        if (kDebugMode) {
          debugPrint('✅ Synced ${products.length} products to SQLite');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error syncing products: $e');
        }
      }

      // 2. Sync Categories
      try {
        final categories = await getCategories();
        // Categories được lưu trong Firestore, không cần sync vào SQLite
        // Vì categories chỉ được quản lý trên Firestore (PRO feature)
        if (kDebugMode) {
          debugPrint('✅ Synced ${categories.length} categories (stored in Firestore)');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error syncing categories: $e');
        }
      }

      // 3. Sync Branches
      try {
        final branchesSnapshot = await _branchesCollection
            .where('isActive', isEqualTo: true)
            .get();
        
        final branches = branchesSnapshot.docs.map((doc) {
          final data = doc.data();
          return BranchModel(
            id: doc.id,
            name: data['name'] ?? '',
            address: data['address'],
            phone: data['phone'],
            isActive: data['isActive'] ?? true,
          );
        }).toList();

        for (final branch in branches) {
          await _localDb.addBranch(branch);
        }
        
        if (kDebugMode) {
          debugPrint('✅ Synced ${branches.length} branches to SQLite');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('❌ Error syncing branches: $e');
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Sync completed successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error during syncAllFromCloud: $e');
      }
      rethrow;
    }
  }

  /// Đồng bộ hóa: Migrate dữ liệu từ Local DB lên Firestore
  /// Hàm này được gọi khi user nâng cấp từ BASIC lên PRO
  Future<void> migrateLocalToCloud() async {
    try {
      if (kDebugMode) {
        debugPrint('Starting migration from Local DB to Firestore...');
      }

      // 1. Đọc toàn bộ sản phẩm từ Local DB
      final localProducts = await _localDb.getProducts(includeInactive: true);
      
      if (kDebugMode) {
        debugPrint('Found ${localProducts.length} products to migrate');
      }

      if (localProducts.isEmpty) {
        if (kDebugMode) {
          debugPrint('No products to migrate');
        }
        return;
      }

      // 2. Upload tất cả lên Firestore
      final batch = _firestore.batch();
      int successCount = 0;
      int errorCount = 0;

      for (final product in localProducts) {
        try {
          final docRef = _productsCollection.doc(product.id);
          batch.set(docRef, product.toFirestore());
          successCount++;
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error adding product ${product.id} to batch: $e');
          }
          errorCount++;
        }
      }

      // Commit batch
      await batch.commit();

      if (kDebugMode) {
        debugPrint('Migration completed: $successCount success, $errorCount errors');
      }

      // 3. KHÔNG xóa dữ liệu cục bộ - giữ lại làm backup
      // Khi user hết hạn PRO, họ vẫn có dữ liệu trong SQLite
      if (kDebugMode) {
        debugPrint('Local database kept as backup for offline access');
      }

      if (kDebugMode) {
        debugPrint('Local database cleared after successful migration');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error during migration: $e');
      }
      rethrow;
    }
  }

  /// Lắng nghe thay đổi real-time từ Firestore (chỉ cho PRO)
  Stream<List<ProductModel>>? watchProducts({bool includeInactive = false}) {
    if (!isPro) {
      // Local DB không hỗ trợ stream, trả về null
      return null;
    }

    try {
      Query<Map<String, dynamic>> query = _productsCollection.orderBy('name');

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      return query.snapshots().map((snapshot) {
        return snapshot.docs
            .map((doc) => ProductModel.fromFirestore(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error watching products from Firestore: $e');
      }
      return null;
    }
  }

  // ==================== CATEGORY CRUD OPERATIONS ====================

  /// Lấy tất cả categories
  /// PRO: Lấy từ Firestore
  /// BASIC: Trả về danh sách rỗng (Category chỉ có trên Firestore)
  /// Web: Lấy từ Firestore
  Future<List<CategoryModel>> getCategories() async {
    if (!isPro && !kIsWeb) {
      // BASIC: Category chỉ có trên Firestore
      return [];
    }

    try {
      final snapshot = await _categoriesCollection
          .orderBy('name')
          .get();
      
      return snapshot.docs
          .map((doc) => CategoryModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting categories from Firestore: $e');
      }
      return [];
    }
  }

  /// Lấy category theo ID
  Future<CategoryModel?> getCategoryById(String id) async {
    if (!isPro && !kIsWeb) {
      return null;
    }

    try {
      final doc = await _categoriesCollection.doc(id).get();
      if (doc.exists && doc.data() != null) {
        return CategoryModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting category from Firestore: $e');
      }
      return null;
    }
  }

  /// Thêm category mới
  /// PRO: Lưu vào Firestore
  /// BASIC: Trả về lỗi (Category chỉ có trên Firestore)
  /// Web: Lưu vào Firestore
  Future<String> addCategory(CategoryModel category) async {
    if (!isPro && !kIsWeb) {
      throw Exception('Category chỉ khả dụng cho gói PRO');
    }

    try {
      final docRef = _categoriesCollection.doc(category.id);
      await docRef.set(category.toFirestore());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding category to Firestore: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật category
  /// PRO: Cập nhật trong Firestore
  /// BASIC: Trả về lỗi (Category chỉ có trên Firestore)
  /// Web: Cập nhật trong Firestore
  Future<void> updateCategory(CategoryModel category) async {
    if (!isPro && !kIsWeb) {
      throw Exception('Category chỉ khả dụng cho gói PRO');
    }

    try {
      await _categoriesCollection
          .doc(category.id)
          .update(category.toFirestore());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating category in Firestore: $e');
      }
      rethrow;
    }
  }

  /// Xóa category
  /// PRO: Xóa trong Firestore
  /// BASIC: Trả về lỗi (Category chỉ có trên Firestore)
  /// Web: Xóa trong Firestore
  Future<void> deleteCategory(String id) async {
    if (!isPro && !kIsWeb) {
      throw Exception('Category chỉ khả dụng cho gói PRO');
    }

    try {
      await _categoriesCollection.doc(id).delete();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting category from Firestore: $e');
      }
      rethrow;
    }
  }

  /// Lắng nghe thay đổi real-time từ Firestore (chỉ cho PRO)
  Stream<List<CategoryModel>>? watchCategories() {
    if (!isPro) {
      return null;
    }

    try {
      return _categoriesCollection
          .orderBy('name')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs
            .map((doc) => CategoryModel.fromFirestore(doc.data(), doc.id))
            .toList();
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error watching categories from Firestore: $e');
      }
      return null;
    }
  }
}

