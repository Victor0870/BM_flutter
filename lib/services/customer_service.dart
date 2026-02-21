import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Lấy tất cả nhóm khách hàng.
  /// - Web: luôn đọc từ Firestore.
  /// - PRO (app): mỗi lần load đồng bộ từ Firestore xuống SQLite rồi trả về (đồng bộ đa thiết bị).
  /// - BASIC: chỉ đọc từ SQLite.
  Future<List<CustomerGroupModel>> getCustomerGroups() async {
    if (kIsWeb) {
      return await _getCustomerGroupsFromFirestore();
    }

    if (isPro) {
      await _syncCustomerGroupsFromFirestoreToLocal();
      return await _localDb.getCustomerGroups();
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
  /// Lấy danh sách khách hàng.
  /// - Web: luôn đọc từ Firestore (đồng bộ đa thiết bị).
  /// - PRO (app): mỗi lần load đều kéo Firestore về SQLite rồi trả về (đồng bộ khi đăng nhập máy khác / mobile).
  /// - BASIC: chỉ đọc từ SQLite.
  Future<List<CustomerModel>> getCustomers() async {
    if (kIsWeb) {
      return await _getCustomersFromFirestore();
    }

    if (isPro) {
      await _syncCustomersFromFirestoreToLocal();
      return await _localDb.getCustomers();
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

  static const String _keyLastSyncCustomers = 'last_sync_customers';

  /// Đồng bộ tăng dần: chỉ lấy customer có updatedAt > lastSync, merge vào SQLite. Giảm lượt đọc.
  Future<void> syncIncrementalFromCloud() async {
    if (kIsWeb || !isPro) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyLastSyncCustomers}_$userId';
      final lastMs = prefs.getInt(key);

      final List<CustomerModel> customers;
      if (lastMs == null) {
        final snapshot = await _customersCollection.get();
        customers = snapshot.docs
            .map((doc) => CustomerModel.fromFirestore(doc.data(), doc.id))
            .toList();
      } else {
        final lastSync = DateTime.fromMillisecondsSinceEpoch(lastMs);
        final snapshot = await _customersCollection
            .where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSync))
            .orderBy('updatedAt')
            .get();
        customers = snapshot.docs
            .map((doc) => CustomerModel.fromFirestore(doc.data(), doc.id))
            .toList();
      }

      for (final c in customers) {
        await _localDb.addCustomer(c);
      }
      await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
      if (kDebugMode && customers.isNotEmpty) {
        debugPrint('✅ Incremental sync customers: ${customers.length} docs');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ syncIncrementalFromCloud (customers): $e');
    }
  }

  /// Đồng bộ khách hàng từ Firestore xuống SQLite (PRO).
  /// Dùng incremental nếu đã có lastSync; lần đầu dùng full sync.
  Future<void> _syncCustomersFromFirestoreToLocal() async {
    try {
      await _syncCustomerGroupsFromFirestoreToLocal();
      final prefs = await SharedPreferences.getInstance();
      final key = '${_keyLastSyncCustomers}_$userId';
      final lastMs = prefs.getInt(key);
      final lastSync = lastMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastMs)
          : null;

      if (lastSync == null) {
        final snapshot = await _customersCollection.get();
        final customers = snapshot.docs
            .map((doc) => CustomerModel.fromFirestore(doc.data(), doc.id))
            .toList();
        for (final c in customers) {
          await _localDb.addCustomer(c);
        }
        await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
        if (kDebugMode && customers.isNotEmpty) {
          debugPrint('✅ Synced ${customers.length} customers from Firestore to SQLite (full)');
        }
      } else {
        final query = _customersCollection
            .where('updatedAt', isGreaterThan: Timestamp.fromDate(lastSync))
            .orderBy('updatedAt');
        final snapshot = await query.get();
        final customers = snapshot.docs
            .map((doc) => CustomerModel.fromFirestore(doc.data(), doc.id))
            .toList();
        for (final c in customers) {
          await _localDb.addCustomer(c);
        }
        await prefs.setInt(key, DateTime.now().millisecondsSinceEpoch);
        if (kDebugMode && customers.isNotEmpty) {
          debugPrint('✅ Synced ${customers.length} customers (incremental)');
        }
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

  /// Giới hạn 500 thao tác/batch theo Firestore.
  static const int _firestoreBatchLimit = 500;

  /// Thêm hàng loạt khách hàng: SQLite batch + Firestore WriteBatch (tối đa 500/batch).
  Future<void> addCustomersBatch(List<CustomerModel> customers, {void Function(double)? onProgress}) async {
    if (customers.isEmpty) return;

    final doFirestore = kIsWeb || isPro;
    if (!kIsWeb) {
      await _localDb.addCustomersBatch(customers);
      if (onProgress != null && !doFirestore) onProgress(1.0);
    }

    if (doFirestore) {
      final total = customers.length;
      var done = 0;
      for (var start = 0; start < total; start += _firestoreBatchLimit) {
        final end = (start + _firestoreBatchLimit < total) ? start + _firestoreBatchLimit : total;
        final batch = _firestore.batch();
        for (var i = start; i < end; i++) {
          final c = customers[i];
          batch.set(_customersCollection.doc(c.id), c.toFirestore());
        }
        await batch.commit();
        done = end;
        if (onProgress != null) onProgress(done / total);
      }
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
