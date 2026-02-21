import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/user_model.dart';

/// Service CRUD nhân viên từ Firestore.
/// Nhân viên được lưu trong collection root `users` với field `shopId` = uid của chủ shop.
/// Mỗi nhân viên khi tạo bắt buộc gắn với một [workingBranchId] (chi nhánh làm việc chính).
class EmployeeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// [shopId] = uid của chủ shop (owner). Tất cả nhân viên có doc trong `users` với shopId = shopId.
  final String shopId;

  EmployeeService({required this.shopId});

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Lấy danh sách nhân viên của shop (tất cả doc trong `users` có shopId = [shopId]).
  /// [includeUnapproved] = true thì bao gồm nhân viên chưa duyệt (isApproved = false).
  Future<List<UserModel>> getEmployees({bool includeUnapproved = false}) async {
    try {
      final snapshot =
          await _usersCollection.where('shopId', isEqualTo: shopId).get();

      var list = snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
          .toList();

      if (!includeUnapproved) {
        list = list.where((e) => e.isApproved).toList();
      }
      return list;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EmployeeService getEmployees error: $e');
      }
      return [];
    }
  }

  /// Lấy một nhân viên theo [uid]. Trả về null nếu không tồn tại hoặc không thuộc shop.
  Future<UserModel?> getEmployeeById(String uid) async {
    try {
      final doc = await _usersCollection.doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      final data = doc.data()!;
      if (data['shopId'] != shopId) return null;
      return UserModel.fromFirestore(data, doc.id);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('EmployeeService getEmployeeById error: $e');
      }
      return null;
    }
  }

  /// Thêm bản ghi nhân viên vào Firestore.
  /// [employee.uid] phải đã tồn tại (Firebase Auth user đã được tạo trước).
  /// [employee.workingBranchId] bắt buộc: mỗi nhân viên phải gắn với một chi nhánh.
  /// [employee.shopId] phải bằng [shopId] của service.
  Future<void> addEmployee(UserModel employee) async {
    if (employee.shopId != shopId) {
      throw ArgumentError(
          'employee.shopId phải trùng với shopId của EmployeeService');
    }
    if (employee.role != UserRole.owner &&
        (employee.workingBranchId == null ||
            employee.workingBranchId!.isEmpty)) {
      throw ArgumentError(
          'Nhân viên (manager/staff) bắt buộc phải có workingBranchId');
    }

    await _usersCollection.doc(employee.uid).set(employee.toFirestore());
    if (kDebugMode) {
      debugPrint('EmployeeService addEmployee: ${employee.uid}');
    }
  }

  /// Cập nhật thông tin nhân viên. Chỉ cập nhật các field có trong [updates].
  /// [updates] dùng cho Firestore (Timestamp cho DateTime, không dùng uid/shopId thay đổi).
  Future<void> updateEmployee(String uid, Map<String, dynamic> updates) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists || doc.data()?['shopId'] != shopId) {
      throw StateError('Nhân viên không tồn tại hoặc không thuộc shop');
    }

    final sanitized = Map<String, dynamic>.from(updates);
    if (sanitized.containsKey('createdAt') &&
        sanitized['createdAt'] is DateTime) {
      sanitized['createdAt'] = Timestamp.fromDate(sanitized['createdAt']);
    }
    if (sanitized.containsKey('updatedAt')) {
      sanitized['updatedAt'] = Timestamp.fromDate(DateTime.now());
    }

    await _usersCollection.doc(uid).update(sanitized);
    if (kDebugMode) {
      debugPrint('EmployeeService updateEmployee: $uid');
    }
  }

  /// Cập nhật nhân viên từ model (ghi đè toàn bộ doc trừ uid).
  Future<void> setEmployee(UserModel employee) async {
    if (employee.shopId != shopId) {
      throw ArgumentError(
          'employee.shopId phải trùng với shopId của EmployeeService');
    }
    if (employee.role != UserRole.owner &&
        (employee.workingBranchId == null ||
            employee.workingBranchId!.isEmpty)) {
      throw ArgumentError(
          'Nhân viên (manager/staff) bắt buộc phải có workingBranchId');
    }

    await _usersCollection.doc(employee.uid).set(employee.toFirestore());
    if (kDebugMode) {
      debugPrint('EmployeeService setEmployee: ${employee.uid}');
    }
  }

  /// Xóa bản ghi nhân viên khỏi Firestore (không xóa user Firebase Auth).
  Future<void> deleteEmployee(String uid) async {
    final doc = await _usersCollection.doc(uid).get();
    if (!doc.exists || doc.data()?['shopId'] != shopId) {
      throw StateError('Nhân viên không tồn tại hoặc không thuộc shop');
    }
    await _usersCollection.doc(uid).delete();
    if (kDebugMode) {
      debugPrint('EmployeeService deleteEmployee: $uid');
    }
  }
}
