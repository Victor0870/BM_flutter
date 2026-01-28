import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../models/sale_model.dart';
import 'local_db_service.dart';
import 'product_service.dart';
import 'customer_service.dart';

/// Hybrid Sales Service - Quản lý đơn hàng với logic hybrid (Offline-First)
/// - Gói BASIC: Chỉ lưu vào SQLite
/// - Gói PRO: Lưu song song vào cả SQLite và Firestore
/// - Khi lưu đơn hàng, tự động cập nhật stock của sản phẩm
class SalesService {
  final bool isPro;
  final String userId;
  final LocalDbService _localDb = LocalDbService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProductService? _productService;

  SalesService({
    required this.isPro,
    required this.userId,
    ProductService? productService,
  }) : _productService = productService;

  /// Lấy collection reference cho Firestore
  CollectionReference<Map<String, dynamic>> get _salesCollection {
    return _firestore.collection('shops').doc(userId).collection('sales');
  }

  /// Lưu đơn hàng và cập nhật stock
  /// PRO: Lưu song song SQLite + Firestore, cập nhật stock cả 2
  /// BASIC: Chỉ lưu SQLite, cập nhật stock SQLite
  /// Nếu đơn hàng là "nợ" (paymentMethod = 'DEBT'), sẽ cập nhật totalDebt của khách hàng
  Future<String> saveSale(
    SaleModel sale, {
    CustomerService? customerService,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('💼 Starting saveSale with ${sale.items.length} items, total: ${sale.totalAmount}');
      }

      // 1. Cập nhật stock cho tất cả sản phẩm trong đơn hàng TRƯỚC
      // Quan trọng: Phải cập nhật stock trước khi lưu sale
      // NHƯNG: Chỉ cập nhật stock nếu paymentStatus = COMPLETED
      if (sale.paymentStatus == 'COMPLETED') {
        if (kDebugMode) {
          debugPrint('📦 Step 1: Updating product stocks...');
        }
        await _updateProductStocks(sale.items, sale);
      } else {
        if (kDebugMode) {
          debugPrint('⏳ Step 1: Skipping stock update (paymentStatus = ${sale.paymentStatus})');
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Step 1 completed: All stocks updated');
      }

      // 2. Lưu đơn hàng
      if (kDebugMode) {
        debugPrint('💾 Step 2: Saving sale to storage...');
      }

      // Trên web, chỉ dùng Firestore
      if (kIsWeb) {
        if (kDebugMode) {
          debugPrint('🌐 Web mode: Saving to Firestore only');
        }
        await _addSaleToFirestore(sale);
      } else if (isPro) {
        // PRO: Lưu vào SQLite trước (offline-first)
        if (kDebugMode) {
          debugPrint('💾 PRO mode: Saving to SQLite first');
        }
        await _localDb.addSale(sale);

        try {
          // Sau đó lưu vào Firestore
          if (kDebugMode) {
            debugPrint('☁️ PRO mode: Saving to Firestore');
          }
          await _addSaleToFirestore(sale);
        } catch (e) {
          // Nếu Firestore lỗi, vẫn giữ trong SQLite
          if (kDebugMode) {
            debugPrint('⚠️ Error saving sale to Firestore, kept in SQLite: $e');
          }
        }
      } else {
        // BASIC: Chỉ lưu vào SQLite
        if (kDebugMode) {
          debugPrint('💾 BASIC mode: Saving to SQLite only');
        }
        await _localDb.addSale(sale);
      }

      if (kDebugMode) {
        debugPrint('✅ Sale saved successfully: ${sale.id}');
      }

      // 3. Xử lý nợ khách hàng nếu đơn hàng là "nợ" (paymentMethod = 'DEBT')
      if (sale.paymentMethod == 'DEBT' && 
          sale.customerId != null && 
          sale.customerId!.isNotEmpty &&
          customerService != null) {
        try {
          if (kDebugMode) {
            debugPrint('💰 Step 3: Updating customer debt for customer: ${sale.customerId}');
          }
          
          // Lấy thông tin khách hàng
          final customer = await customerService.getCustomerById(sale.customerId!);
          if (customer != null) {
            // Cập nhật tổng nợ: thêm số tiền của đơn hàng này
            final newTotalDebt = customer.totalDebt + sale.totalAmount;
            final updatedCustomer = customer.copyWith(
              totalDebt: newTotalDebt,
              updatedAt: DateTime.now(),
            );
            
            // Lưu lại khách hàng với nợ mới
            await customerService.updateCustomer(updatedCustomer);
            
            if (kDebugMode) {
              debugPrint('✅ Customer debt updated: ${customer.name} - Old: ${customer.totalDebt}, New: $newTotalDebt');
            }
          } else {
            if (kDebugMode) {
              debugPrint('⚠️ Customer not found: ${sale.customerId}, skipping debt update');
            }
          }
        } catch (e) {
          // Log lỗi nhưng không chặn quá trình lưu đơn hàng
          if (kDebugMode) {
            debugPrint('⚠️ Error updating customer debt: $e');
          }
        }
      }

      return sale.id;
    } catch (e, stackTrace) {
      if (kDebugMode) {
        debugPrint('❌ Error saving sale: $e');
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow;
    }
  }

  /// Cập nhật trạng thái thanh toán của đơn hàng
  /// Chỉ cập nhật paymentStatus, không cập nhật stock (đã được cập nhật trước đó)
  /// Cập nhật SaleModel (dùng để cập nhật thông tin hóa đơn điện tử)
  Future<void> updateSale(SaleModel sale) async {
    if (kDebugMode) {
      debugPrint('💾 Updating sale: ${sale.id}');
    }

    if (kIsWeb) {
      // Web: Chỉ cập nhật Firestore
      await _updateSaleInFirestore(sale);
    } else if (isPro) {
      // PRO: Cập nhật cả SQLite và Firestore
      await _localDb.updateSale(sale);
      try {
        await _updateSaleInFirestore(sale);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error updating sale in Firestore: $e');
        }
      }
    } else {
      // BASIC: Chỉ cập nhật SQLite
      await _localDb.updateSale(sale);
    }

    if (kDebugMode) {
      debugPrint('✅ Sale updated successfully: ${sale.id}');
    }
  }

