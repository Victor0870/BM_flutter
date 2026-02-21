import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/employee_group_model.dart';

/// Service CRUD nhóm nhân viên trên Firestore.
/// Collection: shops/{shopId}/employee_groups
class EmployeeGroupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String shopId;

  EmployeeGroupService({required this.shopId});

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('shops').doc(shopId).collection('employee_groups');

  /// Lấy tất cả nhóm nhân viên của shop.
  Future<List<EmployeeGroupModel>> getEmployeeGroups() async {
    try {
      final snapshot = await _collection.orderBy('name').get();
      return snapshot.docs
          .map((doc) => EmployeeGroupModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EmployeeGroupService getEmployeeGroups error: $e');
      }
      return [];
    }
  }

  /// Lấy một nhóm theo ID.
  Future<EmployeeGroupModel?> getEmployeeGroupById(String id) async {
    try {
      final doc = await _collection.doc(id).get();
      if (!doc.exists || doc.data() == null) return null;
      return EmployeeGroupModel.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EmployeeGroupService getEmployeeGroupById error: $e');
      }
      return null;
    }
  }

  /// Thêm nhóm nhân viên. [group.id] có thể để trống để Firestore tự sinh.
  Future<String> addEmployeeGroup(EmployeeGroupModel group) async {
    try {
      final data = group.toFirestore();
      if (group.id.isNotEmpty) {
        await _collection.doc(group.id).set(data);
        return group.id;
      }
      final docRef = await _collection.add({
        ...data,
        'shopId': shopId,
      });
      if (kDebugMode) {
        debugPrint('EmployeeGroupService addEmployeeGroup: ${docRef.id}');
      }
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EmployeeGroupService addEmployeeGroup error: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật nhóm nhân viên.
  Future<void> updateEmployeeGroup(EmployeeGroupModel group) async {
    try {
      await _collection.doc(group.id).update(group.toFirestore());
      if (kDebugMode) {
        debugPrint('EmployeeGroupService updateEmployeeGroup: ${group.id}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EmployeeGroupService updateEmployeeGroup error: $e');
      }
      rethrow;
    }
  }

  /// Xóa nhóm nhân viên.
  Future<void> deleteEmployeeGroup(String id) async {
    try {
      await _collection.doc(id).delete();
      if (kDebugMode) {
        debugPrint('EmployeeGroupService deleteEmployeeGroup: $id');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EmployeeGroupService deleteEmployeeGroup error: $e');
      }
      rethrow;
    }
  }
}
