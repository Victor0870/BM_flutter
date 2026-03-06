import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter/services.dart';

import 'firebase_service.dart';
import 'local_db_service.dart';

/// Đồng bộ dữ liệu KiotViet:
/// - assets/kiotviet2.xlsx: chỉ 2 cột (Product code, product name), chỉ ở local → bảng tra tên + màn Data gốc.
/// - Data base danganh.xlsx: nhiều cột, có trên Firestore → tải xuống local (kiot_viet_data) khi chưa có → dùng cho Tra cứu.
class KiotVietSyncService {
  static final KiotVietSyncService _instance = KiotVietSyncService._internal();
  factory KiotVietSyncService() => _instance;
  KiotVietSyncService._internal();

  final FirebaseService _firebase = FirebaseService();
  final LocalDbService _local = LocalDbService();

  /// Tên cột Excel tương ứng với ô lọc (cells key có thể có dấu cách hoặc _).
  static String _cell(Map<String, dynamic>? cells, String name) {
    if (cells == null) return '';
    final v = cells[name] ?? cells[name.replaceAll(' ', '_')];
    return v?.toString() ?? '';
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

  /// Tìm chỉ số cột theo tên (thử nhiều biến thể: có dấu cách, gạch dưới).
  static int _columnIndex(List<String> columnNames, List<String> possibleLabels) {
    final normalized = possibleLabels.map((l) => l.trim().toLowerCase().replaceAll(' ', '_')).toList();
    for (var i = 0; i < columnNames.length; i++) {
      final n = columnNames[i].trim().toLowerCase().replaceAll(' ', '_');
      if (normalized.contains(n)) return i;
    }
    return -1;
  }

  /// Import file assets/kiotviet2.xlsx (chỉ 2 cột: Product code, product name) vào local.
  /// Dùng cho: (1) bảng tra tên trong Tra cứu, (2) màn Data gốc để kiểm tra product code.
  /// Không ghi vào kiot_viet_data (data nhiều cột là danganh từ Firestore).
  Future<bool> importFromBundledAsset(String shopId) async {
    if (kIsWeb) return false;
    try {
      final bytes = await rootBundle.load('assets/kiotviet2.xlsx');
      final data = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
      final excel = Excel.decodeBytes(data);
      if (excel.sheets.isEmpty) return false;

      final productCodeToName = <String, String>{};
      final bundleRows = <Map<String, dynamic>>[];
      int globalIndex = 0;

      for (final sheetName in excel.sheets.keys) {
        final sheet = excel.sheets[sheetName]!;
        final rows = sheet.rows;
        if (rows.isEmpty) continue;

        final headerRow = rows[0];
        final columnNames = <String>[];
        for (var c = 0; c < headerRow.length; c++) {
          columnNames.add(_excelCellToStr(headerRow[c]).isEmpty ? 'C$c' : _excelCellToStr(headerRow[c]));
        }

        final idxProductCode = _columnIndex(columnNames, [
          'productCode', 'Productcode', 'Product code', 'Mã chéo', 'Ma cheo',
          'Mã sản phẩm', 'Ma san pham', 'Code', 'CODE', 'Mã code',
        ]);
        final idxProductName = _columnIndex(columnNames, [
          'productName', 'Product name', 'Tên sản phẩm', 'Tên san pham', 'Ten san pham',
        ]);

        for (var r = 1; r < rows.length; r++) {
          final row = rows[r];
          final code = (idxProductCode >= 0 && idxProductCode < row.length
                  ? _excelCellToStr(row[idxProductCode])
                  : '')
              .trim();
          final name = idxProductName >= 0 && idxProductName < row.length
              ? _excelCellToStr(row[idxProductName])
              : '';
          if (code.isEmpty) continue;
          productCodeToName[code] = name;
          final cellsMap = <String, String>{
            'Product code': code,
            'product name': name,
          };
          bundleRows.add({
            'row_index': globalIndex++,
            'ten_xe': '',
            'doi_xe': '',
            'chung_loai': '',
            'ten_phu_tung': '',
            'cells': jsonEncode(cellsMap),
          });
        }
      }

      if (productCodeToName.isEmpty && bundleRows.isEmpty) return false;

      await _local.clearKiotVietProductLookup(shopId);
      await _local.clearKiotVietBundleData(shopId);
      if (bundleRows.isNotEmpty) {
        const batchSize = 500;
        for (var i = 0; i < bundleRows.length; i += batchSize) {
          final end = (i + batchSize < bundleRows.length) ? i + batchSize : bundleRows.length;
          await _local.insertKiotVietBundleRows(shopId, bundleRows.sublist(i, end));
        }
      }
      await _local.setProductNameLookup(shopId, productCodeToName);
      if (kDebugMode) {
        debugPrint('KiotVietSync: đã import ${bundleRows.length} dòng (2 cột), ${productCodeToName.length} mã từ assets/kiotviet2.xlsx');
      }
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('KiotVietSync importFromBundledAsset: $e');
      return false;
    }
  }

  /// Đảm bảo đã nạp assets/kiotviet2.xlsx (2 cột: Product code, product name) vào local.
  /// Chỉ import khi chưa có bundle data cho shop.
  Future<void> ensureInitialDataFromBundle(String shopId) async {
    if (kIsWeb) return;
    try {
      final hasBundle = await _local.hasKiotVietBundleData(shopId);
      if (hasBundle) return;
      final ok = await importFromBundledAsset(shopId);
      if (kDebugMode && ok) {
        debugPrint('KiotVietSync: đã nạp assets/kiotviet2.xlsx (2 cột) cho shop $shopId');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('KiotVietSync ensureInitialDataFromBundle: $e');
    }
  }

  /// Ép nạp lại từ assets/kiotviet2.xlsx (xóa data cũ rồi import). Dùng khi user đã thay file trong assets và cần refresh "Data gốc".
  Future<bool> forceImportFromBundle(String shopId) async {
    if (kIsWeb) return false;
    return importFromBundledAsset(shopId);
  }

  /// Tải Data base danganh từ Firestore xuống local (kiot_viet_data) khi local chưa có.
  /// Dữ liệu nhiều cột dùng cho Tra cứu.
  Future<bool> syncDanganhFromFirestore(String shopId) async {
    if (kIsWeb) return false;
    try {
      final sheet = await _firebase.getKiotVietDataSheet(shopId, '0');
      if (sheet == null) return false;
      final rows = await _firebase.getKiotVietDataRowsAll(shopId, '0');
      if (rows.isEmpty) return false;

      final toInsert = <Map<String, dynamic>>[];
      for (final row in rows) {
        final cells = row['cells'] is Map ? Map<String, dynamic>.from(row['cells'] as Map) : <String, dynamic>{};
        final idx = row['index'] is int ? row['index'] as int : toInsert.length;
        final tenXe = _cell(cells, 'Tên Xe');
        final doiXe = _cell(cells, 'Đời Xe');
        final chungLoai = _cell(cells, 'Chủng loại');
        final tenPhuTung = _cell(cells, 'Tên Phụ Tùng');
        toInsert.add({
          'row_index': idx,
          'ten_xe': tenXe,
          'doi_xe': doiXe,
          'chung_loai': chungLoai,
          'ten_phu_tung': tenPhuTung,
          'cells': jsonEncode(cells),
        });
      }

      await _local.clearKiotVietData(shopId);
      const batchSize = 500;
      for (var i = 0; i < toInsert.length; i += batchSize) {
        final end = (i + batchSize < toInsert.length) ? i + batchSize : toInsert.length;
        await _local.insertKiotVietRows(shopId, toInsert.sublist(i, end));
      }
      await _local.setKiotVietLastUpdate(shopId, DateTime.now().toUtc().toIso8601String());
      if (kDebugMode) debugPrint('KiotVietSync: đã tải ${toInsert.length} dòng danganh từ Firestore');
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('KiotVietSync syncDanganhFromFirestore: $e');
      return false;
    }
  }

  /// Chạy đồng bộ (gọi sau khi đăng nhập, không chặn UI). Chỉ chạy khi !kIsWeb.
  /// (1) Nạp kiotviet2.xlsx (2 cột) nếu chưa có. (2) Tải danganh từ Firestore xuống local nếu chưa có.
  Future<void> syncIfNeeded(String shopId) async {
    if (kIsWeb) return;
    try {
      await ensureInitialDataFromBundle(shopId);
      final hasDanganh = await _local.hasKiotVietData(shopId);
      if (!hasDanganh) await syncDanganhFromFirestore(shopId);
    } catch (e) {
      if (kDebugMode) debugPrint('KiotVietSync error: $e');
    }
  }

  /// Đồng bộ global_parts_catalog từ Firestore xuống local (chạy sau khi đăng nhập nếu isKiotVietEnabled).
  /// Chỉ tải khi chưa có dữ liệu local; sau đó tra cứu chỉ dùng local, không cần Firestore.
  Future<void> syncGlobalPartsCatalogIfNeeded() async {
    if (kIsWeb) return;
    try {
      final hasLocal = await _local.hasGlobalPartsCatalogData();
      if (hasLocal) {
        if (kDebugMode) debugPrint('GlobalPartsCatalog: đã có dữ liệu local, bỏ qua tải');
        return;
      }
      if (kDebugMode) debugPrint('GlobalPartsCatalog: bắt đầu tải từ Firestore...');
      await _downloadAndSaveGlobalPartsCatalog();
    } catch (e) {
      if (kDebugMode) debugPrint('GlobalPartsCatalog sync error: $e');
    }
  }

  static String _cellGlobal(Map<String, dynamic>? cells, String name) {
    if (cells == null) return '';
    final v = cells[name] ?? cells[name.replaceAll(' ', '_')];
    return v?.toString() ?? '';
  }

  Future<void> _downloadAndSaveGlobalPartsCatalog() async {
    await _local.clearGlobalPartsCatalog();

    const batchSize = 500;
    DocumentSnapshot? lastDoc;
    int total = 0;

    while (true) {
      final page = await _firebase.getGlobalPartsCatalogBatch(
        limit: batchSize,
        startAfterDoc: lastDoc,
      );
      if (page.rows.isEmpty) break;

      final toInsert = <Map<String, dynamic>>[];
      for (final row in page.rows) {
        final cells = row['cells'] as Map<String, dynamic>? ?? {};
        final docId = row['id'] as String? ?? '';
        if (docId.isEmpty) continue;
        final tenXe = _cellGlobal(cells, 'Tên Xe');
        final doiXe = _cellGlobal(cells, 'Đời Xe');
        final chungLoai = _cellGlobal(cells, 'Chủng loại');
        final tenPhuTung = _cellGlobal(cells, 'Tên Phụ Tùng');
        toInsert.add({
          'row_id': docId,
          'ten_xe': tenXe,
          'doi_xe': doiXe,
          'chung_loai': chungLoai,
          'ten_phu_tung': tenPhuTung,
          'cells': jsonEncode(cells),
        });
      }
      if (toInsert.isNotEmpty) {
        await _local.insertGlobalPartsCatalogRows(toInsert);
        total += toInsert.length;
      }
      if (page.rows.length < batchSize || page.lastDoc == null) break;
      lastDoc = page.lastDoc;
    }

    await _local.setGlobalPartsCatalogSynced();
    if (kDebugMode) debugPrint('GlobalPartsCatalog: đã lưu $total dòng local');
  }
}
