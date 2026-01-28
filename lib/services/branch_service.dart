import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../models/branch_model.dart';
import 'local_db_service.dart';

/// Hybrid Branch Service - Quản lý chi nhánh với logic hybrid (Offline-First)
/// - Gói BASIC: Chỉ lưu vào SQLite
/// - Gói PRO: Lưu song song vào cả SQLite và Firestore
class BranchService {
  final bool isPro;
  final String userId;
  final LocalDbService _localDb = LocalDbService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  BranchService({
    required this.isPro,
    required this.userId,
  });

  /// Lấy collection reference cho Firestore - Branches
  CollectionReference<Map<String, dynamic>> get _branchesCollection {
    return _firestore.collection('shops').doc(userId).collection('branches');
  }

  /// Lấy tất cả chi nhánh
  /// CHỈ ĐỌC TỪ SQLITE để tiết kiệm chi phí Firebase
  /// Để có dữ liệu mới nhất, gọi syncAllFromCloud() từ ProductService
  Future<List<BranchModel>> getBranches({bool includeInactive = false}) async {
    // Trên web, vẫn phải dùng Firestore vì không có SQLite
    if (kIsWeb) {
      return await _getBranchesFromFirestore(includeInactive: includeInactive);
    }

    // TẤT CẢ các trường hợp khác: CHỈ đọc từ SQLite
    return await _localDb.getBranches(includeInactive: includeInactive);
  }

  /// Lấy chi nhánh theo ID
  Future<BranchModel?> getBranchById(String id) async {
    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _getBranchByIdFromFirestore(id);
    }

    // Mobile/Desktop: Đọc từ SQLite
    return await _localDb.getBranchById(id);
  }

  /// Lấy từ Firestore
  Future<List<BranchModel>> _getBranchesFromFirestore({bool includeInactive = false}) async {
    try {
      Query<Map<String, dynamic>> query = _branchesCollection.orderBy('name');

      if (!includeInactive) {
        query = query.where('isActive', isEqualTo: true);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map((doc) => BranchModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting branches from Firestore: $e');
      }
      return [];
    }
  }

  /// Lấy từ Firestore theo ID
  Future<BranchModel?> _getBranchByIdFromFirestore(String id) async {
    try {
      final doc = await _branchesCollection.doc(id).get();
      if (doc.exists && doc.data() != null) {
        return BranchModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting branch from Firestore: $e');
      }
      return null;
    }
  }

  /// Thêm chi nhánh mới
  /// CHIẾN LƯỢC: Cập nhật SQLite trước, sau đó push lên Firestore (Write once)
  Future<String> addBranch(BranchModel branch) async {
    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _addBranchToFirestore(branch);
    }

    // TẤT CẢ: Luôn cập nhật SQLite trước (offline-first)
    await _localDb.addBranch(branch);

    // PRO: Sau đó push lên Firestore (write once)
    if (isPro) {
      try {
        await _addBranchToFirestore(branch);
        if (kDebugMode) {
          debugPrint('✅ Branch added to SQLite and Firestore: ${branch.id}');
        }
      } catch (e) {
        // Nếu Firestore lỗi, vẫn giữ trong SQLite
        if (kDebugMode) {
          debugPrint('⚠️ Error adding to Firestore, kept in SQLite: $e');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Branch added to SQLite only (BASIC package): ${branch.id}');
      }
    }

    return branch.id;
  }

  /// Thêm chi nhánh vào Firestore
  Future<String> _addBranchToFirestore(BranchModel branch) async {
    try {
      final docRef = _branchesCollection.doc(branch.id);
      await docRef.set(branch.toFirestore());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding branch to Firestore: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật chi nhánh
  /// CHIẾN LƯỢC: Cập nhật SQLite trước, sau đó push lên Firestore (Write once)
  Future<int> updateBranch(BranchModel branch) async {
    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _updateBranchInFirestore(branch);
    }

    // TẤT CẢ: Luôn cập nhật SQLite trước (offline-first)
    await _localDb.updateBranch(branch);

    // PRO: Sau đó push lên Firestore (write once)
    if (isPro) {
      try {
        await _updateBranchInFirestore(branch);
        if (kDebugMode) {
          debugPrint('✅ Branch updated in SQLite and Firestore: ${branch.id}');
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
        debugPrint('✅ Branch updated in SQLite only (BASIC package): ${branch.id}');
      }
      return 1;
    }
  }

  /// Cập nhật chi nhánh trong Firestore
  Future<int> _updateBranchInFirestore(BranchModel branch) async {
    try {
      await _branchesCollection.doc(branch.id).update(branch.toFirestore());
      return 1;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating branch in Firestore: $e');
      }
      rethrow;
    }
  }

  /// Xóa chi nhánh (soft delete)
  /// CHIẾN LƯỢC: Cập nhật SQLite trước, sau đó push lên Firestore (Write once)
  Future<int> deleteBranch(String id) async {
    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _deleteBranchFromFirestore(id);
    }

    // TẤT CẢ: Luôn cập nhật SQLite trước (offline-first)
    await _localDb.deleteBranch(id);

    // PRO: Sau đó push lên Firestore (write once)
    if (isPro) {
      try {
        await _deleteBranchFromFirestore(id);
        if (kDebugMode) {
          debugPrint('✅ Branch deleted in SQLite and Firestore: $id');
        }
        return 1;
      } catch (e) {
        // Nếu Firestore lỗi, vẫn giữ trong SQLite
        if (kDebugMode) {
          debugPrint('⚠️ Error deleting from Firestore, kept in SQLite: $e');
        }
        return 1;
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Branch deleted in SQLite only (BASIC package): $id');
      }
      return 1;
    }
  }

  /// Xóa chi nhánh từ Firestore (soft delete)
  Future<int> _deleteBranchFromFirestore(String id) async {
    try {
      await _branchesCollection.doc(id).update({
        'isActive': false,
      });
      return 1;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting branch from Firestore: $e');
      }
      rethrow;
    }
  }
}
