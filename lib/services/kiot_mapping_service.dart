import '../models/product_model.dart';
import '../models/customer_model.dart';

/// Chuyển đổi dữ liệu từ KiotViet API (2.4 Hàng hóa, 2.6 Khách hàng) sang Model của app.
/// - Sản phẩm cha-con: nhóm biến thể (masterProductId != null) vào sản phẩm cha.
/// - Tồn kho: map mảng inventories theo từng chi nhánh (branchId -> onHand).
class KiotMappingService {
  /// Map branchId (int) từ KiotViet sang id chi nhánh (String) của app.
  /// Nếu null, dùng branchId.toString().
  final Map<int, String>? branchIdMapper;

  KiotMappingService({this.branchIdMapper});

  /// Chuẩn hóa key từ PascalCase (Webhook) sang camelCase (REST).
  static Map<String, dynamic> _normalizeKeys(Map<String, dynamic> json) {
    final result = <String, dynamic>{};
    for (final e in json.entries) {
      final key = _pascalToCamel(e.key);
      final value = e.value;
      if (value is Map<String, dynamic>) {
        result[key] = _normalizeKeys(value);
      } else if (value is List) {
        result[key] = value.map((x) => x is Map<String, dynamic> ? _normalizeKeys(x) : x).toList();
      } else {
        result[key] = value;
      }
    }
    return result;
  }

  static String _pascalToCamel(String s) {
    if (s.isEmpty) return s;
    return s[0].toLowerCase() + s.substring(1);
  }

  /// Map mảng inventories từ KiotViet vào cấu trúc tồn kho theo chi nhánh của app.
  /// KiotViet: [{ branchId, branchName, onHand, reserved, cost, ... }]
  /// Trả về: `Map<String, double>` (branchId -> onHand).
  Map<String, double> branchStockFromInventories(List<dynamic>? inventories) {
    final branchStock = <String, double>{};
    if (inventories == null) return branchStock;
    for (final e in inventories) {
      final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      final branchIdRaw = m['branchId'];
      if (branchIdRaw == null) continue;
      final kiotBranchId = branchIdRaw is int ? branchIdRaw : (branchIdRaw as num).toInt();
      final appBranchId = branchIdMapper?[kiotBranchId] ?? kiotBranchId.toString();
      final onHand = (m['onHand'] as num?)?.toDouble() ?? 0.0;
      branchStock[appBranchId] = onHand;
    }
    return branchStock;
  }

  /// Map mảng inventories sang `List<ProductInventory>` (giữ branchId theo app).
  List<ProductInventory> inventoriesFromKiot(List<dynamic>? inventories) {
    if (inventories == null) return [];
    return inventories.map((e) {
      final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
      final branchIdRaw = m['branchId'];
      final kiotBranchId = branchIdRaw is int ? branchIdRaw : (branchIdRaw as num?)?.toInt();
      final appBranchId = kiotBranchId != null ? (branchIdMapper?[kiotBranchId] ?? kiotBranchId.toString()) : '';
      final map = Map<String, dynamic>.from(m)..['branchId'] = appBranchId;
      return ProductInventory.fromMap(map);
    }).toList();
  }

  /// Map mảng lô & hạn sử dụng từ KiotViet (2.4.1, 2.12.1) sang `List<ProductBatchExpire>`.
  /// Nguồn: batchExpires, batches, batchInventories. Mỗi phần tử: batchName/batchCode, expiredDate/expireDate, onHand, branchId.
  List<ProductBatchExpire> batchExpiresFromKiot(List<dynamic>? list) {
    if (list == null || list.isEmpty) return [];
    return list.map((e) {
      final m = e is Map<String, dynamic> ? Map<String, dynamic>.from(e) : Map<String, dynamic>.from(e as Map);
      final branchIdRaw = m['branchId'];
      final kiotBranchId = branchIdRaw is int ? branchIdRaw : (branchIdRaw as num?)?.toInt();
      final appBranchId = kiotBranchId != null ? (branchIdMapper?[kiotBranchId] ?? kiotBranchId.toString()) : '';
      final map = Map<String, dynamic>.from(m)..['branchId'] = appBranchId;
      return ProductBatchExpire.fromMap(map);
    }).toList();
  }

