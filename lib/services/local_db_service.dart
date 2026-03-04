import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../models/sales_return_model.dart';
import '../models/purchase_model.dart';
import '../models/branch_model.dart';
import '../models/customer_model.dart';
import '../models/customer_group_model.dart';
import '../models/stock_history_model.dart';

/// Service để quản lý database cục bộ bằng SQLite
/// Dùng cho gói BASIC (Offline mode)
/// Cache in-memory để tra cứu <100ms (tìm hàng, chọn biến thể).
class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  static Database? _database;

  /// Cache in-memory: ưu tiên tốc độ phản hồi UI (<100ms).
  static Map<String, ProductModel>? _productByIdCache;
  static Map<String, ProductModel>? _productByBarcodeCache;

  static void _invalidateProductCache() {
    _productByIdCache = null;
    _productByBarcodeCache = null;
  }

  static void _fillProductCaches(List<ProductModel> products) {
    _productByIdCache = { for (final p in products) p.id: p };
    _productByBarcodeCache = {};
    for (final p in products) {
      final b = p.barcode?.trim().toLowerCase();
      if (b != null && b.isNotEmpty) _productByBarcodeCache![b] = p;
    }
  }

  /// Lấy database instance (singleton)
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Khởi tạo database
  Future<Database> _initDatabase() async {
    // SQLite không hoạt động trên web
    if (kIsWeb) {
      throw UnsupportedError('SQLite không được hỗ trợ trên web. Vui lòng sử dụng mobile hoặc desktop app.');
    }

    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, 'products.db');

    final db = await openDatabase(
      path,
      version: 18, // 18: global_parts_catalog_data.last_updated (dấu vết sửa đổi để đồng bộ)
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Kiểm tra và tạo table purchases nếu chưa tồn tại (fix cho database cũ)
    await _ensurePurchasesTableExists(db);
    await _ensureAppPrefsTableExists(db);

    // Đảm bảo columns tồn tại (để xử lý trường hợp database đã tồn tại nhưng chưa migrate đúng)
    await _ensureSalesColumnsExist(db);
    await _ensureProductsColumnsExist(db);
    await _ensureBranchesTableExists(db);
    await _ensureBranchColumnsExist(db);
    await _ensureStockHistoryTableExists(db);
    await _ensureSalesReturnsTableExists(db);
    await _ensureKiotVietTablesExist(db);
    await _ensureGlobalPartsCatalogTablesExist(db);

    return db;
  }

  Future<void> _ensureGlobalPartsCatalogTablesExist(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS global_parts_catalog_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS global_parts_catalog_data (
        row_id TEXT PRIMARY KEY,
        ten_xe TEXT,
        doi_xe TEXT,
        chung_loai TEXT,
        ten_phu_tung TEXT,
        cells TEXT,
        last_updated TEXT
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_global_parts_ten_xe ON global_parts_catalog_data(ten_xe)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_global_parts_doi_xe ON global_parts_catalog_data(doi_xe)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_global_parts_chung_loai ON global_parts_catalog_data(chung_loai)');
  }

  Future<void> _ensureKiotVietTablesExist(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kiot_viet_meta (
        shop_id TEXT PRIMARY KEY,
        last_update TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kiot_viet_data (
        shop_id TEXT NOT NULL,
        row_index INTEGER NOT NULL,
        ten_xe TEXT,
        doi_xe TEXT,
        chung_loai TEXT,
        ten_phu_tung TEXT,
        cells TEXT,
        PRIMARY KEY (shop_id, row_index)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kiot_viet_product_lookup (
        shop_id TEXT NOT NULL,
        product_code TEXT NOT NULL,
        product_name TEXT,
        PRIMARY KEY (shop_id, product_code)
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_kiot_viet_ten_xe ON kiot_viet_data(shop_id, ten_xe)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_kiot_viet_doi_xe ON kiot_viet_data(shop_id, doi_xe)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_kiot_viet_chung_loai ON kiot_viet_data(shop_id, chung_loai)');
  }

  // ========== KIOT VIET DATA (tra cứu local, đồng bộ batch từ Firestore) ==========

  /// Lấy lastUpdate (ISO8601) của dữ liệu KiotViet local cho shop. Null nếu chưa có.
  Future<String?> getKiotVietLastUpdate(String shopId) async {
    try {
      final db = await database;
      final rows = await db.query(
        'kiot_viet_meta',
        where: 'shop_id = ?',
        whereArgs: [shopId],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['last_update'] as String?;
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getKiotVietLastUpdate: $e');
      return null;
    }
  }

  /// Lưu lastUpdate sau khi đồng bộ xong.
  Future<void> setKiotVietLastUpdate(String shopId, String lastUpdateIso8601) async {
    final db = await database;
    await db.insert(
      'kiot_viet_meta',
      {'shop_id': shopId, 'last_update': lastUpdateIso8601},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Kiểm tra đã có dữ liệu local chưa.
  Future<bool> hasKiotVietData(String shopId) async {
    try {
      final db = await database;
      final rows = await db.query(
        'kiot_viet_data',
        columns: ['row_index'],
        where: 'shop_id = ?',
        whereArgs: [shopId],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService hasKiotVietData: $e');
      return false;
    }
  }

  /// Xóa toàn bộ dữ liệu KiotViet của shop (trước khi ghi đè).
  Future<void> clearKiotVietData(String shopId) async {
    final db = await database;
    await db.delete('kiot_viet_data', where: 'shop_id = ?', whereArgs: [shopId]);
    await db.delete('kiot_viet_meta', where: 'shop_id = ?', whereArgs: [shopId]);
  }

  /// Xóa bảng tra tên sản phẩm (product code -> name) từ bundle asset.
  Future<void> clearKiotVietProductLookup(String shopId) async {
    final db = await database;
    await db.delete('kiot_viet_product_lookup', where: 'shop_id = ?', whereArgs: [shopId]);
  }

  /// Xóa dữ liệu bundle (kiot_viet_data) của shop, giữ nguyên meta.
  Future<void> clearKiotVietBundleData(String shopId) async {
    final db = await database;
    await db.delete('kiot_viet_data', where: 'shop_id = ?', whereArgs: [shopId]);
  }

  /// Chèn một lô dòng bundle (từ asset kiotviet2.xlsx). Format giống insertKiotVietRows.
  Future<void> insertKiotVietBundleRows(String shopId, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('kiot_viet_data', {
        'shop_id': shopId,
        'row_index': row['row_index'] as int,
        'ten_xe': row['ten_xe'] as String? ?? '',
        'doi_xe': row['doi_xe'] as String? ?? '',
        'chung_loai': row['chung_loai'] as String? ?? '',
        'ten_phu_tung': row['ten_phu_tung'] as String? ?? '',
        'cells': row['cells'] as String? ?? '{}',
      });
    }
    await batch.commit(noResult: true);
  }

  /// Lưu bảng tra tên sản phẩm (product code -> name) từ bundle asset.
  Future<void> setProductNameLookup(String shopId, Map<String, String> productCodeToName) async {
    if (productCodeToName.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final e in productCodeToName.entries) {
      batch.insert(
        'kiot_viet_product_lookup',
        {'shop_id': shopId, 'product_code': e.key, 'product_name': e.value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Kiểm tra đã có dữ liệu bundle (kiot_viet_data) cho shop chưa.
  Future<bool> hasKiotVietBundleData(String shopId) async {
    return hasKiotVietData(shopId);
  }

  /// Lấy bảng tra tên sản phẩm (product code -> name) cho shop.
  Future<Map<String, String>> getProductNameLookupMap(String shopId) async {
    try {
      final db = await database;
      final rows = await db.query(
        'kiot_viet_product_lookup',
        where: 'shop_id = ?',
        whereArgs: [shopId],
      );
      return {for (final r in rows) (r['product_code'] as String? ?? ''): (r['product_name'] as String? ?? '')};
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getProductNameLookupMap: $e');
      return {};
    }
  }

  /// Chèn một lô dòng. Mỗi row: map với keys ten_xe, doi_xe, chung_loai, ten_phu_tung, row_index, cells (JSON string).
  Future<void> insertKiotVietRows(String shopId, List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('kiot_viet_data', {
        'shop_id': shopId,
        'row_index': row['row_index'] as int,
        'ten_xe': row['ten_xe'] as String? ?? '',
        'doi_xe': row['doi_xe'] as String? ?? '',
        'chung_loai': row['chung_loai'] as String? ?? '',
        'ten_phu_tung': row['ten_phu_tung'] as String? ?? '',
        'cells': row['cells'] as String? ?? '{}',
      });
    }
    await batch.commit(noResult: true);
  }

  /// Tìm kiếm cục bộ theo 3 bộ lọc (LIKE %value%). Trả về danh sách map (row_index, ten_xe, doi_xe, chung_loai, ten_phu_tung, cells).
  Future<List<Map<String, dynamic>>> getKiotVietRowsFiltered(
    String shopId, {
    String? tenXe,
    String? namSanXuat,
    String? chungLoaiPhuTung,
  }) async {
    try {
      final db = await database;
      String? where = 'shop_id = ?';
      final args = <dynamic>[shopId];
      if (tenXe != null && tenXe.trim().isNotEmpty) {
        where += ' AND ten_xe LIKE ?';
        args.add('%${tenXe.trim()}%');
      }
      if (namSanXuat != null && namSanXuat.trim().isNotEmpty) {
        where += ' AND doi_xe LIKE ?';
        args.add('%${namSanXuat.trim()}%');
      }
      if (chungLoaiPhuTung != null && chungLoaiPhuTung.trim().isNotEmpty) {
        where += ' AND chung_loai LIKE ?';
        args.add('%${chungLoaiPhuTung.trim()}%');
      }
      final rows = await db.query(
        'kiot_viet_data',
        where: where,
        whereArgs: args,
        orderBy: 'row_index ASC',
      );
      return rows.map((m) => {
        'row_index': m['row_index'],
        'ten_xe': m['ten_xe'],
        'doi_xe': m['doi_xe'],
        'chung_loai': m['chung_loai'],
        'ten_phu_tung': m['ten_phu_tung'],
        'cells': m['cells'],
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getKiotVietRowsFiltered: $e');
      return [];
    }
  }

  /// Lấy toàn bộ dòng KiotViet từ local (để hiển thị bảng). cells trả về dạng Map (parse từ JSON).
  /// Format giống Firestore: [{ index, cells: Map }, ...].
  Future<List<Map<String, dynamic>>> getAllKiotVietRows(String shopId) async {
    try {
      final list = await getKiotVietRowsFiltered(shopId);
      return list.map((m) {
        final cellsStr = m['cells'] as String?;
        Map<String, dynamic> cells = {};
        if (cellsStr != null && cellsStr.isNotEmpty) {
          try {
            final decoded = jsonDecode(cellsStr);
            if (decoded is Map) cells = Map<String, dynamic>.from(decoded);
          } catch (_) {}
        }
        return <String, dynamic>{
          'index': m['row_index'] as int? ?? 0,
          'cells': cells,
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getAllKiotVietRows: $e');
      return [];
    }
  }

  /// Kiểm tra và thêm các columns còn thiếu vào bảng sales
  Future<void> _ensureSalesColumnsExist(Database db) async {
    try {
      // Kiểm tra paymentStatus column
      final result = await db.rawQuery("PRAGMA table_info(sales)");
      final columnNames = result.map((row) => row['name'] as String).toList();
      
      if (!columnNames.contains('paymentStatus')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN paymentStatus TEXT DEFAULT 'COMPLETED'
        ''');
      }
      
      if (!columnNames.contains('customerTaxCode')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN customerTaxCode TEXT
        ''');
      }
      
      if (!columnNames.contains('customerAddress')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN customerAddress TEXT
        ''');
      }
      
      if (!columnNames.contains('customerId')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN customerId TEXT
        ''');
      }
      
      if (!columnNames.contains('branchId')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN branchId TEXT DEFAULT ''
        ''');
      }
      
      if (!columnNames.contains('sellerId')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN sellerId TEXT
        ''');
      }
      
      if (!columnNames.contains('sellerName')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN sellerName TEXT
        ''');
      }
      
      if (!columnNames.contains('isStockUpdated')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN isStockUpdated INTEGER DEFAULT 0
        ''');
      }
      
      // Thêm các cột hóa đơn điện tử
      if (!columnNames.contains('totalBeforeDiscount')) {
        await db.execute('ALTER TABLE sales ADD COLUMN totalBeforeDiscount REAL');
      }
      if (!columnNames.contains('discountAmount')) {
        await db.execute('ALTER TABLE sales ADD COLUMN discountAmount REAL');
      }
      if (!columnNames.contains('subTotal')) {
        await db.execute('ALTER TABLE sales ADD COLUMN subTotal REAL');
      }
      if (!columnNames.contains('orderDiscountValue')) {
        await db.execute('ALTER TABLE sales ADD COLUMN orderDiscountValue REAL');
      }
      if (!columnNames.contains('orderDiscountType')) {
        await db.execute('ALTER TABLE sales ADD COLUMN orderDiscountType TEXT');
      }
      if (!columnNames.contains('totalDiscountAmount')) {
        await db.execute('ALTER TABLE sales ADD COLUMN totalDiscountAmount REAL');
      }
      if (!columnNames.contains('discountApprovedBy')) {
        await db.execute('ALTER TABLE sales ADD COLUMN discountApprovedBy TEXT');
      }
      if (!columnNames.contains('vatRate')) {
        await db.execute('ALTER TABLE sales ADD COLUMN vatRate REAL');
      }
      if (!columnNames.contains('taxAmount')) {
        await db.execute('ALTER TABLE sales ADD COLUMN taxAmount REAL');
      }
      if (!columnNames.contains('invoiceNo')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN invoiceNo TEXT
        ''');
      }
      
      if (!columnNames.contains('templateCode')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN templateCode TEXT
        ''');
      }
      
      if (!columnNames.contains('invoiceSerial')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN invoiceSerial TEXT
        ''');
      }
      
      if (!columnNames.contains('einvoiceUrl')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN einvoiceUrl TEXT
        ''');
      }
      // KiotViet: totalPayment (Khách thanh toán), statusValue (Trạng thái đơn)
      if (!columnNames.contains('totalPayment')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN totalPayment REAL
        ''');
      }
      if (!columnNames.contains('statusValue')) {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN statusValue TEXT
        ''');
      }
    } catch (e) {
      // Bỏ qua lỗi nếu columns đã tồn tại
      // debugPrint('Error ensuring sales columns: $e');
    }
  }

  /// Kiểm tra và thêm các columns còn thiếu vào bảng products
  Future<void> _ensureProductsColumnsExist(Database db) async {
    try {
      final result = await db.rawQuery("PRAGMA table_info(products)");
      final columnNames = result.map((row) => row['name'] as String).toList();

      if (!columnNames.contains('kiotId')) {
        await db.execute('ALTER TABLE products ADD COLUMN kiotId INTEGER');
      }
      if (!columnNames.contains('code')) {
        await db.execute('ALTER TABLE products ADD COLUMN code TEXT');
      }
      if (!columnNames.contains('fullName')) {
        await db.execute('ALTER TABLE products ADD COLUMN fullName TEXT');
      }
      if (!columnNames.contains('categoryName')) {
        await db.execute('ALTER TABLE products ADD COLUMN categoryName TEXT');
      }
      if (!columnNames.contains('images')) {
        await db.execute('ALTER TABLE products ADD COLUMN images TEXT');
      }
      if (!columnNames.contains('masterUnitId')) {
        await db.execute('ALTER TABLE products ADD COLUMN masterUnitId TEXT');
      }
      if (!columnNames.contains('masterProductId')) {
        await db.execute('ALTER TABLE products ADD COLUMN masterProductId TEXT');
      }
      if (!columnNames.contains('hasVariants')) {
        await db.execute('ALTER TABLE products ADD COLUMN hasVariants INTEGER DEFAULT 0');
      }
      if (!columnNames.contains('attributes')) {
        await db.execute('ALTER TABLE products ADD COLUMN attributes TEXT');
      }
      if (!columnNames.contains('inventories')) {
        await db.execute('ALTER TABLE products ADD COLUMN inventories TEXT');
      }
      if (!columnNames.contains('retailerId')) {
        await db.execute('ALTER TABLE products ADD COLUMN retailerId TEXT');
      }
      if (!columnNames.contains('tradeMarkId')) {
        await db.execute('ALTER TABLE products ADD COLUMN tradeMarkId TEXT');
      }
      if (!columnNames.contains('tradeMarkName')) {
        await db.execute('ALTER TABLE products ADD COLUMN tradeMarkName TEXT');
      }
      if (!columnNames.contains('description')) {
        await db.execute('ALTER TABLE products ADD COLUMN description TEXT');
      }
      if (!columnNames.contains('weight')) {
        await db.execute('ALTER TABLE products ADD COLUMN weight REAL');
      }

      if (!columnNames.contains('categoryId')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN categoryId TEXT
        ''');
      }
      
      if (!columnNames.contains('sku')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN sku TEXT
        ''');
      }
      
      if (!columnNames.contains('imageUrl')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN imageUrl TEXT
        ''');
      }
      
      if (!columnNames.contains('minStock')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN minStock REAL
        ''');
      }
      
      if (!columnNames.contains('variants')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN variants TEXT
        ''');
      }
      
      if (!columnNames.contains('branchPrices')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN branchPrices TEXT
        ''');
      }
      
      if (!columnNames.contains('branchStock')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN branchStock TEXT
        ''');
      }

      if (!columnNames.contains('groupPrices')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN groupPrices TEXT
        ''');
      }

      if (!columnNames.contains('isBatchExpireControl')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN isBatchExpireControl INTEGER DEFAULT 0
        ''');
      }

      if (!columnNames.contains('batchExpires')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN batchExpires TEXT
        ''');
      }
      
      if (!columnNames.contains('units')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN units TEXT
        ''');
      }
      
      if (!columnNames.contains('maxStock')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN maxStock REAL
        ''');
      }
      
      if (!columnNames.contains('isInventoryManaged')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN isInventoryManaged INTEGER DEFAULT 1
        ''');
      }
      
      if (!columnNames.contains('isImeiManaged')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN isImeiManaged INTEGER DEFAULT 0
        ''');
      }
      
      if (!columnNames.contains('isBatchManaged')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN isBatchManaged INTEGER DEFAULT 0
        ''');
      }
      
      if (!columnNames.contains('isSellable')) {
        await db.execute('''
          ALTER TABLE products ADD COLUMN isSellable INTEGER DEFAULT 1
        ''');
      }
    } catch (e) {
      // Bỏ qua lỗi nếu columns đã tồn tại
      if (kDebugMode) {
        debugPrint('Error ensuring products columns: $e');
      }
    }
  }

  /// Đảm bảo table branches tồn tại
  Future<void> _ensureBranchesTableExists(Database db) async {
    try {
      // Thử query để kiểm tra table có tồn tại không
      await db.rawQuery('SELECT 1 FROM branches LIMIT 1');
    } catch (e) {
      // Table chưa tồn tại, tạo mới
      await db.execute('''
        CREATE TABLE IF NOT EXISTS branches (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          address TEXT,
          phone TEXT,
          isActive INTEGER NOT NULL DEFAULT 1
        )
      ''');
    }
  }

  /// Đảm bảo các columns của branches tồn tại
  Future<void> _ensureBranchColumnsExist(Database db) async {
    // Tất cả các columns đã được tạo trong _ensureBranchesTableExists
    // Không cần thêm gì nữa, chỉ cần đảm bảo table tồn tại
    try {
      await db.rawQuery("SELECT 1 FROM branches LIMIT 1");
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking branches table: $e');
      }
    }
  }

  /// Đảm bảo table stock_history tồn tại
  Future<void> _ensureStockHistoryTableExists(Database db) async {
    try {
      // Thử query để kiểm tra table có tồn tại không
      await db.rawQuery('SELECT 1 FROM stock_history LIMIT 1');
    } catch (e) {
      // Table chưa tồn tại, tạo mới
      await db.execute('''
        CREATE TABLE IF NOT EXISTS stock_history (
          id TEXT PRIMARY KEY,
          productId TEXT NOT NULL,
          branchId TEXT NOT NULL,
          type TEXT NOT NULL,
          quantityChange REAL NOT NULL,
          beforeQuantity REAL NOT NULL,
          afterQuantity REAL NOT NULL,
          note TEXT NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_stock_history_productId ON stock_history(productId)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_stock_history_branchId ON stock_history(branchId)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_stock_history_timestamp ON stock_history(timestamp)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_stock_history_type ON stock_history(type)
      ''');
    }
  }

  /// Đảm bảo table sales_returns tồn tại
  Future<void> _ensureSalesReturnsTableExists(Database db) async {
    try {
      // Thử query để kiểm tra table có tồn tại không
      await db.rawQuery('SELECT 1 FROM sales_returns LIMIT 1');
    } catch (e) {
      // Table chưa tồn tại, tạo mới
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales_returns (
          id TEXT PRIMARY KEY,
          originalSaleId TEXT NOT NULL,
          customerId TEXT,
          branchId TEXT NOT NULL,
          items TEXT NOT NULL,
          totalRefundAmount REAL NOT NULL,
          reason TEXT NOT NULL,
          paymentMethod TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          userId TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sales_returns_timestamp ON sales_returns(timestamp)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sales_returns_userId ON sales_returns(userId)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sales_returns_originalSaleId ON sales_returns(originalSaleId)
      ''');
    }
  }

  /// Đảm bảo table app_prefs tồn tại (key-value cho tutorial flags và cài đặt app)
  Future<void> _ensureAppPrefsTableExists(Database db) async {
    try {
      await db.rawQuery('SELECT 1 FROM app_prefs LIMIT 1');
    } catch (e) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS app_prefs (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
    }
  }

  /// Đảm bảo table purchases tồn tại (fix cho database đã tạo từ trước)
  Future<void> _ensurePurchasesTableExists(Database db) async {
    try {
      // Thử query để kiểm tra table có tồn tại không
      await db.rawQuery('SELECT 1 FROM purchases LIMIT 1');
      
      // Kiểm tra và thêm branchId column nếu chưa có
      final result = await db.rawQuery("PRAGMA table_info(purchases)");
      final columnNames = result.map((row) => row['name'] as String).toList();
      
      if (!columnNames.contains('branchId')) {
        await db.execute('''
          ALTER TABLE purchases ADD COLUMN branchId TEXT DEFAULT ''
        ''');
      }
    } catch (e) {
      // Table chưa tồn tại, tạo mới
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchases (
          id TEXT PRIMARY KEY,
          supplierName TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          totalAmount REAL NOT NULL,
          items TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'DRAFT',
          userId TEXT NOT NULL,
          branchId TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_purchases_timestamp ON purchases(timestamp)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_purchases_userId ON purchases(userId)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_purchases_status ON purchases(status)
      ''');
    }
  }

  /// Tạo bảng products khi database được tạo lần đầu
  Future<void> _onCreate(Database db, int version) async {
    // Tạo bảng branches
    await db.execute('''
      CREATE TABLE branches (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT,
        phone TEXT,
        isActive INTEGER NOT NULL DEFAULT 1
      )
    ''');

      await db.execute('''
        CREATE TABLE products (
        id TEXT PRIMARY KEY,
        kiotId INTEGER,
        code TEXT,
        name TEXT NOT NULL,
        fullName TEXT,
        unit TEXT NOT NULL,
        units TEXT,
        price REAL NOT NULL,
        importPrice REAL NOT NULL,
        stock REAL NOT NULL,
        branchPrices TEXT,
        branchStock TEXT,
        groupPrices TEXT,
        barcode TEXT,
        category TEXT,
        categoryId TEXT,
        categoryName TEXT,
        manufacturer TEXT,
        sku TEXT,
        imageUrl TEXT,
        images TEXT,
        minStock REAL,
        maxStock REAL,
        masterUnitId TEXT,
        masterProductId TEXT,
        hasVariants INTEGER DEFAULT 0,
        attributes TEXT,
        inventories TEXT,
        variants TEXT,
        isInventoryManaged INTEGER DEFAULT 1,
        isImeiManaged INTEGER DEFAULT 0,
        isBatchManaged INTEGER DEFAULT 0,
        isBatchExpireControl INTEGER DEFAULT 0,
        batchExpires TEXT,
        isSellable INTEGER DEFAULT 1,
        createdAt TEXT,
        updatedAt TEXT,
        isActive INTEGER NOT NULL DEFAULT 1,
        retailerId TEXT,
        tradeMarkId TEXT,
        tradeMarkName TEXT,
        description TEXT,
        weight REAL
      )
    ''');

    // Tạo index cho barcode để tìm kiếm nhanh hơn
    await db.execute('''
      CREATE INDEX idx_barcode ON products(barcode)
    ''');

    // Tạo index cho category
    await db.execute('''
      CREATE INDEX idx_category ON products(category)
    ''');

    // Tạo bảng sales
    await db.execute('''
      CREATE TABLE sales (
        id TEXT PRIMARY KEY,
        timestamp TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        items TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        paymentStatus TEXT NOT NULL DEFAULT 'COMPLETED',
        userId TEXT NOT NULL,
        branchId TEXT NOT NULL,
        customerName TEXT,
        customerTaxCode TEXT,
        customerAddress TEXT,
        customerId TEXT,
        notes TEXT,
        sellerId TEXT,
        sellerName TEXT,
        isStockUpdated INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Tạo index cho timestamp để query nhanh hơn
    await db.execute('''
      CREATE INDEX idx_sales_timestamp ON sales(timestamp)
    ''');

    // Tạo index cho userId
    await db.execute('''
      CREATE INDEX idx_sales_userId ON sales(userId)
    ''');

    // Tạo bảng sales_returns
    await db.execute('''
      CREATE TABLE sales_returns (
        id TEXT PRIMARY KEY,
        originalSaleId TEXT NOT NULL,
        customerId TEXT,
        branchId TEXT NOT NULL,
        items TEXT NOT NULL,
        totalRefundAmount REAL NOT NULL,
        reason TEXT NOT NULL,
        paymentMethod TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        userId TEXT NOT NULL
      )
    ''');

    // Tạo index cho timestamp
    await db.execute('''
      CREATE INDEX idx_sales_returns_timestamp ON sales_returns(timestamp)
    ''');

    // Tạo index cho userId
    await db.execute('''
      CREATE INDEX idx_sales_returns_userId ON sales_returns(userId)
    ''');

    // Tạo index cho originalSaleId
    await db.execute('''
      CREATE INDEX idx_sales_returns_originalSaleId ON sales_returns(originalSaleId)
    ''');

    // Tạo bảng draft_carts để lưu giỏ hàng tạm
    await db.execute('''
      CREATE TABLE draft_carts (
        tabId INTEGER PRIMARY KEY,
        cartItems TEXT NOT NULL,
        paymentMethod TEXT NOT NULL DEFAULT 'CASH',
        customerId TEXT,
        customerName TEXT,
        customerPhone TEXT,
        customerTaxCode TEXT,
        customerAddress TEXT,
        notes TEXT,
        discountPercent REAL NOT NULL DEFAULT 0.0,
        updatedAt TEXT NOT NULL
      )
    ''');

    // Tạo bảng purchases
    await db.execute('''
      CREATE TABLE purchases (
        id TEXT PRIMARY KEY,
        supplierName TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        totalAmount REAL NOT NULL,
        items TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'DRAFT',
        userId TEXT NOT NULL,
        branchId TEXT NOT NULL
      )
    ''');

    // Tạo index cho purchases
    await db.execute('''
      CREATE INDEX idx_purchases_timestamp ON purchases(timestamp)
    ''');

    await db.execute('''
      CREATE INDEX idx_purchases_userId ON purchases(userId)
    ''');

    await db.execute('''
      CREATE INDEX idx_purchases_status ON purchases(status)
    ''');

    // Tạo bảng stock_history
    await db.execute('''
      CREATE TABLE stock_history (
        id TEXT PRIMARY KEY,
        productId TEXT NOT NULL,
        branchId TEXT NOT NULL,
        type TEXT NOT NULL,
        quantityChange REAL NOT NULL,
        beforeQuantity REAL NOT NULL,
        afterQuantity REAL NOT NULL,
        note TEXT NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    // Tạo index cho stock_history
    await db.execute('''
      CREATE INDEX idx_stock_history_productId ON stock_history(productId)
    ''');

    await db.execute('''
      CREATE INDEX idx_stock_history_branchId ON stock_history(branchId)
    ''');

    await db.execute('''
      CREATE INDEX idx_stock_history_timestamp ON stock_history(timestamp)
    ''');

    await db.execute('''
      CREATE INDEX idx_stock_history_type ON stock_history(type)
    ''');

    // Bảng app_prefs (key-value cho tutorial flags, v.v.)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_prefs (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  /// Upgrade database khi có thay đổi schema
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Thêm table sales cho version 2
      await db.execute('''
        CREATE TABLE IF NOT EXISTS sales (
          id TEXT PRIMARY KEY,
          timestamp TEXT NOT NULL,
          totalAmount REAL NOT NULL,
          items TEXT NOT NULL,
          paymentMethod TEXT NOT NULL,
          userId TEXT NOT NULL,
          branchId TEXT NOT NULL DEFAULT '',
          customerName TEXT,
          notes TEXT
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sales_timestamp ON sales(timestamp)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_sales_userId ON sales(userId)
      ''');
    }

    if (oldVersion < 3) {
      // Thêm table purchases cho version 3
      await db.execute('''
        CREATE TABLE IF NOT EXISTS purchases (
          id TEXT PRIMARY KEY,
          supplierName TEXT NOT NULL,
          timestamp TEXT NOT NULL,
          totalAmount REAL NOT NULL,
          items TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'DRAFT',
          userId TEXT NOT NULL,
          branchId TEXT NOT NULL DEFAULT ''
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_purchases_timestamp ON purchases(timestamp)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_purchases_userId ON purchases(userId)
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_purchases_status ON purchases(status)
      ''');
    }

    if (oldVersion < 4) {
      // Thêm paymentStatus và customerTaxCode, customerAddress vào sales table cho version 4
      try {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN paymentStatus TEXT DEFAULT 'COMPLETED'
        ''');
      } catch (e) {
        // Column có thể đã tồn tại, bỏ qua lỗi
      }
      try {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN customerTaxCode TEXT
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
      try {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN customerAddress TEXT
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
    }

    if (oldVersion < 6) {
      // Thêm branches table và branchPrices/branchStock columns cho version 6
      // Tạo branches table
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS branches (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            address TEXT,
            phone TEXT,
            isActive INTEGER NOT NULL DEFAULT 1
          )
        ''');
      } catch (e) {
        // Table có thể đã tồn tại
      }

      // Thêm branchPrices và branchStock columns vào products table
      try {
        await db.execute('''
          ALTER TABLE products ADD COLUMN branchPrices TEXT
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }

      try {
        await db.execute('''
          ALTER TABLE products ADD COLUMN branchStock TEXT
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
    }

    if (oldVersion < 5) {
      // Thêm sku, imageUrl, categoryId, minStock, variants vào products table cho version 5
      try {
        await db.execute('''
          ALTER TABLE products ADD COLUMN categoryId TEXT
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
      try {
        await db.execute('''
          ALTER TABLE products ADD COLUMN sku TEXT
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
      try {
        await db.execute('''
          ALTER TABLE products ADD COLUMN imageUrl TEXT
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
      try {
        await db.execute('''
          ALTER TABLE products ADD COLUMN minStock REAL
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
      try {
        await db.execute('''
          ALTER TABLE products ADD COLUMN variants TEXT
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
    }

    if (oldVersion < 7) {
      // Thêm units, maxStock, isInventoryManaged, isImeiManaged, isBatchManaged cho version 7
      try {
        await db.execute('''
          ALTER TABLE products ADD COLUMN units TEXT
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
      try {
        await db.execute('''
          ALTER TABLE products ADD COLUMN maxStock REAL
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
      try {
        await db.execute('''
          ALTER TABLE products ADD COLUMN isInventoryManaged INTEGER DEFAULT 1
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
      try {
        await db.execute('''
          ALTER TABLE products ADD COLUMN isImeiManaged INTEGER DEFAULT 0
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
      try {
        await db.execute('''
          ALTER TABLE products ADD COLUMN isBatchManaged INTEGER DEFAULT 0
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
    }

    if (oldVersion < 9) {
      // Thêm branchId vào sales và purchases tables cho version 9
      try {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN branchId TEXT DEFAULT ''
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
      try {
        await db.execute('''
          ALTER TABLE purchases ADD COLUMN branchId TEXT DEFAULT ''
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
    }

    if (oldVersion < 10) {
      // Thêm sellerId và sellerName vào sales table cho version 10
      try {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN sellerId TEXT
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
      try {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN sellerName TEXT
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
    }

    if (oldVersion < 11) {
      // Thêm isStockUpdated vào sales table cho version 11
      try {
        await db.execute('''
          ALTER TABLE sales ADD COLUMN isStockUpdated INTEGER DEFAULT 0
        ''');
      } catch (e) {
        // Column có thể đã tồn tại
      }
    }

    if (oldVersion < 12) {
      // Thêm bảng draft_carts cho version 12
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS draft_carts (
            tabId INTEGER PRIMARY KEY,
            cartItems TEXT NOT NULL,
            paymentMethod TEXT NOT NULL DEFAULT 'CASH',
            customerId TEXT,
            customerName TEXT,
            customerPhone TEXT,
            customerTaxCode TEXT,
            customerAddress TEXT,
            notes TEXT,
            discountPercent REAL NOT NULL DEFAULT 0.0,
            updatedAt TEXT NOT NULL
          )
        ''');
      } catch (e) {
        // Table có thể đã tồn tại
      }
    }

    if (oldVersion < 13) {
      // Thêm bảng stock_history cho version 13
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS stock_history (
            id TEXT PRIMARY KEY,
            productId TEXT NOT NULL,
            branchId TEXT NOT NULL,
            type TEXT NOT NULL,
            quantityChange REAL NOT NULL,
            beforeQuantity REAL NOT NULL,
            afterQuantity REAL NOT NULL,
            note TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_stock_history_productId ON stock_history(productId)
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_stock_history_branchId ON stock_history(branchId)
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_stock_history_timestamp ON stock_history(timestamp)
        ''');

        await db.execute('''
          CREATE INDEX IF NOT EXISTS idx_stock_history_type ON stock_history(type)
        ''');
      } catch (e) {
        // Table có thể đã tồn tại
      }
    }

    if (oldVersion < 14) {
      // Thêm kiotId và các cột products còn thiếu (fix lỗi thanh toán / đồng bộ KiotViet)
      await _ensureProductsColumnsExist(db);
    }
    if (oldVersion < 15) {
      await _ensureAppPrefsTableExists(db);
    }
    if (oldVersion < 16) {
      await _ensureKiotVietTablesExist(db);
    }
    if (oldVersion < 17) {
      await _ensureGlobalPartsCatalogTablesExist(db);
    }
    if (oldVersion < 18) {
      try {
        await db.execute('ALTER TABLE global_parts_catalog_data ADD COLUMN last_updated TEXT');
      } catch (e) {
        // Cột có thể đã tồn tại
      }
    }
  }

  // ========== GLOBAL PARTS CATALOG (tra cứu phụ tùng toàn hệ thống, tải 1 lần từ Firestore) ==========

  /// Kiểm tra đã có dữ liệu global_parts_catalog local chưa.
  Future<bool> hasGlobalPartsCatalogData() async {
    try {
      final db = await database;
      final rows = await db.query(
        'global_parts_catalog_data',
        columns: ['row_id'],
        limit: 1,
      );
      return rows.isNotEmpty;
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService hasGlobalPartsCatalogData: $e');
      return false;
    }
  }

  /// Xóa toàn bộ dữ liệu global_parts_catalog (trước khi ghi đè).
  Future<void> clearGlobalPartsCatalog() async {
    final db = await database;
    await db.delete('global_parts_catalog_data');
    await db.delete('global_parts_catalog_meta');
  }

  /// Chèn một lô dòng. Mỗi row: map với row_id, ten_xe, doi_xe, chung_loai, ten_phu_tung, cells (JSON string).
  Future<void> insertGlobalPartsCatalogRows(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert('global_parts_catalog_data', {
        'row_id': row['row_id'] as String,
        'ten_xe': row['ten_xe'] as String? ?? '',
        'doi_xe': row['doi_xe'] as String? ?? '',
        'chung_loai': row['chung_loai'] as String? ?? '',
        'ten_phu_tung': row['ten_phu_tung'] as String? ?? '',
        'cells': row['cells'] as String? ?? '{}',
      });
    }
    await batch.commit(noResult: true);
  }

  /// Đánh dấu đã đồng bộ xong.
  Future<void> setGlobalPartsCatalogSynced() async {
    final db = await database;
    await db.insert(
      'global_parts_catalog_meta',
      {'key': 'synced', 'value': DateTime.now().toUtc().toIso8601String()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Tìm kiếm global_parts_catalog theo 3 bộ lọc (LIKE %value%). Trả về danh sách map (row_id, ten_xe, doi_xe, chung_loai, ten_phu_tung, cells).
  Future<List<Map<String, dynamic>>> getGlobalPartsCatalogRowsFiltered({
    String? tenXe,
    String? namSanXuat,
    String? chungLoaiPhuTung,
  }) async {
    try {
      final db = await database;
      String? where = '1=1';
      final args = <dynamic>[];
      if (tenXe != null && tenXe.trim().isNotEmpty) {
        where += ' AND ten_xe LIKE ?';
        args.add('%${tenXe.trim()}%');
      }
      if (namSanXuat != null && namSanXuat.trim().isNotEmpty) {
        where += ' AND doi_xe LIKE ?';
        args.add('%${namSanXuat.trim()}%');
      }
      if (chungLoaiPhuTung != null && chungLoaiPhuTung.trim().isNotEmpty) {
        where += ' AND chung_loai LIKE ?';
        args.add('%${chungLoaiPhuTung.trim()}%');
      }
      final rows = await db.query(
        'global_parts_catalog_data',
        where: where,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'row_id ASC',
      );
      return rows.map((m) => {
        'row_id': m['row_id'],
        'ten_xe': m['ten_xe'],
        'doi_xe': m['doi_xe'],
        'chung_loai': m['chung_loai'],
        'ten_phu_tung': m['ten_phu_tung'],
        'cells': m['cells'],
      }).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getGlobalPartsCatalogRowsFiltered: $e');
      return [];
    }
  }

  static String _cellValue(Map<String, dynamic> cells, String key) {
    final v = cells[key] ?? cells[key.replaceAll(' ', '_')];
    return (v?.toString() ?? '').trim();
  }

  /// Cập nhật một dòng trong global_parts_catalog_data (local). Ghi thêm last_updated để biết dòng đã sửa (đồng bộ sau).
  Future<void> updateGlobalPartsCatalogRow(String rowId, Map<String, dynamic> cells) async {
    if (rowId.isEmpty) return;
    final db = await database;
    final tenXe = _cellValue(cells, 'Tên Xe');
    final doiXe = _cellValue(cells, 'Đời Xe');
    final chungLoai = _cellValue(cells, 'Chủng loại');
    final tenPhuTung = _cellValue(cells, 'Tên Phụ Tùng');
    final cellsJson = jsonEncode(cells);
    final lastUpdated = DateTime.now().toUtc().toIso8601String();
    await db.update(
      'global_parts_catalog_data',
      {
        'ten_xe': tenXe,
        'doi_xe': doiXe,
        'chung_loai': chungLoai,
        'ten_phu_tung': tenPhuTung,
        'cells': cellsJson,
        'last_updated': lastUpdated,
      },
      where: 'row_id = ?',
      whereArgs: [rowId],
    );
  }

  /// Gợi ý Tên xe từ global_parts_catalog. [namSanXuat]/[chungLoaiPhuTung] nếu có thì chỉ gợi ý giá trị tồn tại cùng bộ lọc đó.
  Future<List<String>> getGlobalPartsCatalogTenXeSuggestions(
    String query, {
    String? namSanXuat,
    String? chungLoaiPhuTung,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      final db = await database;
      var where = "ten_xe IS NOT NULL AND ten_xe != '' AND ten_xe LIKE ?";
      final args = <dynamic>['%${query.trim()}%'];
      if (namSanXuat != null && namSanXuat.trim().isNotEmpty) {
        where += ' AND doi_xe LIKE ?';
        args.add('%${namSanXuat.trim()}%');
      }
      if (chungLoaiPhuTung != null && chungLoaiPhuTung.trim().isNotEmpty) {
        where += ' AND chung_loai LIKE ?';
        args.add('%${chungLoaiPhuTung.trim()}%');
      }
      final rows = await db.rawQuery(
        'SELECT DISTINCT ten_xe FROM global_parts_catalog_data WHERE $where ORDER BY ten_xe LIMIT 20',
        args,
      );
      return rows.map((r) => (r['ten_xe'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getGlobalPartsCatalogTenXeSuggestions: $e');
      return [];
    }
  }

  /// Gợi ý Chủng loại từ global_parts_catalog. [tenXe]/[namSanXuat] nếu có thì chỉ gợi ý giá trị tồn tại cùng bộ lọc đó.
  Future<List<String>> getGlobalPartsCatalogChungLoaiSuggestions(
    String query, {
    String? tenXe,
    String? namSanXuat,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      final db = await database;
      var where = "chung_loai IS NOT NULL AND chung_loai != '' AND chung_loai LIKE ?";
      final args = <dynamic>['%${query.trim()}%'];
      if (tenXe != null && tenXe.trim().isNotEmpty) {
        where += ' AND ten_xe LIKE ?';
        args.add('%${tenXe.trim()}%');
      }
      if (namSanXuat != null && namSanXuat.trim().isNotEmpty) {
        where += ' AND doi_xe LIKE ?';
        args.add('%${namSanXuat.trim()}%');
      }
      final rows = await db.rawQuery(
        'SELECT DISTINCT chung_loai FROM global_parts_catalog_data WHERE $where ORDER BY chung_loai LIMIT 20',
        args,
      );
      return rows.map((r) => (r['chung_loai'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getGlobalPartsCatalogChungLoaiSuggestions: $e');
      return [];
    }
  }

  /// Gợi ý Đời xe từ global_parts_catalog. [tenXe]/[chungLoaiPhuTung] nếu có thì chỉ gợi ý giá trị tồn tại cùng bộ lọc đó.
  Future<List<String>> getGlobalPartsCatalogDoiXeSuggestions(
    String query, {
    String? tenXe,
    String? chungLoaiPhuTung,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      final db = await database;
      var where = "doi_xe IS NOT NULL AND doi_xe != '' AND doi_xe LIKE ?";
      final args = <dynamic>['%${query.trim()}%'];
      if (tenXe != null && tenXe.trim().isNotEmpty) {
        where += ' AND ten_xe LIKE ?';
        args.add('%${tenXe.trim()}%');
      }
      if (chungLoaiPhuTung != null && chungLoaiPhuTung.trim().isNotEmpty) {
        where += ' AND chung_loai LIKE ?';
        args.add('%${chungLoaiPhuTung.trim()}%');
      }
      final rows = await db.rawQuery(
        'SELECT DISTINCT doi_xe FROM global_parts_catalog_data WHERE $where ORDER BY doi_xe LIMIT 20',
        args,
      );
      return rows.map((r) => (r['doi_xe'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getGlobalPartsCatalogDoiXeSuggestions: $e');
      return [];
    }
  }

  /// Gợi ý Tên xe từ kiot_viet_data theo shop. [namSanXuat]/[chungLoaiPhuTung] nếu có thì chỉ gợi ý giá trị tồn tại cùng bộ lọc đó.
  Future<List<String>> getKiotVietTenXeSuggestions(
    String shopId,
    String query, {
    String? namSanXuat,
    String? chungLoaiPhuTung,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      final db = await database;
      var where = 'shop_id = ? AND ten_xe IS NOT NULL AND ten_xe != '' AND ten_xe LIKE ?';
      final args = <dynamic>[shopId, '%${query.trim()}%'];
      if (namSanXuat != null && namSanXuat.trim().isNotEmpty) {
        where += ' AND doi_xe LIKE ?';
        args.add('%${namSanXuat.trim()}%');
      }
      if (chungLoaiPhuTung != null && chungLoaiPhuTung.trim().isNotEmpty) {
        where += ' AND chung_loai LIKE ?';
        args.add('%${chungLoaiPhuTung.trim()}%');
      }
      final rows = await db.rawQuery(
        'SELECT DISTINCT ten_xe FROM kiot_viet_data WHERE $where ORDER BY ten_xe LIMIT 20',
        args,
      );
      return rows.map((r) => (r['ten_xe'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getKiotVietTenXeSuggestions: $e');
      return [];
    }
  }

  /// Gợi ý Chủng loại từ kiot_viet_data theo shop. [tenXe]/[namSanXuat] nếu có thì chỉ gợi ý giá trị tồn tại cùng bộ lọc đó.
  Future<List<String>> getKiotVietChungLoaiSuggestions(
    String shopId,
    String query, {
    String? tenXe,
    String? namSanXuat,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      final db = await database;
      var where = 'shop_id = ? AND chung_loai IS NOT NULL AND chung_loai != '' AND chung_loai LIKE ?';
      final args = <dynamic>[shopId, '%${query.trim()}%'];
      if (tenXe != null && tenXe.trim().isNotEmpty) {
        where += ' AND ten_xe LIKE ?';
        args.add('%${tenXe.trim()}%');
      }
      if (namSanXuat != null && namSanXuat.trim().isNotEmpty) {
        where += ' AND doi_xe LIKE ?';
        args.add('%${namSanXuat.trim()}%');
      }
      final rows = await db.rawQuery(
        'SELECT DISTINCT chung_loai FROM kiot_viet_data WHERE $where ORDER BY chung_loai LIMIT 20',
        args,
      );
      return rows.map((r) => (r['chung_loai'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getKiotVietChungLoaiSuggestions: $e');
      return [];
    }
  }

  /// Gợi ý Đời xe từ kiot_viet_data theo shop. [tenXe]/[chungLoaiPhuTung] nếu có thì chỉ gợi ý giá trị tồn tại cùng bộ lọc đó.
  Future<List<String>> getKiotVietDoiXeSuggestions(
    String shopId,
    String query, {
    String? tenXe,
    String? chungLoaiPhuTung,
  }) async {
    if (query.trim().isEmpty) return [];
    try {
      final db = await database;
      var where = 'shop_id = ? AND doi_xe IS NOT NULL AND doi_xe != '' AND doi_xe LIKE ?';
      final args = <dynamic>[shopId, '%${query.trim()}%'];
      if (tenXe != null && tenXe.trim().isNotEmpty) {
        where += ' AND ten_xe LIKE ?';
        args.add('%${tenXe.trim()}%');
      }
      if (chungLoaiPhuTung != null && chungLoaiPhuTung.trim().isNotEmpty) {
        where += ' AND chung_loai LIKE ?';
        args.add('%${chungLoaiPhuTung.trim()}%');
      }
      final rows = await db.rawQuery(
        'SELECT DISTINCT doi_xe FROM kiot_viet_data WHERE $where ORDER BY doi_xe LIMIT 20',
        args,
      );
      return rows.map((r) => (r['doi_xe'] as String?) ?? '').where((s) => s.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getKiotVietDoiXeSuggestions: $e');
      return [];
    }
  }

  // ========== APP PREFS (Tutorial flags, v.v.) ==========

  /// Lấy giá trị preference theo key. Trả về null nếu không tồn tại.
  Future<String?> getAppPref(String key) async {
    try {
      final db = await database;
      final rows = await db.query(
        'app_prefs',
        where: 'key = ?',
        whereArgs: [key],
        limit: 1,
      );
      if (rows.isEmpty) return null;
      return rows.first['value'] as String?;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocalDbService getAppPref error: $e');
      }
      return null;
    }
  }

  /// Lưu preference (key-value). Dùng cho has_seen_welcome_popup, has_completed_overview_tour.
  Future<void> setAppPref(String key, String value) async {
    try {
      final db = await database;
      await db.insert(
        'app_prefs',
        {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LocalDbService setAppPref error: $e');
      }
      rethrow;
    }
  }

  // ========== CÀI ĐẶT MÁY IN (SharedPreferences) ==========
  static const String _keyPrinterPaperSizeMm = 'printer_paper_size_mm';
  static const String _keyAutoPrintAfterPayment = 'auto_print_after_payment';
  static const String _keyPrinterName = 'printer_name';

  /// Khổ giấy mặc định (58 hoặc 80 mm). Mặc định 80.
  Future<int> getPrinterPaperSizeMm() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getInt(_keyPrinterPaperSizeMm);
      if (v == 58 || v == 80) return v!;
      return 80;
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getPrinterPaperSizeMm: $e');
      return 80;
    }
  }

  Future<void> setPrinterPaperSizeMm(int value) async {
    if (value != 58 && value != 80) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyPrinterPaperSizeMm, value);
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService setPrinterPaperSizeMm: $e');
      rethrow;
    }
  }

  /// Tự động in sau khi thanh toán. Mặc định false.
  Future<bool> getAutoPrintAfterPayment() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAutoPrintAfterPayment) ?? false;
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getAutoPrintAfterPayment: $e');
      return false;
    }
  }

  Future<void> setAutoPrintAfterPayment(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyAutoPrintAfterPayment, value);
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService setAutoPrintAfterPayment: $e');
      rethrow;
    }
  }

  /// Tên máy in (Desktop, Silent Print). Null nếu chưa đặt.
  Future<String?> getPrinterName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyPrinterName);
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService getPrinterName: $e');
      return null;
    }
  }

  Future<void> setPrinterName(String? value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (value == null || value.trim().isEmpty) {
        await prefs.remove(_keyPrinterName);
      } else {
        await prefs.setString(_keyPrinterName, value.trim());
      }
    } catch (e) {
      if (kDebugMode) debugPrint('LocalDbService setPrinterName: $e');
      rethrow;
    }
  }

  /// Lấy tất cả sản phẩm
  Future<List<ProductModel>> getProducts({
    bool includeInactive = false,
    String? activeBranchId,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;

    if (includeInactive) {
      maps = await db.query('products', orderBy: 'name ASC');
    } else {
      maps = await db.query(
        'products',
        where: 'isActive = ?',
        whereArgs: [1],
        orderBy: 'name ASC',
      );
    }

    // Parse products và filter theo branchId nếu có
    List<ProductModel> products = List.generate(
      maps.length,
      (i) => ProductModel.fromMap(maps[i]),
    );

    // Nếu có activeBranchId, filter và tính toán lại price/stock từ branchPrices/branchStock
    if (activeBranchId != null && activeBranchId.isNotEmpty) {
      products = products.map((product) {
        // Lấy price từ branchPrices
        final branchPrice = product.branchPrices[activeBranchId] ?? product.price;
        // Lấy stock từ branchStock
        double branchStock = product.branchStock[activeBranchId] ?? 0.0;
        // Cộng thêm stock từ variants nếu có
        if (product.variants.isNotEmpty) {
          for (var variant in product.variants) {
            branchStock += variant.branchStock[activeBranchId] ?? 0.0;
          }
        }

        // Tạo product mới với price và stock đã được filter
        return product.copyWith(
          branchPrices: {activeBranchId: branchPrice},
          branchStock: {activeBranchId: branchStock},
        );
      }).toList();
    }

    _fillProductCaches(products);
    return products;
  }

  /// Lấy sản phẩm theo ID — ưu tiên cache (<100ms).
  Future<ProductModel?> getProductById(String id) async {
    final cached = _productByIdCache?[id];
    if (cached != null) return cached;

    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;
    final product = ProductModel.fromMap(maps.first);
    _productByIdCache ??= {};
    _productByIdCache![id] = product;
    return product;
  }

  /// Lấy sản phẩm theo mã vạch — ưu tiên cache O(1) (<100ms).
  Future<ProductModel?> getProductByBarcode(String barcode) async {
    final key = barcode.trim().toLowerCase();
    if (key.isEmpty) return null;
    final cached = _productByBarcodeCache?[key];
    if (cached != null) return cached;

    if (_productByIdCache != null) {
      for (final p in _productByIdCache!.values) {
        final b = p.barcode?.trim().toLowerCase();
        if (b == key) {
          _productByBarcodeCache ??= {};
          _productByBarcodeCache![key] = p;
          return p;
        }
      }
      return null;
    }

    await getProducts(includeInactive: false);
    return _productByBarcodeCache?[key];
  }

  /// Tìm kiếm sản phẩm theo tên hoặc barcode
  Future<List<ProductModel>> searchProducts(
    String query, {
    String? activeBranchId,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'isActive = ? AND (name LIKE ? OR barcode LIKE ?)',
      whereArgs: [1, '%$query%', '%$query%'],
      orderBy: 'name ASC',
    );

    // Parse products và filter theo branchId nếu có
    List<ProductModel> products = List.generate(
      maps.length,
      (i) => ProductModel.fromMap(maps[i]),
    );

    // Nếu có activeBranchId, filter và tính toán lại price/stock từ branchPrices/branchStock
    if (activeBranchId != null && activeBranchId.isNotEmpty) {
      products = products.map((product) {
        // Lấy price từ branchPrices
        final branchPrice = product.branchPrices[activeBranchId] ?? product.price;
        // Lấy stock từ branchStock
        double branchStock = product.branchStock[activeBranchId] ?? 0.0;
        // Cộng thêm stock từ variants nếu có
        if (product.variants.isNotEmpty) {
          for (var variant in product.variants) {
            branchStock += variant.branchStock[activeBranchId] ?? 0.0;
          }
        }

        // Tạo product mới với price và stock đã được filter
        return product.copyWith(
          branchPrices: {activeBranchId: branchPrice},
          branchStock: {activeBranchId: branchStock},
        );
      }).toList();
    }

    return products;
  }

  /// Thêm sản phẩm mới
  Future<String> addProduct(ProductModel product) async {
    final db = await database;
    final now = DateTime.now();
    
    final productWithTimestamp = product.copyWith(
      createdAt: product.createdAt ?? now,
      updatedAt: now,
    );

    await db.insert(
      'products',
      productWithTimestamp.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    _invalidateProductCache();
    return product.id;
  }

  /// Cập nhật sản phẩm
  Future<int> updateProduct(ProductModel product) async {
    final db = await database;
    final productWithTimestamp = product.copyWith(
      updatedAt: DateTime.now(),
    );

    final n = await db.update(
      'products',
      productWithTimestamp.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
    _invalidateProductCache();
    return n;
  }

  /// Xóa sản phẩm (soft delete - đánh dấu isActive = false)
  Future<int> deleteProduct(String id) async {
    final db = await database;
    final n = await db.update(
      'products',
      {
        'isActive': 0,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    _invalidateProductCache();
    return n;
  }

  /// Xóa vĩnh viễn sản phẩm
  Future<int> deleteProductPermanently(String id) async {
    final db = await database;
    final n = await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [id],
    );
    _invalidateProductCache();
    return n;
  }

  /// Lấy số lượng sản phẩm
  Future<int> getProductCount({bool includeInactive = false}) async {
    final db = await database;
    final List<Map<String, dynamic>> result;

    if (includeInactive) {
      result = await db.rawQuery('SELECT COUNT(*) as count FROM products');
    } else {
      result = await db.rawQuery(
        'SELECT COUNT(*) as count FROM products WHERE isActive = ?',
        [1],
      );
    }

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Xóa tất cả sản phẩm (dùng khi migrate)
  Future<void> deleteAllProducts() async {
    final db = await database;
    await db.delete('products');
  }

  // ========== BRANCHES METHODS ==========

  /// Lấy tất cả chi nhánh
  Future<List<BranchModel>> getBranches({bool includeInactive = false}) async {
    try {
      final db = await database;
      
      // Đảm bảo table branches tồn tại
      try {
        await db.rawQuery('SELECT 1 FROM branches LIMIT 1');
      } catch (e) {
        // Table chưa tồn tại, tạo mới
        await _ensureBranchesTableExists(db);
      }

      final List<Map<String, dynamic>> maps;

      if (includeInactive) {
        maps = await db.query('branches', orderBy: 'name ASC');
      } else {
        maps = await db.query(
          'branches',
          where: 'isActive = ?',
          whereArgs: [1],
          orderBy: 'name ASC',
        );
      }

      return List.generate(maps.length, (i) {
        final map = maps[i];
        return BranchModel(
          id: map['id'] as String,
          name: map['name'] as String,
          address: map['address'] as String?,
          phone: map['phone'] as String?,
          isActive: (map['isActive'] as int) == 1,
        );
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting branches from SQLite: $e');
      }
      // Trả về danh sách rỗng thay vì throw exception
      return [];
    }
  }

  /// Lấy chi nhánh theo ID
  Future<BranchModel?> getBranchById(String id) async {
    try {
      final db = await database;
      
      // Đảm bảo table branches tồn tại
      try {
        await db.rawQuery('SELECT 1 FROM branches LIMIT 1');
      } catch (e) {
        // Table chưa tồn tại, tạo mới
        await _ensureBranchesTableExists(db);
      }

      final List<Map<String, dynamic>> maps = await db.query(
        'branches',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      final map = maps.first;
      return BranchModel(
        id: map['id'] as String,
        name: map['name'] as String,
        address: map['address'] as String?,
        phone: map['phone'] as String?,
        isActive: (map['isActive'] as int) == 1,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting branch by ID from SQLite: $e');
      }
      return null;
    }
  }

  /// Thêm chi nhánh mới
  Future<String> addBranch(BranchModel branch) async {
    try {
      final db = await database;
      
      // Đảm bảo table branches tồn tại
      try {
        await db.rawQuery('SELECT 1 FROM branches LIMIT 1');
      } catch (e) {
        // Table chưa tồn tại, tạo mới
        await _ensureBranchesTableExists(db);
      }

      await db.insert(
        'branches',
        {
          'id': branch.id,
          'name': branch.name,
          'address': branch.address,
          'phone': branch.phone,
          'isActive': branch.isActive ? 1 : 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return branch.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding branch to SQLite: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật chi nhánh
  Future<int> updateBranch(BranchModel branch) async {
    try {
      final db = await database;
      
      // Đảm bảo table branches tồn tại
      try {
        await db.rawQuery('SELECT 1 FROM branches LIMIT 1');
      } catch (e) {
        // Table chưa tồn tại, tạo mới
        await _ensureBranchesTableExists(db);
      }

      return await db.update(
        'branches',
        {
          'name': branch.name,
          'address': branch.address,
          'phone': branch.phone,
          'isActive': branch.isActive ? 1 : 0,
        },
        where: 'id = ?',
        whereArgs: [branch.id],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating branch in SQLite: $e');
      }
      rethrow;
    }
  }

  /// Xóa chi nhánh (soft delete - đánh dấu isActive = false)
  Future<int> deleteBranch(String id) async {
    try {
      final db = await database;
      
      // Đảm bảo table branches tồn tại
      try {
        await db.rawQuery('SELECT 1 FROM branches LIMIT 1');
      } catch (e) {
        // Table chưa tồn tại, không có gì để xóa
        return 0;
      }

      return await db.update(
        'branches',
        {'isActive': 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting branch in SQLite: $e');
      }
      rethrow;
    }
  }

  /// Xóa vĩnh viễn chi nhánh
  Future<int> deleteBranchPermanently(String id) async {
    final db = await database;
    return await db.delete(
      'branches',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ========== SALES METHODS ==========

  /// Lấy tất cả đơn hàng
  Future<List<SaleModel>> getSales({String? userId}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;

    if (userId != null) {
      maps = await db.query(
        'sales',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'timestamp DESC',
      );
    } else {
      maps = await db.query('sales', orderBy: 'timestamp DESC');
    }

    return maps.map((map) => _saleFromDbMap(map)).toList();
  }

  /// Parse một dòng sales từ DB thành SaleModel (dùng chung cho getSales / getSaleById nếu có)
  SaleModel _saleFromDbMap(Map<String, dynamic> map) {
    final itemsJson = map['items'] as String? ?? '[]';
    final items = SaleItem.fromJsonList(itemsJson);
    return SaleModel(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      items: items,
      paymentMethod: map['paymentMethod'] as String,
      paymentStatus: map['paymentStatus'] as String? ?? 'COMPLETED',
      userId: map['userId'] as String,
      branchId: map['branchId'] as String? ?? '',
      customerName: map['customerName'] as String?,
      customerTaxCode: map['customerTaxCode'] as String?,
      customerAddress: map['customerAddress'] as String?,
      customerId: map['customerId'] as String?,
      notes: map['notes'] as String?,
      sellerId: map['sellerId'] as String?,
      sellerName: map['sellerName'] as String?,
      isStockUpdated: (map['isStockUpdated'] as int? ?? 0) == 1,
      totalBeforeDiscount: map['totalBeforeDiscount'] != null ? (map['totalBeforeDiscount'] as num).toDouble() : null,
      discountAmount: map['discountAmount'] != null ? (map['discountAmount'] as num).toDouble() : null,
      subTotal: map['subTotal'] != null ? (map['subTotal'] as num).toDouble() : null,
      orderDiscountValue: map['orderDiscountValue'] != null ? (map['orderDiscountValue'] as num).toDouble() : null,
      orderDiscountType: map['orderDiscountType'] as String?,
      totalDiscountAmount: map['totalDiscountAmount'] != null ? (map['totalDiscountAmount'] as num).toDouble() : null,
      discountApprovedBy: map['discountApprovedBy'] as String?,
      vatRate: map['vatRate'] != null ? (map['vatRate'] as num).toDouble() : null,
      taxAmount: map['taxAmount'] != null ? (map['taxAmount'] as num).toDouble() : null,
      invoiceNo: map['invoiceNo'] as String?,
      templateCode: map['templateCode'] as String?,
      invoiceSerial: map['invoiceSerial'] as String?,
      einvoiceUrl: map['einvoiceUrl'] as String?,
      totalPayment: map['totalPayment'] != null ? (map['totalPayment'] as num).toDouble() : null,
      statusValue: map['statusValue'] as String?,
    );
  }

  /// Thêm đơn hàng mới
  Future<String> addSale(SaleModel sale) async {
    final db = await database;

    // Chuyển items thành JSON string
    final itemsJson = jsonEncode(sale.items.map((item) => item.toMap()).toList());

    await db.insert(
      'sales',
      {
        'id': sale.id,
        'timestamp': sale.timestamp.toIso8601String(),
        'totalAmount': sale.totalAmount,
        'items': itemsJson,
        'paymentMethod': sale.paymentMethod,
        'paymentStatus': sale.paymentStatus,
        'userId': sale.userId,
        'branchId': sale.branchId,
        'customerName': sale.customerName,
        'customerTaxCode': sale.customerTaxCode,
        'customerAddress': sale.customerAddress,
        'customerId': sale.customerId,
        'notes': sale.notes,
        'sellerId': sale.sellerId,
        'sellerName': sale.sellerName,
        'isStockUpdated': sale.isStockUpdated ? 1 : 0,
        'totalBeforeDiscount': sale.totalBeforeDiscount,
        'discountAmount': sale.discountAmount,
        'subTotal': sale.subTotal,
        'orderDiscountValue': sale.orderDiscountValue,
        'orderDiscountType': sale.orderDiscountType,
        'totalDiscountAmount': sale.totalDiscountAmount,
        'discountApprovedBy': sale.discountApprovedBy,
        'vatRate': sale.vatRate,
        'taxAmount': sale.taxAmount,
        'invoiceNo': sale.invoiceNo,
        'templateCode': sale.templateCode,
        'invoiceSerial': sale.invoiceSerial,
        'einvoiceUrl': sale.einvoiceUrl,
        'totalPayment': sale.totalPayment,
        'statusValue': sale.statusValue,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return sale.id;
  }

  /// Cập nhật trạng thái thanh toán của đơn hàng
  /// Cập nhật SaleModel trong SQLite
  Future<void> updateSale(SaleModel sale) async {
    final db = await database;
    
    await db.update(
      'sales',
      sale.toMap(),
      where: 'id = ?',
      whereArgs: [sale.id],
    );
  }

  Future<void> updateSalePaymentStatus(String saleId, String paymentStatus) async {
    final db = await database;
    await db.update(
      'sales',
      {
        'paymentStatus': paymentStatus,
      },
      where: 'id = ?',
      whereArgs: [saleId],
    );
  }

  // ========== PURCHASES METHODS ==========

  /// Lấy tất cả phiếu nhập
  Future<List<PurchaseModel>> getPurchases({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;

    String? whereClause;
    List<dynamic>? whereArgs;

    if (userId != null) {
      whereClause = 'userId = ?';
      whereArgs = [userId];
    }

    if (startDate != null && endDate != null) {
      if (whereClause != null) {
        whereClause += ' AND timestamp >= ? AND timestamp <= ?';
        whereArgs!.addAll([
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ]);
      } else {
        whereClause = 'timestamp >= ? AND timestamp <= ?';
        whereArgs = [
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ];
      }
    }

    maps = await db.query(
      'purchases',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) {
      // Parse items từ JSON string
      final itemsJson = map['items'] as String? ?? '[]';
      final items = PurchaseItem.fromJsonList(itemsJson);

      return PurchaseModel(
        id: map['id'] as String,
        supplierName: map['supplierName'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        totalAmount: (map['totalAmount'] as num).toDouble(),
        items: items,
        status: map['status'] as String,
        userId: map['userId'] as String,
        branchId: map['branchId'] as String? ?? '', // Bắt buộc, mặc định rỗng nếu không có
      );
    }).toList();
  }

  /// Thêm phiếu nhập mới
  Future<String> addPurchase(PurchaseModel purchase) async {
    final db = await database;

    // Chuyển items thành JSON string
    final itemsJson = jsonEncode(purchase.items.map((item) => item.toMap()).toList());

    await db.insert(
      'purchases',
      {
        'id': purchase.id,
        'supplierName': purchase.supplierName,
        'timestamp': purchase.timestamp.toIso8601String(),
        'totalAmount': purchase.totalAmount,
        'items': itemsJson,
        'status': purchase.status,
        'userId': purchase.userId,
        'branchId': purchase.branchId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return purchase.id;
  }

  /// Lấy phiếu nhập theo ID
  Future<PurchaseModel?> getPurchaseById(String id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchases',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    final itemsJson = map['items'] as String? ?? '[]';
    final items = PurchaseItem.fromJsonList(itemsJson);

    return PurchaseModel(
      id: map['id'] as String,
      supplierName: map['supplierName'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      items: items,
      status: map['status'] as String,
      userId: map['userId'] as String,
      branchId: map['branchId'] as String? ?? '', // Bắt buộc, mặc định rỗng nếu không có
    );
  }

  /// Đóng database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // ==================== CUSTOMER GROUPS ====================

  /// Đảm bảo bảng customer_groups tồn tại
  Future<void> _ensureCustomerGroupsTableExists(Database db) async {
    try {
      await db.rawQuery('SELECT 1 FROM customer_groups LIMIT 1');
    } catch (e) {
      // Table chưa tồn tại, tạo mới
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customer_groups (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          discountPercent REAL NOT NULL DEFAULT 0,
          description TEXT,
          createdAt TEXT,
          updatedAt TEXT
        )
      ''');
    }
  }

  /// Lấy tất cả nhóm khách hàng
  Future<List<CustomerGroupModel>> getCustomerGroups() async {
    try {
      final db = await database;
      
      // Đảm bảo table tồn tại
      try {
        await db.rawQuery('SELECT 1 FROM customer_groups LIMIT 1');
      } catch (e) {
        await _ensureCustomerGroupsTableExists(db);
      }

      final maps = await db.query('customer_groups', orderBy: 'name ASC');
      return maps.map((map) => CustomerGroupModel.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting customer groups from SQLite: $e');
      }
      return [];
    }
  }

  /// Lấy nhóm khách hàng theo ID
  Future<CustomerGroupModel?> getCustomerGroupById(String id) async {
    try {
      final db = await database;
      
      try {
        await db.rawQuery('SELECT 1 FROM customer_groups LIMIT 1');
      } catch (e) {
        await _ensureCustomerGroupsTableExists(db);
      }

      final maps = await db.query(
        'customer_groups',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return CustomerGroupModel.fromMap(maps.first);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting customer group by ID from SQLite: $e');
      }
      return null;
    }
  }

  /// Thêm nhóm khách hàng
  Future<String> addCustomerGroup(CustomerGroupModel group) async {
    try {
      final db = await database;
      
      try {
        await db.rawQuery('SELECT 1 FROM customer_groups LIMIT 1');
      } catch (e) {
        await _ensureCustomerGroupsTableExists(db);
      }

      await db.insert(
        'customer_groups',
        group.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return group.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding customer group to SQLite: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật nhóm khách hàng
  Future<int> updateCustomerGroup(CustomerGroupModel group) async {
    try {
      final db = await database;
      
      try {
        await db.rawQuery('SELECT 1 FROM customer_groups LIMIT 1');
      } catch (e) {
        await _ensureCustomerGroupsTableExists(db);
      }

      return await db.update(
        'customer_groups',
        group.toMap(),
        where: 'id = ?',
        whereArgs: [group.id],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating customer group in SQLite: $e');
      }
      rethrow;
    }
  }

  /// Xóa nhóm khách hàng
  Future<int> deleteCustomerGroup(String id) async {
    try {
      final db = await database;
      
      try {
        await db.rawQuery('SELECT 1 FROM customer_groups LIMIT 1');
      } catch (e) {
        // Table chưa tồn tại, không có gì để xóa
        return 0;
      }

      return await db.delete(
        'customer_groups',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting customer group from SQLite: $e');
      }
      rethrow;
    }
  }

  // ==================== CUSTOMERS ====================

  /// Đảm bảo bảng customers tồn tại và có đủ cột theo [CustomerModel] (đồng bộ với giao diện mới).
  Future<void> _ensureCustomersTableExists(Database db) async {
    try {
      await db.rawQuery('SELECT 1 FROM customers LIMIT 1');
    } catch (e) {
      // Table chưa tồn tại, tạo mới với đủ cột
      await db.execute('''
        CREATE TABLE IF NOT EXISTS customers (
          id TEXT PRIMARY KEY,
          kiotId INTEGER,
          code TEXT,
          name TEXT NOT NULL,
          phone TEXT NOT NULL,
          address TEXT,
          groupId TEXT,
          groupIds TEXT,
          groups TEXT,
          totalDebt REAL NOT NULL DEFAULT 0,
          totalRevenue REAL NOT NULL DEFAULT 0,
          totalInvoiced REAL,
          taxCode TEXT,
          gender INTEGER,
          birthDate TEXT,
          email TEXT,
          locationName TEXT,
          wardName TEXT,
          organization TEXT,
          comments TEXT,
          createdAt TEXT,
          updatedAt TEXT
        )
      ''');

      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_phone ON customers(phone)');
      } catch (_) {}
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_group ON customers(groupId)');
      } catch (_) {}
      return;
    }
    // Bảng đã tồn tại: migration thêm cột nếu thiếu (đồng bộ với CustomerModel / giao diện)
    await _migrateCustomersTableAddColumns(db);
  }

  /// Thêm các cột thiếu vào bảng customers (migration cho DB cũ).
  Future<void> _migrateCustomersTableAddColumns(Database db) async {
    const columns = [
      'kiotId INTEGER', 'code TEXT', 'totalRevenue REAL', 'totalInvoiced REAL', 'taxCode TEXT',
      'gender INTEGER', 'birthDate TEXT', 'email TEXT', 'locationName TEXT', 'wardName TEXT',
      'organization TEXT', 'comments TEXT', 'groupIds TEXT', 'groups TEXT',
    ];
    for (final colDef in columns) {
      final name = colDef.split(' ').first;
      try {
        await db.execute('ALTER TABLE customers ADD COLUMN $colDef');
        if (kDebugMode) debugPrint('✅ customers: added column $name');
      } catch (e) {
        if (e.toString().contains('duplicate column')) {
          // Đã có cột, bỏ qua
        } else {
          rethrow;
        }
      }
    }
  }

  /// Lấy tất cả khách hàng
  Future<List<CustomerModel>> getCustomers() async {
    try {
      final db = await database;
      await _ensureCustomersTableExists(db);

      final maps = await db.query('customers', orderBy: 'name ASC');
      return maps.map((map) => CustomerModel.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting customers from SQLite: $e');
      }
      return [];
    }
  }

  /// Lấy khách hàng theo ID
  Future<CustomerModel?> getCustomerById(String id) async {
    try {
      final db = await database;
      await _ensureCustomersTableExists(db);

      final maps = await db.query(
        'customers',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );

      if (maps.isEmpty) return null;
      return CustomerModel.fromMap(maps.first);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting customer by ID from SQLite: $e');
      }
      return null;
    }
  }

  /// Tìm kiếm khách hàng theo tên hoặc số điện thoại
  Future<List<CustomerModel>> searchCustomers(String query) async {
    try {
      final db = await database;
      await _ensureCustomersTableExists(db);

      final searchPattern = '%$query%';
      final maps = await db.query(
        'customers',
        where: 'name LIKE ? OR phone LIKE ?',
        whereArgs: [searchPattern, searchPattern],
        orderBy: 'name ASC',
      );

      return maps.map((map) => CustomerModel.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error searching customers from SQLite: $e');
      }
      return [];
    }
  }

  /// Thêm khách hàng
  Future<String> addCustomer(CustomerModel customer) async {
    try {
      final db = await database;
      await _ensureCustomersTableExists(db);

      await db.insert(
        'customers',
        customer.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      return customer.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding customer to SQLite: $e');
      }
      rethrow;
    }
  }

  /// Thêm hàng loạt khách hàng (batch insert, tối ưu cho import).
  Future<void> addCustomersBatch(List<CustomerModel> customers) async {
    if (customers.isEmpty) return;
    try {
      final db = await database;
      await _ensureCustomersTableExists(db);
      final batch = db.batch();
      for (final c in customers) {
        batch.insert(
          'customers',
          c.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding customers batch to SQLite: $e');
      }
      rethrow;
    }
  }

  /// Cập nhật khách hàng
  Future<int> updateCustomer(CustomerModel customer) async {
    try {
      final db = await database;
      await _ensureCustomersTableExists(db);

      return await db.update(
        'customers',
        customer.toMap(),
        where: 'id = ?',
        whereArgs: [customer.id],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating customer in SQLite: $e');
      }
      rethrow;
    }
  }

  /// Xóa khách hàng
  Future<int> deleteCustomer(String id) async {
    try {
      final db = await database;
      
      try {
        await db.rawQuery('SELECT 1 FROM customers LIMIT 1');
      } catch (e) {
        // Table chưa tồn tại, không có gì để xóa
        return 0;
      }

      return await db.delete(
        'customers',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting customer from SQLite: $e');
      }
      rethrow;
    }
  }

  // ========== DRAFT CARTS METHODS ==========

  /// Lưu giỏ hàng tạm (draft) vào database
  Future<void> saveDraftCart({
    required int tabId,
    required List<SaleItem> cartItems,
    required String paymentMethod,
    CustomerModel? customer,
    String? customerName,
    String? customerPhone,
    String? customerTaxCode,
    String? customerAddress,
    String? notes,
    required double discountPercent,
  }) async {
    final db = await database;
    
    final cartItemsJson = jsonEncode(cartItems.map((item) => item.toMap()).toList());
    final customerId = customer?.id;
    
    await db.insert(
      'draft_carts',
      {
        'tabId': tabId,
        'cartItems': cartItemsJson,
        'paymentMethod': paymentMethod,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerTaxCode': customerTaxCode,
        'customerAddress': customerAddress,
        'notes': notes,
        'discountPercent': discountPercent,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lấy giỏ hàng tạm (draft) từ database
  Future<Map<String, dynamic>?> getDraftCart(int tabId) async {
    final db = await database;
    
    final maps = await db.query(
      'draft_carts',
      where: 'tabId = ?',
      whereArgs: [tabId],
    );

    if (maps.isEmpty) return null;

    final map = maps.first;
    
    // Parse cartItems từ JSON string
    final cartItemsJson = map['cartItems'] as String? ?? '[]';
    final cartItemsList = jsonDecode(cartItemsJson) as List<dynamic>;
    final cartItems = cartItemsList
        .map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
        .toList();

    // Parse customer nếu có
    CustomerModel? customer;
    final customerId = map['customerId'] as String?;
    if (customerId != null && customerId.isNotEmpty) {
      // Lưu ý: Cần load customer từ CustomerService, tạm thời để null
      // UI sẽ tự load customer khi cần
    }

    return {
      'cartItems': cartItems,
      'paymentMethod': map['paymentMethod'] as String? ?? 'CASH',
      'customer': customer,
      'customerId': customerId,
      'customerName': map['customerName'] as String?,
      'customerPhone': map['customerPhone'] as String?,
      'customerTaxCode': map['customerTaxCode'] as String?,
      'customerAddress': map['customerAddress'] as String?,
      'notes': map['notes'] as String?,
      'discountPercent': (map['discountPercent'] as num?)?.toDouble() ?? 0.0,
    };
  }

  /// Xóa giỏ hàng tạm (draft) khỏi database
  Future<void> deleteDraftCart(int tabId) async {
    final db = await database;
    await db.delete(
      'draft_carts',
      where: 'tabId = ?',
      whereArgs: [tabId],
    );
  }

  /// Lấy tất cả draft carts
  Future<List<Map<String, dynamic>>> getAllDraftCarts() async {
    final db = await database;
    final maps = await db.query('draft_carts', orderBy: 'updatedAt DESC');

    return maps.map((map) {
      final cartItemsJson = map['cartItems'] as String? ?? '[]';
      final cartItemsList = jsonDecode(cartItemsJson) as List<dynamic>;
      final cartItems = cartItemsList
          .map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
          .toList();

      return {
        'tabId': map['tabId'] as int,
        'cartItems': cartItems,
        'paymentMethod': map['paymentMethod'] as String? ?? 'CASH',
        'customerId': map['customerId'] as String?,
        'customerName': map['customerName'] as String?,
        'customerPhone': map['customerPhone'] as String?,
        'customerTaxCode': map['customerTaxCode'] as String?,
        'customerAddress': map['customerAddress'] as String?,
        'notes': map['notes'] as String?,
        'discountPercent': (map['discountPercent'] as num?)?.toDouble() ?? 0.0,
        'updatedAt': map['updatedAt'] as String?,
      };
    }).toList();
  }

  // ========== STOCK HISTORY METHODS ==========

  /// Thêm bản ghi lịch sử tồn kho
  Future<String> addStockHistory(StockHistoryModel history) async {
    final db = await database;
    try {
      await db.insert(
        'stock_history',
        history.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return history.id;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error adding stock history to SQLite: $e');
      }
      rethrow;
    }
  }

  /// Lấy lịch sử tồn kho theo productId
  Future<List<StockHistoryModel>> getStockHistoryByProductId(
    String productId, {
    String? branchId,
    StockHistoryType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final db = await database;
    try {
      String whereClause = 'productId = ?';
      List<dynamic> whereArgs = [productId];

      if (branchId != null && branchId.isNotEmpty) {
        whereClause += ' AND branchId = ?';
        whereArgs.add(branchId);
      }

      if (type != null) {
        whereClause += ' AND type = ?';
        whereArgs.add(type.value);
      }

      if (startDate != null) {
        whereClause += ' AND timestamp >= ?';
        whereArgs.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        whereClause += ' AND timestamp <= ?';
        whereArgs.add(endDate.toIso8601String());
      }

      final maps = await db.query(
        'stock_history',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return maps.map((map) => StockHistoryModel.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting stock history from SQLite: $e');
      }
      return [];
    }
  }

  /// Lấy lịch sử tồn kho theo branchId
  Future<List<StockHistoryModel>> getStockHistoryByBranchId(
    String branchId, {
    StockHistoryType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final db = await database;
    try {
      String whereClause = 'branchId = ?';
      List<dynamic> whereArgs = [branchId];

      if (type != null) {
        whereClause += ' AND type = ?';
        whereArgs.add(type.value);
      }

      if (startDate != null) {
        whereClause += ' AND timestamp >= ?';
        whereArgs.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        whereClause += ' AND timestamp <= ?';
        whereArgs.add(endDate.toIso8601String());
      }

      final maps = await db.query(
        'stock_history',
        where: whereClause,
        whereArgs: whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return maps.map((map) => StockHistoryModel.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting stock history by branchId from SQLite: $e');
      }
      return [];
    }
  }

  /// Lấy tất cả lịch sử tồn kho
  Future<List<StockHistoryModel>> getAllStockHistory({
    String? productId,
    String? branchId,
    StockHistoryType? type,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    final db = await database;
    try {
      String whereClause = '1 = 1';
      List<dynamic> whereArgs = [];

      if (productId != null && productId.isNotEmpty) {
        whereClause += ' AND productId = ?';
        whereArgs.add(productId);
      }

      if (branchId != null && branchId.isNotEmpty) {
        whereClause += ' AND branchId = ?';
        whereArgs.add(branchId);
      }

      if (type != null) {
        whereClause += ' AND type = ?';
        whereArgs.add(type.value);
      }

      if (startDate != null) {
        whereClause += ' AND timestamp >= ?';
        whereArgs.add(startDate.toIso8601String());
      }

      if (endDate != null) {
        whereClause += ' AND timestamp <= ?';
        whereArgs.add(endDate.toIso8601String());
      }

      final maps = await db.query(
        'stock_history',
        where: whereClause,
        whereArgs: whereArgs.isEmpty ? null : whereArgs,
        orderBy: 'timestamp DESC',
        limit: limit,
      );

      return maps.map((map) => StockHistoryModel.fromMap(map)).toList();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error getting all stock history from SQLite: $e');
      }
      return [];
    }
  }

  /// Xóa lịch sử tồn kho theo ID
  Future<int> deleteStockHistory(String id) async {
    final db = await database;
    try {
      return await db.delete(
        'stock_history',
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error deleting stock history from SQLite: $e');
      }
      rethrow;
    }
  }

  // ========== SALES RETURNS METHODS ==========

  /// Thêm hóa đơn trả hàng
  Future<String> addSalesReturn(SalesReturnModel salesReturn) async {
    final db = await database;

    // Chuyển items thành JSON string
    final itemsJson = jsonEncode(salesReturn.items.map((item) => item.toMap()).toList());

    await db.insert(
      'sales_returns',
      {
        'id': salesReturn.id,
        'originalSaleId': salesReturn.originalSaleId,
        'customerId': salesReturn.customerId,
        'branchId': salesReturn.branchId,
        'items': itemsJson,
        'totalRefundAmount': salesReturn.totalRefundAmount,
        'reason': salesReturn.reason,
        'paymentMethod': salesReturn.paymentMethod,
        'timestamp': salesReturn.timestamp.toIso8601String(),
        'userId': salesReturn.userId,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    return salesReturn.id;
  }

  /// Lấy tất cả hóa đơn trả hàng
  Future<List<SalesReturnModel>> getSalesReturns({
    String? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    final List<Map<String, dynamic>> maps;

    String? whereClause;
    List<dynamic>? whereArgs;

    if (userId != null) {
      whereClause = 'userId = ?';
      whereArgs = [userId];
    }

    if (startDate != null && endDate != null) {
      if (whereClause != null) {
        whereClause += ' AND timestamp >= ? AND timestamp <= ?';
        whereArgs!.addAll([
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ]);
      } else {
        whereClause = 'timestamp >= ? AND timestamp <= ?';
        whereArgs = [
          startDate.toIso8601String(),
          endDate.toIso8601String(),
        ];
      }
    }

    maps = await db.query(
      'sales_returns',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
    );

    return maps.map((map) {
      // Parse items từ JSON string
      final itemsJson = map['items'] as String? ?? '[]';
      final items = SaleItem.fromJsonList(itemsJson);

      return SalesReturnModel(
        id: map['id'] as String,
        originalSaleId: map['originalSaleId'] as String,
        customerId: map['customerId'] as String?,
        branchId: map['branchId'] as String,
        items: items,
        totalRefundAmount: (map['totalRefundAmount'] as num).toDouble(),
        reason: map['reason'] as String,
        paymentMethod: map['paymentMethod'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        userId: map['userId'] as String,
      );
    }).toList();
  }
}

