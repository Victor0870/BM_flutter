import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../models/stock_history_model.dart';
import 'local_db_service.dart';

/// Hybrid Stock History Service - Quản lý lịch sử tồn kho với logic hybrid (Offline-First)
/// - Gói BASIC: Chỉ lưu vào SQLite (Local Database)
/// - Gói PRO: Lưu song song vào cả SQLite và Firestore
///   + SQLite: Dùng khi mất mạng hoặc hết hạn license
///   + Firestore: Đồng bộ đa thiết bị
///   + Khi hết hạn PRO → BASIC: Dữ liệu vẫn còn trong SQLite
class StockHistoryService {
  final bool isPro;
  final String userId;
  final LocalDbService _localDb = LocalDbService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StockHistoryService({
    required this.isPro,
    required this.userId,
  });

  /// Lấy collection reference cho Firestore - Stock History
  CollectionReference<Map<String, dynamic>> get _stockHistoryCollection {
    return _firestore.collection('shops').doc(userId).collection('stock_history');
  }

  /// Thêm bản ghi lịch sử tồn kho
  /// CHIẾN LƯỢC: Cập nhật SQLite trước, sau đó push lên Firestore (Write once)
  /// PRO: Lưu vào SQLite trước, sau đó push lên Firestore
  /// BASIC: Chỉ lưu vào SQLite
  /// Web: Chỉ lưu vào Firestore
  Future<String> addStockHistory(StockHistoryModel history) async {
    if (kDebugMode) {
      debugPrint('📝 Adding stock history: productId=${history.productId}, branchId=${history.branchId}, type=${history.type.value}, change=${history.quantityChange}');
    }

    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _addStockHistoryToFirestore(history);
    }

    // TẤT CẢ: Luôn cập nhật SQLite trước (offline-first)
    await _localDb.addStockHistory(history);

    // PRO: Sau đó push lên Firestore (write once)
    if (isPro) {
      try {
        await _addStockHistoryToFirestore(history);
        if (kDebugMode) {
          debugPrint('✅ Stock history added to SQLite and Firestore: ${history.id}');
        }
      } catch (e) {
        // Nếu Firestore lỗi, vẫn giữ trong SQLite
        if (kDebugMode) {
          debugPrint('⚠️ Error adding to Firestore, kept in SQLite: $e');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Stock history added to SQLite only (BASIC package): ${history.id}');
      }
    }

    return history.id;
  }

