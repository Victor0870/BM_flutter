import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../models/sales_return_model.dart';
import '../models/sale_model.dart';
import '../models/stock_history_model.dart';
import 'local_db_service.dart';
import 'product_service.dart';
import 'customer_service.dart';

/// Hybrid Sales Return Service - Quản lý hóa đơn hàng trả với logic hybrid (Offline-First)
/// - Gói BASIC: Chỉ lưu vào SQLite
/// - Gói PRO: Lưu song song vào cả SQLite và Firestore
/// - Khi lưu đơn trả hàng, tự động cập nhật stock (cộng lại vào kho) và công nợ (nếu cần)
class SalesReturnService {
  final bool isPro;
  final String userId;
  final LocalDbService _localDb = LocalDbService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProductService? _productService;

  SalesReturnService({
    required this.isPro,
    required this.userId,
    ProductService? productService,
  }) : _productService = productService;

  /// Lấy collection reference cho Firestore
  CollectionReference<Map<String, dynamic>> get _salesReturnsCollection {
    return _firestore.collection('shops').doc(userId).collection('sales_returns');
  }

  /// Lưu hóa đơn hàng trả và cập nhật stock + công nợ
  /// PRO: Lưu song song SQLite + Firestore, cập nhật stock cả 2
  /// BASIC: Chỉ lưu SQLite, cập nhật stock SQLite
  /// Nếu đơn trả hàng có paymentMethod = 'DEBT', sẽ giảm totalDebt của khách hàng
  Future<String> saveSalesReturn(
    SalesReturnModel salesReturn, {
    CustomerService? customerService,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Starting saveSalesReturn with ${salesReturn.items.length} items, total refund: ${salesReturn.totalRefundAmount}');
      }

      // 1. Cập nhật stock cho tất cả sản phẩm trong đơn trả hàng TRƯỚC
      // Quan trọng: Phải cập nhật stock trước khi lưu sales return
      // Cộng lại số lượng vào kho (quantityChange là số dương)
      if (kDebugMode) {
        debugPrint('📦 Step 1: Updating product stocks (adding back to inventory)...');
      }
      await _updateProductStocks(salesReturn.items, salesReturn);

      if (kDebugMode) {
        debugPrint('✅ Step 1 completed: All stocks updated (items returned to inventory)');
      }

      // 2. Lưu hóa đơn trả hàng
      if (kDebugMode) {
        debugPrint('💾 Step 2: Saving sales return to storage...');
      }

      // Trên web, chỉ dùng Firestore
      if (kIsWeb) {
        if (kDebugMode) {
          debugPrint('🌐 Web mode: Saving to Firestore only');
        }
        await _addSalesReturnToFirestore(salesReturn);
      } else if (isPro) {
        // PRO: Lưu vào SQLite trước (offline-first)
        if (kDebugMode) {
          debugPrint('💾 PRO mode: Saving to SQLite first');
        }
        await _localDb.addSalesReturn(salesReturn);

        try {
          // Sau đó lưu vào Firestore
          if (kDebugMode) {
            debugPrint('☁️ PRO mode: Saving to Firestore');
          }
          await _addSalesReturnToFirestore(salesReturn);
        } catch (e) {
          // Nếu Firestore lỗi, vẫn giữ trong SQLite
          if (kDebugMode) {
            debugPrint('⚠️ Error saving sales return to Firestore, kept in SQLite: $e');
          }
        }
      } else {
        // BASIC: Chỉ lưu vào SQLite
        if (kDebugMode) {
          debugPrint('💾 BASIC mode: Saving to SQLite only');
        }
        await _localDb.addSalesReturn(salesReturn);
      }

      if (kDebugMode) {
        debugPrint('✅ Sales return saved successfully: ${salesReturn.id}');
      }

      // 3. Xử lý công nợ khách hàng nếu đơn trả hàng có paymentMethod = 'DEBT'
      if (salesReturn.paymentMethod == 'DEBT' && 
          salesReturn.customerId != null && 
          salesReturn.customerId!.isNotEmpty &&
          customerService != null) {
        try {
          if (kDebugMode) {
            debugPrint('💰 Step 3: Updating customer debt (reducing) for customer: ${salesReturn.customerId}');
          }
          
          // Lấy thông tin khách hàng
          final customer = await customerService.getCustomerById(salesReturn.customerId!);
          if (customer != null) {
            // Cập nhật tổng nợ: giảm số tiền hoàn trả (vì đã trả hàng, nợ giảm)
            final newTotalDebt = customer.totalDebt - salesReturn.totalRefundAmount;
            // Đảm bảo không âm
            final finalTotalDebt = newTotalDebt < 0 ? 0.0 : newTotalDebt;
            
            final updatedCustomer = customer.copyWith(
              totalDebt: finalTotalDebt,
              updatedAt: DateTime.now(),
            );
            
            // Lưu lại khách hàng với nợ mới
            await customerService.updateCustomer(updatedCustomer);
            
            if (kDebugMode) {
              debugPrint('✅ Customer debt updated: ${customer.name} - Old: ${customer.totalDebt}, New: $finalTotalDebt (reduced by ${salesReturn.totalRefundAmount})');
            }
          } else {
            if (kDebugMode) {
              debugPrint('⚠️ Customer not found: ${salesReturn.customerId}, skipping debt update');
            }
          }
        } catch (e) {
          // Log lỗi nhưng không chặn quá trình lưu đơn trả hàng
          if (kDebugMode) {
            debugPrint('⚠️ Error updating customer debt: $e');
          }
        }
      }

      return salesReturn.id;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error saving sales return: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// Cập nhật stock của các sản phẩm sau khi trả hàng (cộng lại vào kho)
  Future<void> _updateProductStocks(List<SaleItem> items, SalesReturnModel salesReturn) async {
    if (_productService == null) {
      if (kDebugMode) {
        debugPrint('⚠️ ProductService is null, skipping stock update');
      }
      return;
    }

    // Lưu vào biến local không nullable để tránh warning
    final productService = _productService;

    for (final item in items) {
      try {
        if (kDebugMode) {
          debugPrint('🔄 Updating stock for product: ${item.productId}, quantity to add back: ${item.quantity}');
        }

        // Lấy sản phẩm hiện tại
        final product = await productService.getProductById(item.productId);
        if (product == null) {
          if (kDebugMode) {
            debugPrint('❌ Product ${item.productId} not found, skipping stock update');
          }
          continue;
        }

        // Kiểm tra isInventoryManaged: chỉ cộng kho cho sản phẩm có quản lý kho
        if (!product.isInventoryManaged) {
          if (kDebugMode) {
            debugPrint('⏭️ Product ${product.name} is not inventory managed (dịch vụ), skipping stock update');
          }
          continue;
        }

        if (kDebugMode) {
          final branchId = salesReturn.branchId;
          final currentBranchStock = product.branchStock[branchId] ?? 0.0;
          debugPrint('📦 Current stock for ${product.name} at branch $branchId: $currentBranchStock');
        }

        // Cập nhật stock: cộng lại số lượng (quantityChange là số dương)
        // Sử dụng updateProductStock với quantityChange dương để cộng lại vào kho
        await productService.updateProductStock(
          item.productId,
          salesReturn.branchId,
          item.quantity, // Số dương để cộng lại vào kho
          type: StockHistoryType.adjustment,
          note: 'Trả hàng từ đơn ${salesReturn.originalSaleId}',
        );

        if (kDebugMode) {
          // Lấy lại sản phẩm để xem stock mới
          final updatedProduct = await productService.getProductById(item.productId);
          if (updatedProduct != null) {
            final branchId = salesReturn.branchId;
            final newBranchStock = updatedProduct.branchStock[branchId] ?? 0.0;
            debugPrint('✅ Stock updated successfully for ${product.name} at branch $branchId: $newBranchStock');
          }
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

  /// Thêm hóa đơn trả hàng vào Firestore
  Future<void> _addSalesReturnToFirestore(SalesReturnModel salesReturn) async {
    try {
      await _salesReturnsCollection.doc(salesReturn.id).set(salesReturn.toFirestore());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding sales return to Firestore: $e');
      }
      rethrow;
    }
  }

  /// Lấy danh sách hóa đơn trả hàng
  /// PRO: Ưu tiên Firestore, nếu lỗi thì fallback SQLite
  /// BASIC: Chỉ lấy từ SQLite
  /// Web: Chỉ lấy từ Firestore
  Future<List<SalesReturnModel>> getSalesReturns({
    DateTime? startDate,
    DateTime? endDate,
    String? branchId, // Lọc theo chi nhánh
    String? originalSaleId, // Lọc theo đơn hàng gốc
  }) async {
    // Helper function để filter theo date và branchId nếu cần
    List<SalesReturnModel> filterSalesReturns(
      List<SalesReturnModel> salesReturns,
      DateTime? start,
      DateTime? end,
      String? branchId,
      String? originalSaleId,
    ) {
      return salesReturns.where((salesReturn) {
        // Filter theo date
        if (start != null && salesReturn.timestamp.isBefore(start)) return false;
        if (end != null && salesReturn.timestamp.isAfter(end)) return false;
        // Filter theo branchId
        if (branchId != null && branchId.isNotEmpty && salesReturn.branchId != branchId) return false;
        // Filter theo originalSaleId
        if (originalSaleId != null && originalSaleId.isNotEmpty && salesReturn.originalSaleId != originalSaleId) return false;
        return true;
      }).toList();
    }

    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      try {
        Query<Map<String, dynamic>> query = _salesReturnsCollection.orderBy('timestamp', descending: true);

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
        // Lọc theo originalSaleId nếu có
        if (originalSaleId != null && originalSaleId.isNotEmpty) {
          query = query.where('originalSaleId', isEqualTo: originalSaleId);
        }

        final snapshot = await query.get();
        return snapshot.docs
            .map((doc) => SalesReturnModel.fromFirestore(doc.data(), doc.id))
            .toList();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Firestore query with date filter failed, trying without filter: $e');
        }
        // Fallback: Lấy tất cả rồi filter local
        try {
          final snapshot = await _salesReturnsCollection.orderBy('timestamp', descending: true).get();
          final allSalesReturns = snapshot.docs
              .map((doc) => SalesReturnModel.fromFirestore(doc.data(), doc.id))
              .toList();
          return filterSalesReturns(allSalesReturns, startDate, endDate, branchId, originalSaleId);
        } catch (e2) {
          if (kDebugMode) {
            debugPrint('❌ Error loading sales returns from Firestore: $e2');
          }
          rethrow;
        }
      }
    }

    if (isPro) {
      try {
        // PRO: Ưu tiên Firestore
        Query<Map<String, dynamic>> query = _salesReturnsCollection.orderBy('timestamp', descending: true);

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
        // Lọc theo originalSaleId nếu có
        if (originalSaleId != null && originalSaleId.isNotEmpty) {
          query = query.where('originalSaleId', isEqualTo: originalSaleId);
        }

        final snapshot = await query.get();
        final salesReturns = snapshot.docs
            .map((doc) => SalesReturnModel.fromFirestore(doc.data(), doc.id))
            .toList();

        // Đồng bộ vào SQLite để dự phòng
        for (final salesReturn in salesReturns) {
          try {
            await _localDb.addSalesReturn(salesReturn);
          } catch (e) {
            // Ignore duplicate errors
          }
        }

        return salesReturns;
      } catch (e) {
        // Nếu Firestore lỗi, fallback về SQLite và filter theo date
        if (kDebugMode) {
          debugPrint('⚠️ Firestore error, falling back to SQLite: $e');
        }
        final allSalesReturns = await _localDb.getSalesReturns(userId: userId);
        return filterSalesReturns(allSalesReturns, startDate, endDate, branchId, originalSaleId);
      }
    } else {
      // BASIC: Chỉ lấy từ SQLite và filter theo date và branchId
      final allSalesReturns = await _localDb.getSalesReturns(userId: userId);
      return filterSalesReturns(allSalesReturns, startDate, endDate, branchId, originalSaleId);
    }
  }

  /// Lấy hóa đơn trả hàng theo ID
  Future<SalesReturnModel?> getSalesReturnById(String salesReturnId) async {
    if (isPro) {
      try {
        final doc = await _salesReturnsCollection.doc(salesReturnId).get();
        if (doc.exists && doc.data() != null) {
          return SalesReturnModel.fromFirestore(doc.data()!, doc.id);
        }
        return null;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Firestore error, falling back to SQLite: $e');
        }
        // Fallback về SQLite
        final salesReturns = await _localDb.getSalesReturns(userId: userId);
        try {
          return salesReturns.firstWhere((salesReturn) => salesReturn.id == salesReturnId);
        } catch (e) {
          return null;
        }
      }
    } else {
      final salesReturns = await _localDb.getSalesReturns(userId: userId);
      try {
        return salesReturns.firstWhere((salesReturn) => salesReturn.id == salesReturnId);
      } catch (e) {
        return null;
      }
    }
  }

  /// Lấy tổng số tiền hoàn trả trong khoảng thời gian
  Future<double> getTotalRefundAmount({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final salesReturns = await getSalesReturns(startDate: startDate, endDate: endDate);
    return salesReturns.fold<double>(0.0, (sum, salesReturn) => sum + salesReturn.totalRefundAmount);
  }
}
