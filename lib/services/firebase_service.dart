import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
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

  /// Tải logo cửa hàng lên Firebase Storage (shops/{shopId}/logo.jpg).
  /// Trả về URL download để lưu vào shop.logoUrl.
  Future<String> uploadShopLogo(String shopId, Uint8List imageBytes) async {
    final ref = FirebaseStorage.instance.ref('shops').child(shopId).child('logo.jpg');
    await ref.putData(
      imageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

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
    String? groupId, // Nhóm nhân viên (phân quyền)
  }) async {
    try {
      final updateData = <String, dynamic>{
        'isApproved': isApproved,
        'updatedAt': Timestamp.now(),
      };
      if (groupId != null) {
        updateData['groupId'] = groupId.isEmpty ? null : groupId;
      }
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

  /// Parse file Excel và lưu **nội dung** (sheets, cột, dòng) lên Firestore bằng WriteBatch.
  /// Cấu trúc: shops/{shopId}/kiotVietData/meta (uploadedAt, sheetNames),
  ///           shops/{shopId}/kiotVietData/{sheetIndex} (sheetName, columnNames, rowCount),
  ///           shops/{shopId}/kiotVietData/{sheetIndex}/rows/{rowIndex} (index, cells).
  /// Có thể gọi lại để cập nhật (ghi đè).
  Future<void> saveKiotVietExcelContentToFirestore(String shopId, Uint8List bytes) async {
    final excel = Excel.decodeBytes(bytes);
    if (excel.sheets.isEmpty) {
      throw Exception('File Excel không có sheet nào');
    }

    final sheetNames = excel.sheets.keys.toList();
    final now = Timestamp.now();
    final baseRef = _firestore.collection('shops').doc(shopId).collection('kiotVietData');

    const int maxBatchSize = 500;
    WriteBatch batch = _firestore.batch();
    int opCount = 0;

    Future<void> maybeCommit() async {
      if (opCount >= maxBatchSize) {
        await batch.commit();
        batch = _firestore.batch();
        opCount = 0;
      }
    }

    // Meta
    batch.set(baseRef.doc('meta'), {
      'uploadedAt': now,
      'sheetNames': sheetNames,
      'fileName': 'Data base danganh.xlsx',
    });
    opCount++;

    for (var s = 0; s < sheetNames.length; s++) {
      final sheetName = sheetNames[s];
      final sheet = excel.sheets[sheetName]!;
      final rows = sheet.rows;
      if (rows.isEmpty) {
        batch.set(baseRef.doc('$s'), {
          'sheetName': sheetName,
          'columnNames': <String>[],
          'rowCount': 0,
        });
        opCount++;
        await maybeCommit();
        continue;
      }

      final headerRow = rows[0];
      final columnNames = <String>[];
      for (var c = 0; c < headerRow.length; c++) {
        final label = _excelCellToStr(headerRow[c]);
        columnNames.add(label.isEmpty ? 'C$c' : label);
      }

      final rowCount = rows.length - 1; // bỏ dòng header
      batch.set(baseRef.doc('$s'), {
        'sheetName': sheetName,
        'columnNames': columnNames,
        'rowCount': rowCount,
      });
      opCount++;
      await maybeCommit();

      for (var r = 1; r < rows.length; r++) {
        final row = rows[r];
        final cells = <String, String>{};
        for (var c = 0; c < columnNames.length; c++) {
          final colName = columnNames[c];
          final key = colName.replaceAll('.', '_');
          cells[key] = c < row.length ? _excelCellToStr(row[c]) : '';
        }
        batch.set(baseRef.doc('$s').collection('rows').doc('${r - 1}'), {
          'index': r - 1,
          'cells': cells,
        });
        opCount++;
        await maybeCommit();
      }
    }

    if (opCount > 0) await batch.commit();
  }

  static String _excelCellToStr(Data? cell) {
    if (cell == null) return '';
    final v = cell.value;
    if (v == null) return '';
    if (v is TextCellValue) return v.value.text ?? v.value.toString();
    if (v is IntCellValue) return '${v.value}';
    if (v is DoubleCellValue) return '${v.value}';
    if (v is BoolCellValue) return v.value ? '1' : '0';
    if (v is DateCellValue) {
      return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}';
    }
    if (v is DateTimeCellValue) {
      return '${v.year}-${v.month.toString().padLeft(2, '0')}-${v.day.toString().padLeft(2, '0')}'
          'T${v.hour.toString().padLeft(2, '0')}:${v.minute.toString().padLeft(2, '0')}:00';
    }
    return v.toString();
  }

  /// Lấy metadata nội dung Excel KiotViet đã lưu (nếu có). Đọc từ kiotVietData/meta.
  Future<Map<String, dynamic>?> getKiotVietFileMeta(String shopId) async {
    try {
      final doc = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('kiotVietData')
          .doc('meta')
          .get();
      if (doc.exists && doc.data() != null) return doc.data();
      return null;
    } catch (e) {
      debugPrint('Error getting KiotViet data meta: $e');
      return null;
    }
  }

  /// Lấy thông tin sheet (columnNames, rowCount) cho màn bảng. sheetIndex thường là "0".
  Future<Map<String, dynamic>?> getKiotVietDataSheet(String shopId, String sheetIndex) async {
    try {
      final doc = await _firestore
          .collection('shops')
          .doc(shopId)
          .collection('kiotVietData')
          .doc(sheetIndex)
          .get();
      if (doc.exists && doc.data() != null) return doc.data();
      return null;
    } catch (e) {
      debugPrint('Error getting KiotViet sheet: $e');
      return null;
    }
  }

  /// Lấy một trang dòng (phân trang). startAfterDoc null = trang đầu.
  /// Trả về danh sách rows và lastDoc để gọi trang tiếp.
  Future<({List<Map<String, dynamic>> rows, DocumentSnapshot? lastDoc})> getKiotVietDataRows(
    String shopId,
    String sheetIndex, {
    int limit = 100,
    DocumentSnapshot? startAfterDoc,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _firestore
          .collection('shops')
          .doc(shopId)
          .collection('kiotVietData')
          .doc(sheetIndex)
          .collection('rows')
          .orderBy('index')
          .limit(limit);
      if (startAfterDoc != null) {
        q = q.startAfterDocument(startAfterDoc);
      }
      final snap = await q.get();
      final rows = snap.docs
          .map<Map<String, dynamic>>((d) => {'id': d.id, ...d.data()})
          .toList();
      final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      return (rows: rows, lastDoc: lastDoc);
    } catch (e) {
      debugPrint('Error getting KiotViet rows: $e');
      return (rows: <Map<String, dynamic>>[], lastDoc: null);
    }
  }

  /// Lấy toàn bộ dòng (theo lô) để tìm kiếm client-side. Mỗi lô tối đa [batchSize].
  Future<List<Map<String, dynamic>>> getKiotVietDataRowsAll(
    String shopId,
    String sheetIndex, {
    int batchSize = 500,
  }) async {
    final result = <Map<String, dynamic>>[];
    DocumentSnapshot? lastDoc;
    while (true) {
      final page = await getKiotVietDataRows(
        shopId,
        sheetIndex,
        limit: batchSize,
        startAfterDoc: lastDoc,
      );
      result.addAll(page.rows);
      if (page.rows.length < batchSize || page.lastDoc == null) break;
      lastDoc = page.lastDoc;
    }
    return result;
  }

  /// Lấy một trang document từ global_parts_catalog (để tải về local, không cần Firestore khi tra cứu).
  /// Mỗi doc: { id, cells }. Trả về (rows, lastDoc) để gọi trang tiếp.
  Future<({List<Map<String, dynamic>> rows, DocumentSnapshot? lastDoc})> getGlobalPartsCatalogBatch({
    int limit = 500,
    DocumentSnapshot? startAfterDoc,
  }) async {
    try {
      Query<Map<String, dynamic>> q = _firestore
          .collection('global_parts_catalog')
          .orderBy(FieldPath.documentId)
          .limit(limit);
      if (startAfterDoc != null) {
        q = q.startAfterDocument(startAfterDoc);
      }
      final snap = await q.get();
      final rows = snap.docs
          .map<Map<String, dynamic>>((d) => {
                'id': d.id,
                'cells': d.data()['cells'] ?? {},
              })
          .toList();
      final lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      return (rows: rows, lastDoc: lastDoc);
    } catch (e) {
      debugPrint('Error getting global_parts_catalog batch: $e');
      return (rows: <Map<String, dynamic>>[], lastDoc: null);
    }
  }

  /// Cập nhật một document trong global_parts_catalog. [id] giữ nguyên (ghi đè đúng doc).
  /// [data] thường là { 'cells': Map }. Tự thêm lastUpdated (server timestamp) làm dấu vết để đồng bộ sau.
  Future<void> updateGlobalPart(String id, Map<String, dynamic> data) async {
    if (id.isEmpty) throw ArgumentError('id must not be empty');
    try {
      final dataToUpdate = Map<String, dynamic>.from(data);
      dataToUpdate['lastUpdated'] = FieldValue.serverTimestamp();
      await _firestore.collection('global_parts_catalog').doc(id).update(dataToUpdate);
    } catch (e) {
      debugPrint('Error updateGlobalPart $id: $e');
      rethrow;
    }
  }

  /// Lấy toàn bộ global_parts_catalog từ Firestore, lọc theo [tenXe], [doiXe], [chungLoai] (LIKE trong cells).
  /// Mỗi phần tử: { id, cells }. Dùng cho màn Bảng dữ liệu.
  Future<List<Map<String, dynamic>>> getGlobalPartsCatalogFiltered({
    String? tenXe,
    String? doiXe,
    String? chungLoai,
  }) async {
    final result = <Map<String, dynamic>>[];
    DocumentSnapshot? lastDoc;
    const batchSize = 500;
    while (true) {
      final page = await getGlobalPartsCatalogBatch(limit: batchSize, startAfterDoc: lastDoc);
      for (final row in page.rows) {
        final cells = row['cells'] as Map<String, dynamic>? ?? {};
        final ten = _cellValue(cells, 'Tên Xe');
        final doi = _cellValue(cells, 'Đời Xe');
        final chung = _cellValue(cells, 'Chủng loại');
        if (tenXe != null && tenXe.trim().isNotEmpty && !ten.toLowerCase().contains(tenXe.trim().toLowerCase())) continue;
        if (doiXe != null && doiXe.trim().isNotEmpty && !doi.toLowerCase().contains(doiXe.trim().toLowerCase())) continue;
        if (chungLoai != null && chungLoai.trim().isNotEmpty && !chung.toLowerCase().contains(chungLoai.trim().toLowerCase())) continue;
        result.add(row);
      }
      if (page.rows.length < batchSize || page.lastDoc == null) break;
      lastDoc = page.lastDoc;
    }
    return result;
  }

  static String _cellValue(Map<String, dynamic> cells, String key) {
    final v = cells[key] ?? cells[key.replaceAll(' ', '_')];
    return v?.toString().trim() ?? '';
  }

  /// Lấy trạng thái môi trường test từ Firestore system_settings/isTest.
  /// Document: { "value": true|false } hoặc { "isTest": true|false }.
  /// - Dùng cho FPT eInvoice (URL UAT khi true).
  /// - Dùng cho AdMob: isTest true → hiện quảng cáo với tất cả tài khoản (kiểm thử);
  ///   isTest false → chỉ hiện quảng cáo ở tài khoản free (!isPro).
  Future<bool> getIsTestMode() async {
    try {
      final doc = await _firestore
          .collection('system_settings')
          .doc('isTest')
          .get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final value = data['value'] ?? data['isTest'];
        if (value is bool) return value;
        if (value is bool?) return value ?? false;
      }
      return false; // Mặc định production
    } catch (e) {
      debugPrint('Error getting isTest from system_settings: $e');
      return false;
    }
  }

  // Authentication methods sẽ được thêm vào đây khi cần
}

