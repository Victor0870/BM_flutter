import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import '../models/customer_model.dart';
import '../models/customer_group_model.dart';
import 'local_db_service.dart';

/// Hybrid Customer Service - Quản lý khách hàng với logic hybrid (Offline-First)
/// - Gói BASIC: Chỉ lưu vào SQLite
/// - Gói PRO: Lưu song song vào cả SQLite và Firestore
class CustomerService {
  final bool isPro;
  final String userId;
  final LocalDbService _localDb = LocalDbService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CustomerService({
    required this.isPro,
    required this.userId,
  });

  /// Lấy collection reference cho Firestore - Customer Groups
  CollectionReference<Map<String, dynamic>> get _customerGroupsCollection {
    return _firestore.collection('shops').doc(userId).collection('customer_groups');
  }

  /// Lấy collection reference cho Firestore - Customers
  CollectionReference<Map<String, dynamic>> get _customersCollection {
    return _firestore.collection('shops').doc(userId).collection('customers');
  }

  // ==================== CUSTOMER GROUPS ====================

  /// Lấy tất cả nhóm khách hàng
  /// CHỈ ĐỌC TỪ SQLITE để tiết kiệm chi phí Firebase.
  /// PRO + không web: nếu SQLite trống thì đồng bộ từ Firestore (dữ liệu mẫu sau đăng ký).
  Future<List<CustomerGroupModel>> getCustomerGroups() async {
    if (kIsWeb) {
      return await _getCustomerGroupsFromFirestore();
    }

    if (isPro) {
      final local = await _localDb.getCustomerGroups();
      if (local.isEmpty) {
        await _syncCustomerGroupsFromFirestoreToLocal();
        return await _localDb.getCustomerGroups();
      }
      return local;
    }
    return await _localDb.getCustomerGroups();
  }

  /// Lấy nhóm khách hàng theo ID
  Future<CustomerGroupModel?> getCustomerGroupById(String id) async {
    if (kIsWeb) {
      return await _getCustomerGroupByIdFromFirestore(id);
    }

    return await _localDb.getCustomerGroupById(id);
  }

  /// Lấy từ Firestore
  Future<List<CustomerGroupModel>> _getCustomerGroupsFromFirestore() async {
    try {
      final snapshot = await _customerGroupsCollection.orderBy('name').get();
      return snapshot.docs
          .map((doc) => CustomerGroupModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting customer groups from Firestore: $e');
      }
      return [];
    }
  }

  /// Đồng bộ nhóm khách hàng từ Firestore xuống SQLite (PRO, lần đầu sau đăng ký).
  /// Dùng get() không orderBy để tránh lỗi index trên collection mới.
  Future<void> _syncCustomerGroupsFromFirestoreToLocal() async {
    try {
      final snapshot = await _customerGroupsCollection.get();
      final groups = snapshot.docs
          .map((doc) => CustomerGroupModel.fromFirestore(doc.data(), doc.id))
          .toList();
      for (final g in groups) {
        await _localDb.addCustomerGroup(g);
      }
      if (kDebugMode && groups.isNotEmpty) {
        debugPrint('✅ Synced ${groups.length} customer groups from Firestore to SQLite');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error syncing customer groups Firestore->SQLite: $e');
      }
    }
  }

  /// Lấy từ Firestore theo ID
  Future<CustomerGroupModel?> _getCustomerGroupByIdFromFirestore(String id) async {
    try {
      final doc = await _customerGroupsCollection.doc(id).get();
      if (doc.exists && doc.data() != null) {
        return CustomerGroupModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting customer group from Firestore: $e');
      }
      return null;
    }
  }