  /// Cập nhật sale trong Firestore
  Future<void> _updateSaleInFirestore(SaleModel sale) async {
    try {
      await _salesCollection.doc(sale.id).update(sale.toFirestore());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating sale in Firestore: $e');
      }
      rethrow;
    }
  }

  Future<void> updateSalePaymentStatus(String saleId, String paymentStatus) async {
    try {
      if (kDebugMode) {
        debugPrint('💼 Updating payment status for sale: $saleId to $paymentStatus');
      }

      // Trên web, chỉ dùng Firestore
      if (kIsWeb) {
        try {
          await _salesCollection.doc(saleId).update({
            'paymentStatus': paymentStatus,
            'updatedAt': Timestamp.now(),
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error updating sale payment status in Firestore: $e');
          }
          rethrow;
        }
      } else if (isPro) {
        // PRO: Cập nhật cả SQLite và Firestore
        try {
          await _localDb.updateSalePaymentStatus(saleId, paymentStatus);
          await _salesCollection.doc(saleId).update({
            'paymentStatus': paymentStatus,
            'updatedAt': Timestamp.now(),
          });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('⚠️ Error updating sale payment status, but continuing: $e');
          }
          // Vẫn tiếp tục nếu một trong hai lỗi
        }
      } else {
        // BASIC: Chỉ cập nhật SQLite
        await _localDb.updateSalePaymentStatus(saleId, paymentStatus);
      }

      if (kDebugMode) {
        debugPrint('✅ Payment status updated successfully for sale: $saleId');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error updating sale payment status: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật stock của các sản phẩm sau khi bán
  Future<void> _updateProductStocks(List<SaleItem> items, SaleModel sale) async {
    if (_productService == null) {
      if (kDebugMode) {
        debugPrint('⚠️ ProductService is null, skipping stock update');
      }
      return;
    }

    for (final item in items) {
      try {
        if (kDebugMode) {
          debugPrint('🔄 Updating stock for product: ${item.productId}, quantity: ${item.quantity}');
        }

        // Lấy sản phẩm hiện tại
        final product = await _productService.getProductById(item.productId);
        if (product == null) {
          if (kDebugMode) {
            debugPrint('❌ Product ${item.productId} not found, skipping stock update');
          }
          continue;
        }

        if (kDebugMode) {
          debugPrint('📦 Current stock for ${product.name}: ${product.stock}');
        }

        // Tính stock mới cho branch từ sale.branchId
        final branchId = sale.branchId.isNotEmpty ? sale.branchId : 'default';
        final currentBranchStock = product.branchStock[branchId] ?? product.stock;
        final newStock = currentBranchStock - item.quantity;
        
        if (newStock < 0) {
          if (kDebugMode) {
            debugPrint('⚠️ Warning: Stock would be negative for ${product.name}, setting to 0');
          }
        }

        // Cập nhật branchStock
        final updatedBranchStock = Map<String, double>.from(product.branchStock);
        updatedBranchStock[branchId] = newStock < 0 ? 0 : newStock;

        // Cập nhật sản phẩm với branchStock mới
        final updatedProduct = product.copyWith(
          branchStock: updatedBranchStock,
          updatedAt: DateTime.now(),
        );

        if (kDebugMode) {
          debugPrint('💾 New stock for ${product.name}: ${updatedProduct.stock}');
        }

        // Lưu cập nhật (ProductService sẽ xử lý hybrid storage)
        await _productService.updateProduct(updatedProduct);

        if (kDebugMode) {
          debugPrint('✅ Stock updated successfully for ${product.name}');
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

  /// Thêm đơn hàng vào Firestore
  Future<void> _addSaleToFirestore(SaleModel sale) async {
    try {
      await _salesCollection.doc(sale.id).set(sale.toFirestore());
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding sale to Firestore: $e');
      }
      rethrow;
    }
  }

  /// Lấy danh sách đơn hàng
  /// PRO: Ưu tiên Firestore, nếu lỗi thì fallback SQLite
  /// BASIC: Chỉ lấy từ SQLite
  /// Web: Chỉ lấy từ Firestore
  Future<List<SaleModel>> getSales({
    DateTime? startDate,
    DateTime? endDate,
    String? branchId, // Lọc theo chi nhánh
  }) async {
    // Helper function để filter theo date và branchId nếu cần
    List<SaleModel> filterSales(List<SaleModel> sales, DateTime? start, DateTime? end, String? branchId) {
      return sales.where((sale) {
        // Filter theo date
        if (start != null && sale.timestamp.isBefore(start)) return false;
        if (end != null && sale.timestamp.isAfter(end)) return false;
        // Filter theo branchId
        if (branchId != null && branchId.isNotEmpty && sale.branchId != branchId) return false;
        return true;
      }).toList();
    }

    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      try {
        Query<Map<String, dynamic>> query = _salesCollection.orderBy('timestamp', descending: true);

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
            .map((doc) => SaleModel.fromFirestore(doc.data(), doc.id))
            .toList();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Firestore query with date filter failed, trying without filter: $e');
        }
        // Fallback: Lấy tất cả rồi filter local
        try {
          final snapshot = await _salesCollection.orderBy('timestamp', descending: true).get();
          final allSales = snapshot.docs
              .map((doc) => SaleModel.fromFirestore(doc.data(), doc.id))
              .toList();
          return filterSales(allSales, startDate, endDate, branchId);
        } catch (e2) {
          if (kDebugMode) {
            debugPrint('❌ Error loading sales from Firestore: $e2');
          }
          rethrow;
        }
      }
    }

    if (isPro) {
      try {
        // PRO: Ưu tiên Firestore
        Query<Map<String, dynamic>> query = _salesCollection.orderBy('timestamp', descending: true);

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
        final sales = snapshot.docs
            .map((doc) => SaleModel.fromFirestore(doc.data(), doc.id))
            .toList();

        // Đồng bộ vào SQLite để dự phòng
        for (final sale in sales) {
          try {
            await _localDb.addSale(sale);
          } catch (e) {
            // Ignore duplicate errors
          }
        }

        return sales;
      } catch (e) {
        // Nếu Firestore lỗi, fallback về SQLite và filter theo date
        if (kDebugMode) {
          debugPrint('⚠️ Firestore error, falling back to SQLite: $e');
        }
        final allSales = await _localDb.getSales(userId: userId);
        return filterSales(allSales, startDate, endDate, branchId);
      }
    } else {
      // BASIC: Chỉ lấy từ SQLite và filter theo date và branchId
      final allSales = await _localDb.getSales(userId: userId);
      return filterSales(allSales, startDate, endDate, branchId);
    }
  }

  /// Lấy đơn hàng theo ID
  Future<SaleModel?> getSaleById(String saleId) async {
    if (isPro) {
      try {
        final doc = await _salesCollection.doc(saleId).get();
        if (doc.exists && doc.data() != null) {
          return SaleModel.fromFirestore(doc.data()!, doc.id);
        }
        return null;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Firestore error, falling back to SQLite: $e');
        }
        // Fallback về SQLite - cần implement getSaleById trong LocalDbService
        final sales = await _localDb.getSales(userId: userId);
        return sales.firstWhere(
          (sale) => sale.id == saleId,
          orElse: () => throw StateError('Sale not found'),
        );
      }
    } else {
      final sales = await _localDb.getSales(userId: userId);
      try {
        return sales.firstWhere((sale) => sale.id == saleId);
      } catch (e) {
        return null;
      }
    }
  }

  /// Lấy tổng doanh thu trong khoảng thời gian
  Future<double> getTotalRevenue({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final sales = await getSales(startDate: startDate, endDate: endDate);
    return sales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);
  }

  /// Lấy doanh thu hôm nay
  Future<double> getTodayRevenue() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));

      if (kDebugMode) {
        debugPrint('📅 Calculating today revenue from ${startOfDay.toIso8601String()} to ${endOfDay.toIso8601String()}');
      }

      final revenue = await getTotalRevenue(startDate: startOfDay, endDate: endOfDay);

      if (kDebugMode) {
        debugPrint('💰 Today revenue: $revenue');
      }

      return revenue;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error calculating today revenue: $e');
      }
      // Fallback: Lấy tất cả sales và filter local
      final allSales = await getSales();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todaySales = allSales.where((sale) {
        return sale.timestamp.isAfter(startOfDay) && sale.timestamp.isBefore(endOfDay);
      }).toList();

      return todaySales.fold<double>(0.0, (sum, sale) => sum + sale.totalAmount);
    }
  }

  /// Lấy tổng số đơn hàng trong khoảng thời gian
  Future<int> getSalesCount({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final sales = await getSales(startDate: startDate, endDate: endDate);
    return sales.length;
  }

  /// Lấy tổng số đơn hàng hôm nay
  Future<int> getTodaySalesCount() async {
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(microseconds: 1));

      if (kDebugMode) {
        debugPrint('📅 Calculating today sales count from ${startOfDay.toIso8601String()} to ${endOfDay.toIso8601String()}');
      }

      final count = await getSalesCount(startDate: startOfDay, endDate: endOfDay);

      if (kDebugMode) {
        debugPrint('📦 Today sales count: $count');
      }

      return count;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error calculating today sales count: $e');
      }
      // Fallback: Lấy tất cả sales và filter local
      final allSales = await getSales();
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));

      final todaySales = allSales.where((sale) {
        return sale.timestamp.isAfter(startOfDay) && sale.timestamp.isBefore(endOfDay);
      }).toList();

      return todaySales.length;
    }
  }
}