  /// Chuyển một item hàng hóa KiotViet (REST hoặc Webhook đã normalize) thành ProductModel.
  /// [documentId] dùng làm id trong app; nếu null thì dùng kiotId.toString().
  /// Lô & Hạn sử dụng (2.4.1, 2.12.1): map từ manageBatch, batchInventories/batches vào isBatchExpireControl và batchExpires.
  ProductModel productFromKiotJson(Map<String, dynamic> json, {String? documentId}) {
    final normalized = _normalizeKeys(json);
    final kiotId = normalized['id'] is int ? normalized['id'] as int : (normalized['id'] as num?)?.toInt();
    final id = documentId ?? kiotId?.toString() ?? '';
    normalized['id'] = id;
    normalized['kiotId'] = kiotId;
    if (normalized['inventories'] != null) {
      final invList = normalized['inventories'] as List;
      normalized['inventories'] = invList.map((e) {
        final m = e is Map<String, dynamic> ? Map<String, dynamic>.from(e) : Map<String, dynamic>.from(e as Map);
        final branchIdRaw = m['branchId'];
        final kiotBranchId = branchIdRaw is int ? branchIdRaw : (branchIdRaw as num?)?.toInt();
        if (kiotBranchId != null && branchIdMapper != null) {
          m['branchId'] = branchIdMapper![kiotBranchId] ?? kiotBranchId.toString();
        } else if (branchIdRaw != null) {
          m['branchId'] = branchIdRaw.toString();
        }
        return m;
      }).toList();
    }

    // Lô & Hạn sử dụng (KiotViet 2.4.1, 2.12.1 — Batch & Expire Date)
    List<ProductBatchExpire> batchExpires = [];
    final batchSource = normalized['batchExpires'] ?? normalized['batches'] ?? normalized['batchInventories'];
    if (batchSource != null && batchSource is List && batchSource.isNotEmpty) {
      batchExpires = batchExpiresFromKiot(batchSource);
    } else if (normalized['inventories'] != null) {
      // Một số API trả về inventory theo lô ngay trong inventories[] (mỗi phần tử có batchName, expiredDate)
      final invList = normalized['inventories'] as List;
      for (final e in invList) {
        final m = e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map);
        if (m['batchName'] != null || m['batchCode'] != null || m['expiredDate'] != null) {
          batchExpires.addAll(batchExpiresFromKiot([m]));
        }
      }
    }
    final manageBatch = normalized['manageBatch'] as bool? ?? normalized['batchManagement'] as bool?;
    final isBatchExpireControl = manageBatch ?? (normalized['isBatchExpireControl'] as bool?) ?? batchExpires.isNotEmpty;
    normalized['batchExpires'] = batchExpires.map((b) => b.toMap()).toList();
    normalized['isBatchExpireControl'] = isBatchExpireControl;

    return ProductModel.fromJson(normalized);
  }

  /// Chuyển danh sách hàng hóa KiotViet thành `List<ProductModel>` với logic cha-con:
  /// - Nếu masterProductId != null: không tạo sản phẩm đơn lẻ, mà nhóm vào sản phẩm cha dưới dạng variant.
  /// - Sản phẩm cha có hasVariants = true và danh sách variants từ các item con.
  List<ProductModel> productsFromKiotList(List<dynamic> rawList) {
    if (rawList.isEmpty) return [];

    final items = rawList
        .map((e) => e is Map<String, dynamic> ? e : Map<String, dynamic>.from(e as Map))
        .toList();

    final byKiotId = <int, Map<String, dynamic>>{};
    for (final item in items) {
      final id = item['id'] is int ? item['id'] as int : (item['id'] as num?)?.toInt();
      if (id != null) byKiotId[id] = item;
    }

    final roots = <Map<String, dynamic>>[];
    final childrenByMaster = <int, List<Map<String, dynamic>>>{};

    for (final item in items) {
      final masterId = item['masterProductId'] is int
          ? item['masterProductId'] as int?
          : (item['masterProductId'] as num?)?.toInt();
      if (masterId == null) {
        roots.add(item);
      } else {
        childrenByMaster.putIfAbsent(masterId, () => []).add(item);
      }
    }

    final result = <ProductModel>[];
    for (final root in roots) {
      final rootKiotId = root['id'] is int ? root['id'] as int : (root['id'] as num?)?.toInt();
      if (rootKiotId == null) continue;

      final children = childrenByMaster[rootKiotId] ?? [];
      final hasVariants = (root['hasVariants'] == true) || children.isNotEmpty;

      if (!hasVariants || children.isEmpty) {
        result.add(productFromKiotJson(root));
        continue;
      }

      final variants = children.map((child) {
        final childKiotId = child['id'] is int ? child['id'] as int : (child['id'] as num?)?.toInt();
        final invList = child['inventories'] as List?;
        final branchStock = branchStockFromInventories(invList);
        final basePrice = (child['basePrice'] as num?)?.toDouble() ?? 0.0;
        final branchPrices = <String, double>{};
        for (final bid in branchStock.keys) {
          branchPrices[bid] = basePrice;
        }
        final cost = (invList?.isNotEmpty == true && invList!.first is Map)
            ? ((invList.first as Map)['cost'] as num?)?.toDouble() ?? 0.0
            : 0.0;

        return ProductVariant(
          id: childKiotId?.toString() ?? '',
          sku: child['code'] as String? ?? '',
          name: child['fullName'] as String? ?? child['name'] as String? ?? '',
          branchPrices: branchPrices,
          costPrice: cost,
          branchStock: branchStock,
          barcode: child['barCode'] as String? ?? child['barcode'] as String?,
        );
      }).toList();

      final rootProduct = productFromKiotJson(root);
      final mergedBranchStock = Map<String, double>.from(rootProduct.branchStock);
      for (final v in variants) {
        v.branchStock.forEach((branchId, qty) {
          mergedBranchStock[branchId] = (mergedBranchStock[branchId] ?? 0) + qty;
        });
      }

      result.add(rootProduct.copyWith(
        hasVariants: true,
        variants: variants,
        branchStock: mergedBranchStock,
      ));
    }

    return result;
  }

  /// Chuyển một item khách hàng KiotViet thành CustomerModel.
  CustomerModel customerFromKiotJson(Map<String, dynamic> json) {
    final normalized = _normalizeKeys(json);
    normalized['kiotId'] = normalized['id'] is int ? normalized['id'] : (normalized['id'] as num?)?.toInt();
    normalized['id'] = normalized['id']?.toString() ?? '';
    return CustomerModel.fromJson(normalized);
  }
}