  /// Thêm nhóm khách hàng
  /// CHIẾN LƯỢC: Cập nhật SQLite trước, sau đó push lên Firestore (Write once)
  Future<String> addCustomerGroup(CustomerGroupModel group) async {
    // Trên web, chỉ dùng Firestore
    if (kIsWeb) {
      return await _addCustomerGroupToFirestore(group);
    }

    // TẤT CẢ: Luôn cập nhật SQLite trước (offline-first)
    await _localDb.addCustomerGroup(group);

    // PRO: Sau đó push lên Firestore (write once)
    if (isPro) {
      try {
        await _addCustomerGroupToFirestore(group);
        if (kDebugMode) {
          debugPrint('✅ Customer group added to SQLite and Firestore: ${group.id}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error adding to Firestore, kept in SQLite: $e');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Customer group added to SQLite only (BASIC package): ${group.id}');
      }
    }

    return group.id;
  }

  /// Thêm nhóm khách hàng vào Firestore
  Future<String> _addCustomerGroupToFirestore(CustomerGroupModel group) async {
    try {
      final docRef = _customerGroupsCollection.doc(group.id);
      await docRef.set(group.toFirestore());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding customer group to Firestore: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật nhóm khách hàng
  Future<int> updateCustomerGroup(CustomerGroupModel group) async {
    if (kIsWeb) {
      return await _updateCustomerGroupInFirestore(group);
    }

    await _localDb.updateCustomerGroup(group);

    if (isPro) {
      try {
        await _updateCustomerGroupInFirestore(group);
        if (kDebugMode) {
          debugPrint('✅ Customer group updated in SQLite and Firestore: ${group.id}');
        }
        return 1;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error updating Firestore, kept in SQLite: $e');
        }
        return 1;
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Customer group updated in SQLite only (BASIC package): ${group.id}');
      }
      return 1;
    }
  }

  /// Cập nhật nhóm khách hàng trong Firestore
  Future<int> _updateCustomerGroupInFirestore(CustomerGroupModel group) async {
    try {
      await _customerGroupsCollection.doc(group.id).update(group.toFirestore());
      return 1;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating customer group in Firestore: $e');
      }
      rethrow;
    }
  }

  /// Xóa nhóm khách hàng
  Future<int> deleteCustomerGroup(String id) async {
    if (kIsWeb) {
      return await _deleteCustomerGroupFromFirestore(id);
    }

    await _localDb.deleteCustomerGroup(id);

    if (isPro) {
      try {
        await _deleteCustomerGroupFromFirestore(id);
        if (kDebugMode) {
          debugPrint('✅ Customer group deleted in SQLite and Firestore: $id');
        }
        return 1;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error deleting from Firestore, kept in SQLite: $e');
        }
        return 1;
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Customer group deleted in SQLite only (BASIC package): $id');
      }
      return 1;
    }
  }