  /// Thêm bản ghi lịch sử tồn kho vào Firestore
  Future<String> _addStockHistoryToFirestore(StockHistoryModel history) async {
    try {
      final docRef = _stockHistoryCollection.doc(history.id);
      await docRef.set(history.toFirestore());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding stock history to Firestore: $e');
      }
      rethrow;
    }
  }

  /// Lấy lịch sử tồn kho theo productId
  /// CHỈ ĐỌC TỪ SQLITE để tiết kiệm chi phí Firebase
  /// Web: Chỉ đọc từ Firestore
  Future<List<StockHistoryModel>> getStockHistoryByProductId(
    String productId, {
    String? branchId,
    StockHistoryType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    // Trên web, vẫn phải dùng Firestore vì không có SQLite
    if (kIsWeb) {
      return await _getStockHistoryByProductIdFromFirestore(
        productId,
        branchId: branchId,
        type: type,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
    }

    // TẤT CẢ các trường hợp khác: CHỈ đọc từ SQLite
    return await _localDb.getStockHistoryByProductId(
      productId,
      branchId: branchId,
      type: type,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Lấy lịch sử tồn kho theo productId từ Firestore
  Future<List<StockHistoryModel>> _getStockHistoryByProductIdFromFirestore(
    String productId, {
    String? branchId,
    StockHistoryType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _stockHistoryCollection
          .where('productId', isEqualTo: productId)
          .orderBy('timestamp', descending: true);

      if (branchId != null && branchId.isNotEmpty) {
        query = query.where('branchId', isEqualTo: branchId);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.value);
      }

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      QuerySnapshot<Map<String, dynamic>> snapshot;
      if (limit != null && limit > 0) {
        snapshot = await query.limit(limit).get();
      } else {
        snapshot = await query.get();
      }

      return snapshot.docs
          .map((doc) => StockHistoryModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting stock history from Firestore: $e');
      }
      return [];
    }
  }

  /// Lấy lịch sử tồn kho theo branchId
  /// CHỈ ĐỌC TỪ SQLITE để tiết kiệm chi phí Firebase
  /// Web: Chỉ đọc từ Firestore
  Future<List<StockHistoryModel>> getStockHistoryByBranchId(
    String branchId, {
    StockHistoryType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    // Trên web, vẫn phải dùng Firestore vì không có SQLite
    if (kIsWeb) {
      return await _getStockHistoryByBranchIdFromFirestore(
        branchId,
        type: type,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
    }

    // TẤT CẢ các trường hợp khác: CHỈ đọc từ SQLite
    return await _localDb.getStockHistoryByBranchId(
      branchId,
      type: type,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Lấy lịch sử tồn kho theo branchId từ Firestore
  Future<List<StockHistoryModel>> _getStockHistoryByBranchIdFromFirestore(
    String branchId, {
    StockHistoryType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _stockHistoryCollection
          .where('branchId', isEqualTo: branchId)
          .orderBy('timestamp', descending: true);

      if (type != null) {
        query = query.where('type', isEqualTo: type.value);
      }

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      QuerySnapshot<Map<String, dynamic>> snapshot;
      if (limit != null && limit > 0) {
        snapshot = await query.limit(limit).get();
      } else {
        snapshot = await query.get();
      }

      return snapshot.docs
          .map((doc) => StockHistoryModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting stock history by branchId from Firestore: $e');
      }
      return [];
    }
  }

  /// Lấy tất cả lịch sử tồn kho
  /// CHỈ ĐỌC TỪ SQLITE để tiết kiệm chi phí Firebase
  /// Web: Chỉ đọc từ Firestore
  Future<List<StockHistoryModel>> getAllStockHistory({
    String? productId,
    String? branchId,
    StockHistoryType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    // Trên web, vẫn phải dùng Firestore vì không có SQLite
    if (kIsWeb) {
      return await _getAllStockHistoryFromFirestore(
        productId: productId,
        branchId: branchId,
        type: type,
        startDate: startDate,
        endDate: endDate,
        limit: limit,
      );
    }

    // TẤT CẢ các trường hợp khác: CHỈ đọc từ SQLite
    return await _localDb.getAllStockHistory(
      productId: productId,
      branchId: branchId,
      type: type,
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Lấy tất cả lịch sử tồn kho từ Firestore
  Future<List<StockHistoryModel>> _getAllStockHistoryFromFirestore({
    String? productId,
    String? branchId,
    StockHistoryType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _stockHistoryCollection
          .orderBy('timestamp', descending: true);

      if (productId != null && productId.isNotEmpty) {
        query = query.where('productId', isEqualTo: productId);
      }

      if (branchId != null && branchId.isNotEmpty) {
        query = query.where('branchId', isEqualTo: branchId);
      }

      if (type != null) {
        query = query.where('type', isEqualTo: type.value);
      }

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      QuerySnapshot<Map<String, dynamic>> snapshot;
      if (limit != null && limit > 0) {
        snapshot = await query.limit(limit).get();
      } else {
        snapshot = await query.get();
      }

      return snapshot.docs
          .map((doc) => StockHistoryModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting all stock history from Firestore: $e');
      }
      return [];
    }
  }

  /// Xóa lịch sử tồn kho
  /// PRO: Xóa song song trong cả SQLite và Firestore
  /// BASIC: Chỉ xóa trong SQLite
  /// Web: Chỉ xóa trong Firestore
  Future<int> deleteStockHistory(String id) async {
    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _deleteStockHistoryFromFirestore(id);
    }

    if (isPro) {
      // PRO: Xóa trong SQLite trước (offline-first)
      await _localDb.deleteStockHistory(id);

      try {
        // Sau đó xóa trong Firestore
        return await _deleteStockHistoryFromFirestore(id);
      } catch (e) {
        // Nếu Firestore lỗi, vẫn giữ trong SQLite
        if (kDebugMode) {
          debugPrint('Error deleting from Firestore, kept in SQLite: $e');
        }
        return 1;
      }
    } else {
      // BASIC: Chỉ xóa trong SQLite
      return await _localDb.deleteStockHistory(id);
    }
  }

  /// Xóa lịch sử tồn kho từ Firestore
  Future<int> _deleteStockHistoryFromFirestore(String id) async {
    try {
      await _stockHistoryCollection.doc(id).delete();
      return 1;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting stock history from Firestore: $e');
      }
      rethrow;
    }
  }
}
