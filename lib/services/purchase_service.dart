import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../models/purchase_model.dart';
import '../models/branch_model.dart';
import 'local_db_service.dart';
import 'product_service.dart';
import 'notification_service.dart';

/// Hybrid Purchase Service - Quản lý phiếu nhập kho với logic hybrid (Offline-First)
/// - Gói BASIC: Chỉ lưu vào SQLite
/// - Gói PRO: Lưu song song vào cả SQLite và Firestore
/// - Khi phiếu nhập được xác nhận (COMPLETED), tự động cập nhật stock và importPrice
class PurchaseService {
  final bool isPro;
  final String userId;
  final LocalDbService _localDb = LocalDbService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProductService _productService;

  PurchaseService({
    required this.isPro,
    required this.userId,
    required ProductService productService,
  }) : _productService = productService;

  /// Lấy collection reference cho Firestore
  CollectionReference<Map<String, dynamic>> get _purchasesCollection {
    return _firestore.collection('shops').doc(userId).collection('purchases');
  }

  /// Lưu phiếu nhập và cập nhật stock nếu status = COMPLETED
  /// PRO: Lưu song song SQLite + Firestore
  /// BASIC: Chỉ lưu SQLite
  Future<String> savePurchase(PurchaseModel purchase) async {
    try {
      if (kDebugMode) {
        debugPrint('📦 Starting savePurchase with ${purchase.items.length} items, status: ${purchase.status}');
      }

      // 1. Nếu status là COMPLETED, cập nhật stock và importPrice cho sản phẩm
      if (purchase.status == 'COMPLETED') {
        if (kDebugMode) {
          debugPrint('📦 Step 1: Updating product stocks and import prices...');
        }
        await _updateProductStocksAndPrices(purchase.items, purchase);
        if (kDebugMode) {
          debugPrint('✅ Step 1 completed: All stocks and prices updated');
        }
      }

      // 2. Lưu phiếu nhập
      if (kDebugMode) {
        debugPrint('💾 Step 2: Saving purchase to storage...');
      }

      // Trên web, chỉ dùng Firestore
      if (kIsWeb) {
        if (kDebugMode) {
          debugPrint('🌐 Web mode: Saving to Firestore only');
        }
        await _addPurchaseToFirestore(purchase);
      } else if (isPro) {
        // PRO: Lưu vào SQLite trước (offline-first)
        if (kDebugMode) {
          debugPrint('💾 PRO mode: Saving to SQLite first');
        }
        await _localDb.addPurchase(purchase);

        try {
          // Sau đó lưu vào Firestore
          if (kDebugMode) {
            debugPrint('☁️ PRO mode: Saving to Firestore');
          }
          await _addPurchaseToFirestore(purchase);
        } catch (e) {
          // Nếu Firestore lỗi, vẫn giữ trong SQLite
          if (kDebugMode) {
            debugPrint('⚠️ Error saving purchase to Firestore, kept in SQLite: $e');
          }
        }
      } else {
        // BASIC: Chỉ lưu vào SQLite
        if (kDebugMode) {
          debugPrint('💾 BASIC mode: Saving to SQLite only');
        }
        await _localDb.addPurchase(purchase);
      }

      if (kDebugMode) {
        debugPrint('✅ Purchase saved successfully: ${purchase.id}');
      }

      // 3. Thông báo phiếu nhập kho hoàn thành
      if (purchase.status == 'COMPLETED') {
        try {
          await NotificationService.notifyPurchaseCompleted(
            shopId: userId,
            purchaseId: purchase.id,
            supplierName: purchase.supplierName,
            totalAmount: purchase.totalAmount,
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Notification create failed (purchase completed): $e');
          }
        }
      }

      return purchase.id;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error saving purchase: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// Cập nhật stock và importPrice cho sản phẩm khi nhập kho
  /// Cộng dồn số lượng vào stock hiện tại
  Future<void> _updateProductStocksAndPrices(List<PurchaseItem> items, PurchaseModel purchase) async {
    for (final item in items) {
      try {
        // Lấy sản phẩm hiện tại
        final product = await _productService.getProductById(item.productId);
        if (product == null) {
          if (kDebugMode) {
            debugPrint('⚠️ Product not found: ${item.productId}');
          }
          continue;
        }

        // Cộng dồn số lượng nhập vào stock hiện tại cho branch từ purchase.branchId
        // Nếu branchId rỗng, sử dụng chi nhánh mặc định
        final branchId = purchase.branchId.isEmpty ? kMainStoreBranchId : purchase.branchId;
        // Lấy stock hiện tại của chi nhánh (mặc định 0 nếu chưa có)
        final currentBranchStock = product.branchStock[branchId] ?? 0.0;
        
        if (kDebugMode) {
          debugPrint('📦 Updating product: ${product.name}');
          debugPrint('  Current branch stock: $currentBranchStock');
          debugPrint('  Adding quantity: ${item.quantity}, New importPrice: ${item.importPrice}');
          debugPrint('  New stock will be: ${currentBranchStock + item.quantity}');
        }

        // Sử dụng updateProductStock với số dương để cộng kho (atomic operation)
        await _productService.updateProductStock(
          item.productId,
          branchId,
          item.quantity, // Số dương để cộng kho
        );

        // Cập nhật importPrice riêng (nếu cần)
        if (item.importPrice != product.importPrice) {
          final updatedProduct = product.copyWith(
            importPrice: item.importPrice, // Cập nhật giá nhập mới nhất
          );
          await _productService.updateProduct(updatedProduct);
        }

        if (kDebugMode) {
          debugPrint('✅ Stock and importPrice updated successfully for ${product.name}');
        }
      } catch (e, stackTrace) {
        if (kDebugMode) {
          debugPrint('❌ Error updating stock for product ${item.productId}: $e');
          debugPrint('Stack trace: $stackTrace');
        }
        // Throw lại để báo lỗi, không continue
        rethrow;
      }
    }
  }

  /// Thêm phiếu nhập vào Firestore
  Future<void> _addPurchaseToFirestore(PurchaseModel purchase) async {
    try {
      await _purchasesCollection.doc(purchase.id).set(purchase.toFirestore());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding purchase to Firestore: $e');
      }
      rethrow;
    }
  }

  /// Lấy danh sách phiếu nhập
  /// PRO: Ưu tiên Firestore, nếu lỗi thì fallback SQLite
  /// BASIC: Chỉ lấy từ SQLite
  /// Web: Chỉ lấy từ Firestore
  Future<List<PurchaseModel>> getPurchases({
    DateTime? startDate,
    DateTime? endDate,
    String? branchId, // Lọc theo chi nhánh
  }) async {
    // Helper function để filter theo date và branchId nếu cần
    List<PurchaseModel> filterPurchases(List<PurchaseModel> purchases, DateTime? start, DateTime? end, String? branchId) {
      return purchases.where((purchase) {
        // Filter theo date
        if (start != null && purchase.timestamp.isBefore(start)) return false;
        if (end != null && purchase.timestamp.isAfter(end)) return false;
        // Filter theo branchId
        if (branchId != null && branchId.isNotEmpty && purchase.branchId != branchId) return false;
        return true;
      }).toList();
    }

    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      try {
        Query<Map<String, dynamic>> query = _purchasesCollection.orderBy('timestamp', descending: true);

        if (startDate != null) {
          query = query.where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
        }
        if (endDate != null) {
          query = query.where('timestamp',
              isLessThanOrEqualTo: Timestamp.fromDate(endDate));
        }
        // Lọc theo branchId nếu có
        if (branchId != null && branchId.isNotEmpty) {
          query = query.where('branchId', isEqualTo: branchId);
        }

        final snapshot = await query.get();
        return snapshot.docs
            .map((doc) => PurchaseModel.fromFirestore(doc.data(), doc.id))
            .toList();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Firestore query with date filter failed, trying without filter: $e');
        }
        // Fallback: Lấy tất cả rồi filter local
        try {
          final snapshot = await _purchasesCollection.orderBy('timestamp', descending: true).get();
          final allPurchases = snapshot.docs
              .map((doc) => PurchaseModel.fromFirestore(doc.data(), doc.id))
              .toList();
          return filterPurchases(allPurchases, startDate, endDate, branchId);
        } catch (e2) {
          if (kDebugMode) {
            debugPrint('❌ Error getting purchases from Firestore: $e2');
          }
          rethrow;
        }
      }
    }

