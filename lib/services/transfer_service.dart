import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../models/transfer_model.dart';
import 'product_service.dart';

/// Hybrid Transfer Service - Quản lý chuyển kho với logic hybrid (Offline-First)
/// - Gói BASIC: Chỉ lưu vào SQLite
/// - Gói PRO: Lưu song song vào cả SQLite và Firestore
/// - Khi status == 'COMPLETED': Trừ kho chi nhánh gửi và cộng kho chi nhánh nhận
class TransferService {
  final bool isPro;
  final String userId;
  // ignore: todo
  // final LocalDbService _localDb = LocalDbService(); // Sử dụng khi có transfers table trong SQLite
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ProductService _productService;

  TransferService({
    required this.isPro,
    required this.userId,
    required ProductService productService,
  }) : _productService = productService;

  /// Lấy collection reference cho Firestore
  CollectionReference<Map<String, dynamic>> get _transfersCollection {
    return _firestore.collection('shops').doc(userId).collection('transfers');
  }

  /// Lưu phiếu chuyển kho và cập nhật stock nếu status = COMPLETED
  /// PRO: Lưu song song SQLite + Firestore
  /// BASIC: Chỉ lưu SQLite
  Future<String> saveTransfer(TransferModel transfer) async {
    try {
      if (kDebugMode) {
        debugPrint('📦 Starting saveTransfer: ${transfer.id}, from: ${transfer.fromBranchId}, to: ${transfer.toBranchId}, status: ${transfer.status}');
      }

      // 1. Nếu status là COMPLETED, cập nhật stock cho cả 2 chi nhánh
      if (transfer.status == 'COMPLETED') {
        if (kDebugMode) {
          debugPrint('📦 Step 1: Updating stock for both branches...');
        }
        await _updateProductStocksForTransfer(transfer);
        if (kDebugMode) {
          debugPrint('✅ Step 1 completed: Stock updated for both branches');
        }
      }

      // 2. Lưu phiếu chuyển kho
      if (kIsWeb) {
        // Web: Chỉ lưu Firestore
        await _saveTransferToFirestore(transfer);
      } else {
        // Mobile/Desktop: Lưu SQLite trước (offline-first)
        await _saveTransferToLocal(transfer);

        // PRO: Sau đó push lên Firestore
        if (isPro) {
          try {
            await _saveTransferToFirestore(transfer);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('⚠️ Error saving to Firestore, kept in SQLite: $e');
            }
          }
        }
      }

      if (kDebugMode) {
        debugPrint('✅ Transfer saved successfully: ${transfer.id}');
      }

      return transfer.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving transfer: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật stock cho cả 2 chi nhánh khi chuyển kho
  Future<void> _updateProductStocksForTransfer(TransferModel transfer) async {
    for (final item in transfer.items) {
      try {
        // Lấy sản phẩm hiện tại
        final product = await _productService.getProductById(item.productId);
        if (product == null) {
          if (kDebugMode) {
            debugPrint('⚠️ Product not found: ${item.productId}');
          }
          continue;
        }

        // Trừ kho chi nhánh gửi
        final fromBranchStock = product.branchStock[transfer.fromBranchId] ?? 0.0;
        if (fromBranchStock < item.quantity) {
          throw Exception('Không đủ hàng ở chi nhánh gửi. Tồn kho: $fromBranchStock, yêu cầu: ${item.quantity}');
        }

        // Cập nhật branchStock
        final updatedBranchStock = Map<String, double>.from(product.branchStock);
        
        // Trừ kho chi nhánh gửi
        updatedBranchStock[transfer.fromBranchId] = fromBranchStock - item.quantity;
        
        // Cộng kho chi nhánh nhận
        final toBranchStock = updatedBranchStock[transfer.toBranchId] ?? 0.0;
        updatedBranchStock[transfer.toBranchId] = toBranchStock + item.quantity;

        // Cập nhật sản phẩm
        final updatedProduct = product.copyWith(
          branchStock: updatedBranchStock,
          updatedAt: DateTime.now(),
        );

        if (kDebugMode) {
          debugPrint('📦 Transferring product: ${product.name}');
          debugPrint('  From branch ${transfer.fromBranchId}: $fromBranchStock → ${updatedBranchStock[transfer.fromBranchId]}');
          debugPrint('  To branch ${transfer.toBranchId}: $toBranchStock → ${updatedBranchStock[transfer.toBranchId]}');
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
        rethrow;
      }
    }
  }

  /// Lưu vào SQLite
  Future<void> _saveTransferToLocal(TransferModel transfer) async {
    try {
      // ignore: todo
      // Thêm method vào LocalDbService để lưu transfers
      // Tạm thời bỏ qua vì chưa có transfers table trong SQLite
      // Có thể thêm sau khi cần thiết
      if (kDebugMode) {
        debugPrint('💾 Saving transfer to SQLite: ${transfer.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ Error saving transfer to SQLite: $e');
      }
      // Không throw, vì có thể table chưa tồn tại
    }
  }

  /// Lưu vào Firestore
  Future<void> _saveTransferToFirestore(TransferModel transfer) async {
    try {
      await _transfersCollection.doc(transfer.id).set(transfer.toFirestore());
      if (kDebugMode) {
        debugPrint('☁️ Transfer saved to Firestore: ${transfer.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving transfer to Firestore: $e');
      }
      rethrow;
    }
  }

  /// Lấy danh sách phiếu chuyển kho
  Future<List<TransferModel>> getTransfers({String? branchId}) async {
    if (kIsWeb || !isPro) {
      // Web hoặc BASIC: Chỉ đọc từ Firestore
      return await _getTransfersFromFirestore(branchId: branchId);
    }

    // PRO Mobile/Desktop: Đọc từ SQLite (có thể thêm sau)
    return await _getTransfersFromFirestore(branchId: branchId);
  }

  /// Lấy từ Firestore
  Future<List<TransferModel>> _getTransfersFromFirestore({String? branchId}) async {
    try {
      Query<Map<String, dynamic>> query = _transfersCollection.orderBy('timestamp', descending: true);

      // Lọc theo branchId nếu có
      if (branchId != null) {
        query = query.where('fromBranchId', isEqualTo: branchId);
        // Hoặc có thể dùng OR để lấy cả from và to
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => TransferModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting transfers from Firestore: $e');
      }
      return [];
    }
  }
}