  /// Xóa nhóm khách hàng từ Firestore
  Future<int> _deleteCustomerGroupFromFirestore(String id) async {
    try {
      await _customerGroupsCollection.doc(id).delete();
      return 1;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting customer group from Firestore: $e');
      }
      rethrow;
    }
  }

  // ==================== CUSTOMERS ====================

  /// Lấy tất cả khách hàng
  /// CHỈ ĐỌC TỪ SQLITE để tiết kiệm chi phí Firebase.
  /// PRO + không web: nếu SQLite trống thì đồng bộ từ Firestore (dữ liệu mẫu sau đăng ký).
  Future<List<CustomerModel>> getCustomers() async {
    if (kIsWeb) {
      return await _getCustomersFromFirestore();
    }

    if (isPro) {
      final local = await _localDb.getCustomers();
      if (local.isEmpty) {
        await _syncCustomersFromFirestoreToLocal();
        return await _localDb.getCustomers();
      }
      return local;
    }
    return await _localDb.getCustomers();
  }

  /// Lấy khách hàng theo ID
  Future<CustomerModel?> getCustomerById(String id) async {
    if (kIsWeb) {
      return await _getCustomerByIdFromFirestore(id);
    }

    return await _localDb.getCustomerById(id);
  }

  /// Tìm kiếm khách hàng
  /// PRO + không web: nếu SQLite trống thì đồng bộ từ Firestore trước (để tìm được dữ liệu mẫu).
  Future<List<CustomerModel>> searchCustomers(String query) async {
    if (kIsWeb) {
      return await _searchCustomersFromFirestore(query);
    }

    if (isPro) {
      final local = await _localDb.getCustomers();
      if (local.isEmpty) {
        await _syncCustomersFromFirestoreToLocal();
      }
    }
    return await _localDb.searchCustomers(query);
  }

  /// Lấy từ Firestore
  Future<List<CustomerModel>> _getCustomersFromFirestore() async {
    try {
      final snapshot = await _customersCollection.orderBy('name').get();
      return snapshot.docs
          .map((doc) => CustomerModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting customers from Firestore: $e');
      }
      return [];
    }
  }

  /// Đồng bộ khách hàng từ Firestore xuống SQLite (PRO, lần đầu sau đăng ký).
  /// Đồng bộ nhóm khách hàng trước để getCustomerGroupById hoạt động khi áp dụng chiết khấu.
  Future<void> _syncCustomersFromFirestoreToLocal() async {
    try {
      await _syncCustomerGroupsFromFirestoreToLocal();
      final snapshot = await _customersCollection.get();
      final customers = snapshot.docs
          .map((doc) => CustomerModel.fromFirestore(doc.data(), doc.id))
          .toList();
      for (final c in customers) {
        await _localDb.addCustomer(c);
      }
      if (kDebugMode && customers.isNotEmpty) {
        debugPrint('✅ Synced ${customers.length} customers from Firestore to SQLite');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error syncing customers Firestore->SQLite: $e');
      }
    }
  }

  /// Lấy từ Firestore theo ID
  Future<CustomerModel?> _getCustomerByIdFromFirestore(String id) async {
    try {
      final doc = await _customersCollection.doc(id).get();
      if (doc.exists && doc.data() != null) {
        return CustomerModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting customer from Firestore: $e');
      }
      return null;
    }
  }

  /// Tìm kiếm từ Firestore
  Future<List<CustomerModel>> _searchCustomersFromFirestore(String query) async {
    try {
      // Firestore không hỗ trợ full-text search tốt, nên ta sẽ lấy tất cả rồi filter
      final snapshot = await _customersCollection.orderBy('name').get();
      final allCustomers = snapshot.docs
          .map((doc) => CustomerModel.fromFirestore(doc.data(), doc.id))
          .toList();

      final queryLower = query.toLowerCase();
      return allCustomers.where((customer) {
        return customer.name.toLowerCase().contains(queryLower) ||
            customer.phone.contains(query);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error searching customers from Firestore: $e');
      }
      return [];
    }
  }

  /// Thêm khách hàng
  /// CHIẾN LƯỢC: Cập nhật SQLite trước, sau đó push lên Firestore (Write once)
  Future<String> addCustomer(CustomerModel customer) async {
    if (kIsWeb) {
      return await _addCustomerToFirestore(customer);
    }

    await _localDb.addCustomer(customer);

    if (isPro) {
      try {
        await _addCustomerToFirestore(customer);
        if (kDebugMode) {
          debugPrint('✅ Customer added to SQLite and Firestore: ${customer.id}');
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error adding to Firestore, kept in SQLite: $e');
        }
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Customer added to SQLite only (BASIC package): ${customer.id}');
      }
    }

    return customer.id;
  }

  /// Thêm khách hàng vào Firestore
  Future<String> _addCustomerToFirestore(CustomerModel customer) async {
    try {
      final docRef = _customersCollection.doc(customer.id);
      await docRef.set(customer.toFirestore());
      return docRef.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding customer to Firestore: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật khách hàng
  Future<int> updateCustomer(CustomerModel customer) async {
    if (kIsWeb) {
      return await _updateCustomerInFirestore(customer);
    }

    await _localDb.updateCustomer(customer);

    if (isPro) {
      try {
        await _updateCustomerInFirestore(customer);
        if (kDebugMode) {
          debugPrint('✅ Customer updated in SQLite and Firestore: ${customer.id}');
        }
        return 1;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error updating Firestore, kept in SQLite: $e');
        }
        return 1;
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Customer updated in SQLite only (BASIC package): ${customer.id}');
      }
      return 1;
    }
  }

  /// Cập nhật khách hàng trong Firestore
  Future<int> _updateCustomerInFirestore(CustomerModel customer) async {
    try {
      await _customersCollection.doc(customer.id).update(customer.toFirestore());
      return 1;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating customer in Firestore: $e');
      }
      rethrow;
    }
  }

  /// Xóa khách hàng
  Future<int> deleteCustomer(String id) async {
    if (kIsWeb) {
      return await _deleteCustomerFromFirestore(id);
    }

    await _localDb.deleteCustomer(id);

    if (isPro) {
      try {
        await _deleteCustomerFromFirestore(id);
        if (kDebugMode) {
          debugPrint('✅ Customer deleted in SQLite and Firestore: $id');
        }
        return 1;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('⚠️ Error deleting from Firestore, kept in SQLite: $e');
        }
        return 1;
      }
    } else {
      if (kDebugMode) {
        debugPrint('✅ Customer deleted in SQLite only (BASIC package): $id');
      }
      return 1;
    }
  }

  /// Xóa khách hàng từ Firestore
  Future<int> _deleteCustomerFromFirestore(String id) async {
    try {
      await _customersCollection.doc(id).delete();
      return 1;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting customer from Firestore: $e');
      }
      rethrow;
    }
  }
}