    if (isPro) {
      try {
        // PRO: Ưu tiên Firestore
        final purchases = await _getPurchasesFromFirestore(startDate, endDate, branchId);
        return purchases;
      } catch (e) {
        // Nếu Firestore lỗi, fallback về SQLite
        if (kDebugMode) {
          debugPrint('Firestore error, falling back to SQLite: $e');
        }
        final purchases = await _localDb.getPurchases(
          userId: userId,
          startDate: startDate,
          endDate: endDate,
        );
        return filterPurchases(purchases, startDate, endDate, branchId);
      }
    } else {
      // BASIC: Chỉ lấy từ SQLite
      final purchases = await _localDb.getPurchases(
        userId: userId,
        startDate: startDate,
        endDate: endDate,
      );
      return filterPurchases(purchases, startDate, endDate, branchId);
    }
  }

  /// Lấy phiếu nhập từ Firestore
  Future<List<PurchaseModel>> _getPurchasesFromFirestore(
    DateTime? startDate,
    DateTime? endDate,
    String? branchId,
  ) async {
    try {
      Query<Map<String, dynamic>> query = _purchasesCollection.orderBy('timestamp', descending: true);

      if (startDate != null) {
        query = query.where('timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('timestamp',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }
      // Lọc theo branchId nếu có
      if (branchId != null && branchId.isNotEmpty) {
        query = query.where('branchId', isEqualTo: branchId);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => PurchaseModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Firestore query with date filter failed, trying without filter: $e');
      }
      // Fallback: Lấy tất cả rồi filter local
      final snapshot = await _purchasesCollection.orderBy('timestamp', descending: true).get();
      final allPurchases = snapshot.docs
          .map((doc) => PurchaseModel.fromFirestore(doc.data(), doc.id))
          .toList();
      
      return allPurchases.where((purchase) {
        if (startDate != null && purchase.timestamp.isBefore(startDate)) return false;
        if (endDate != null && purchase.timestamp.isAfter(endDate)) return false;
        return true;
      }).toList();
    }
  }

  /// Lấy phiếu nhập theo ID
  Future<PurchaseModel?> getPurchaseById(String id) async {
    if (kIsWeb) {
      try {
        final doc = await _purchasesCollection.doc(id).get();
        if (!doc.exists) return null;
        return PurchaseModel.fromFirestore(doc.data()!, doc.id);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error getting purchase from Firestore: $e');
        }
        return null;
      }
    }

    if (isPro) {
      try {
        final doc = await _purchasesCollection.doc(id).get();
        if (!doc.exists) {
          // Fallback về SQLite
          return await _localDb.getPurchaseById(id);
        }
        return PurchaseModel.fromFirestore(doc.data()!, doc.id);
      } catch (e) {
        // Fallback về SQLite
        return await _localDb.getPurchaseById(id);
      }
    } else {
      return await _localDb.getPurchaseById(id);
    }
  }
}

