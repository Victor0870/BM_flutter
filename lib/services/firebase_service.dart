import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/shop_model.dart';
import '../models/user_model.dart';

/// Service class để xử lý các thao tác với Firebase
/// Bao gồm Authentication và Firestore operations
class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Getters
  FirebaseAuth get auth => _auth;
  FirebaseFirestore get firestore => _firestore;

  /// Lấy thông tin shop từ Firestore
  Future<ShopModel?> getShopData(String shopId) async {
    try {
      final doc = await _firestore.collection('shops').doc(shopId).get();
      if (doc.exists && doc.data() != null) {
        return ShopModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting shop data: $e');
      return null;
    }
  }

  /// Cập nhật trạng thái cho phép đăng ký nhân viên của shop
  Future<void> updateShopRegistrationStatus(String shopId, bool status) async {
    try {
      await _firestore.collection('shops').doc(shopId).update({
        'allowRegistration': status,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating shop registration status: $e');
      rethrow;
    }
  }

  /// Lưu thông tin shop vào Firestore
  Future<void> saveShopData(ShopModel shop) async {
    final data = shop.toFirestore();
    
    // Debug: In ra paymentConfig để kiểm tra
    if (data.containsKey('paymentConfig')) {
      if (data['paymentConfig'] != null) {
        debugPrint('💾 Saving paymentConfig to Firestore:');
        debugPrint('   ${data['paymentConfig']}');
        if (data['paymentConfig'] is Map) {
          final paymentMap = data['paymentConfig'] as Map;
          debugPrint('   Keys: ${paymentMap.keys.toList()}');
          debugPrint('   Values: ${paymentMap.values.toList()}');
        }
      } else {
        debugPrint('⚠️ paymentConfig is null in toFirestore()');
      }
    } else {
      debugPrint('⚠️ paymentConfig key is missing in toFirestore()');
    }
    
    try {
      final docRef = _firestore.collection('shops').doc(shop.id);
      
      // Kiểm tra document có tồn tại không
      final currentDoc = await docRef.get();
      
      if (currentDoc.exists) {
        // Document đã tồn tại - dùng update để cập nhật tất cả fields
        // Firestore update sẽ merge nested objects đúng cách
        await docRef.update(data);
        debugPrint('✅ Shop data updated successfully');
      } else {
        // Document chưa tồn tại - dùng set
        await docRef.set(data);
        debugPrint('✅ Shop data created successfully');
      }
      
      // Verify lại sau khi lưu để đảm bảo paymentConfig được lưu
      await Future.delayed(const Duration(milliseconds: 200));
      final verifyDoc = await docRef.get();
      if (verifyDoc.exists && verifyDoc.data() != null) {
        final verifyData = verifyDoc.data()!;
        if (verifyData.containsKey('paymentConfig')) {
          final savedPaymentConfig = verifyData['paymentConfig'];
          if (savedPaymentConfig != null) {
            debugPrint('✅ Verified paymentConfig in Firestore:');
            debugPrint('   $savedPaymentConfig');
            if (savedPaymentConfig is Map) {
              debugPrint('   Keys: ${savedPaymentConfig.keys.toList()}');
            }
          } else {
            debugPrint('❌ paymentConfig is null in Firestore after save!');
          }
        } else {
          debugPrint('❌ paymentConfig key NOT found in Firestore after save!');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error saving shop data: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Lấy thông tin user/nhân viên từ Firestore theo uid
  Future<UserModel?> getUserById(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserModel.fromFirestore(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  /// Lấy danh sách nhân viên chờ duyệt theo shopId
  Future<List<UserModel>> getPendingStaffByShopId(String shopId) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('shopId', isEqualTo: shopId)
          .where('role', isEqualTo: UserRole.staff.value)
          .where('isApproved', isEqualTo: false)
          .get();

      return querySnapshot.docs
          .map((doc) => UserModel.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error getting pending staff list: $e');
      return [];
    }
  }

  /// Cập nhật trạng thái phê duyệt cho nhân viên (chỉ nên gọi bởi Admin phía UI đã kiểm tra quyền)
  /// Có thể cập nhật workingBranchId khi phê duyệt hoặc điều chuyển nhân viên
  Future<void> updateStaffApprovalStatus({
    required String uid,
    required bool isApproved,
    String? workingBranchId, // Chi nhánh làm việc chính
  }) async {
    try {
      final updateData = <String, dynamic>{
        'isApproved': isApproved,
        'updatedAt': Timestamp.now(),
      };
      
      // Nếu có workingBranchId, thêm vào update
      if (workingBranchId != null && workingBranchId.isNotEmpty) {
        updateData['workingBranchId'] = workingBranchId;
        // Tự động thêm workingBranchId vào allowedBranchIds nếu chưa có
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (userDoc.exists && userDoc.data() != null) {
          final currentAllowedBranchIds = userDoc.data()!['allowedBranchIds'] as List<dynamic>? ?? [];
          final allowedList = List<String>.from(currentAllowedBranchIds);
          if (!allowedList.contains(workingBranchId)) {
            allowedList.add(workingBranchId);
            updateData['allowedBranchIds'] = allowedList;
          }
        }
      }
      
      await _firestore.collection('users').doc(uid).update(updateData);
    } catch (e) {
      debugPrint('Error updating staff approval status: $e');
      rethrow;
    }
  }

  /// Cập nhật workingBranchId cho nhân viên (điều chuyển chi nhánh)
  Future<void> updateStaffWorkingBranch({
    required String uid,
    required String workingBranchId,
  }) async {
    try {
      // Lấy thông tin user hiện tại
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists || userDoc.data() == null) {
        throw Exception('User not found');
      }
      
      final currentAllowedBranchIds = userDoc.data()!['allowedBranchIds'] as List<dynamic>? ?? [];
      final allowedList = List<String>.from(currentAllowedBranchIds);
      
      // Đảm bảo workingBranchId có trong allowedBranchIds
      if (!allowedList.contains(workingBranchId)) {
        allowedList.add(workingBranchId);
      }
      
      await _firestore.collection('users').doc(uid).update({
        'workingBranchId': workingBranchId,
        'allowedBranchIds': allowedList,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error updating staff working branch: $e');
      rethrow;
    }
  }

  // Authentication methods sẽ được thêm vào đây khi cần
}

