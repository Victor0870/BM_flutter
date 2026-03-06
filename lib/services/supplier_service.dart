import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/supplier_model.dart';

/// Service CRUD nhà cung cấp — Firestore: shops/{userId}/suppliers/{supplierId}
class SupplierService {
  final String userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SupplierService({required this.userId});

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection('shops').doc(userId).collection('suppliers');
  }

  /// Stream danh sách nhà cung cấp theo shop
  Stream<List<SupplierModel>> streamByShop() {
    return _collection.orderBy('name').snapshots().map((snap) {
      return snap.docs
          .map((doc) => SupplierModel.fromFirestore(doc.data(), doc.id))
          .toList();
    });
  }

  /// Thêm nhà cung cấp
  Future<String> add(SupplierModel supplier) async {
    final now = DateTime.now();
    final data = supplier.toFirestore()
      ..['createdAt'] = Timestamp.fromDate(now)
      ..['updatedAt'] = Timestamp.fromDate(now);
    final ref = await _collection.add(data);
    if (kDebugMode) debugPrint('SupplierService: added ${ref.id}');
    return ref.id;
  }

  /// Cập nhật nhà cung cấp
  Future<void> update(SupplierModel supplier) async {
    final data = supplier.toFirestore()
      ..['updatedAt'] = Timestamp.fromDate(DateTime.now());
    await _collection.doc(supplier.id).set(data, SetOptions(merge: true));
  }

  /// Xóa nhà cung cấp
  Future<void> delete(String supplierId) async {
    await _collection.doc(supplierId).delete();
  }

  /// Lấy theo id
  Future<SupplierModel?> getById(String supplierId) async {
    final doc = await _collection.doc(supplierId).get();
    if (doc.exists && doc.data() != null) {
      return SupplierModel.fromFirestore(doc.data()!, doc.id);
    }
    return null;
  }

  /// Lấy danh sách một lần (cho dropdown khi không cần stream)
  Future<List<SupplierModel>> getList() async {
    final snap = await _collection.orderBy('name').get();
    return snap.docs
        .map((doc) => SupplierModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }
}
