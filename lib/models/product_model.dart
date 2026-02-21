import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'unit_conversion.dart';

// ============== KiotViet-compatible sub-models (API 2.4) ==============

/// Thuộc tính sản phẩm (Màu sắc, Size...). KiotViet: attributes[] - attributeName, attributeValue.
class ProductAttribute {
  /// ID sản phẩm (KiotViet: productId long). Có thể null khi tạo mới.
  final int? productId;
  /// Tên thuộc tính (VD: "Màu sắc", "Size"). KiotViet: attributeName
  final String attributeName;
  /// Giá trị thuộc tính (VD: "Đỏ", "M"). KiotViet: attributeValue
  final String attributeValue;

  ProductAttribute({
    this.productId,
    required this.attributeName,
    required this.attributeValue,
  });

  factory ProductAttribute.fromMap(Map<String, dynamic> map) {
    return ProductAttribute(
      productId: map['productId'] is int ? map['productId'] as int : (map['productId'] as num?)?.toInt(),
      attributeName: map['attributeName'] as String? ?? '',
      attributeValue: map['attributeValue'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'attributeName': attributeName,
        'attributeValue': attributeValue,
      };
}

/// Tồn kho theo chi nhánh. KiotViet: inventories[] - branchId, branchName, onHand, reserved, cost.
class ProductInventory {
  /// ID sản phẩm (KiotViet: productId). Có thể null khi nhúng trong product.
  final int? productId;
  final String? productCode;
  final String? productName;
  /// ID chi nhánh (KiotViet: branchId int). Lưu dạng String để đồng bộ với BranchModel.id.
  final String branchId;
  /// Tên chi nhánh (KiotViet: branchName)
  final String branchName;
  /// Tồn kho hiện có (KiotViet: onHand)
  final double onHand;
  /// Đã đặt/giữ (KiotViet: reserved)
  final double reserved;
  /// Giá vốn (KiotViet: cost)
  final double cost;
  /// Số lượng đặt từ NCC (KiotViet: onOrder) - optional trong response
  final double? onOrder;
  /// Định mức tồn thấp nhất (KiotViet: minQuality)
  final double? minQuality;
  /// Định mức tồn cao nhất (KiotViet: maxQuality)
  final double? maxQuality;

  ProductInventory({
    this.productId,
    this.productCode,
    this.productName,
    required this.branchId,
    required this.branchName,
    this.onHand = 0,
    this.reserved = 0,
    this.cost = 0,
    this.onOrder,
    this.minQuality,
    this.maxQuality,
  });

  factory ProductInventory.fromMap(Map<String, dynamic> map) {
    final branchId = map['branchId'];
    return ProductInventory(
      productId: map['productId'] is int ? map['productId'] as int : (map['productId'] as num?)?.toInt(),
      productCode: map['productCode'] as String?,
      productName: map['productName'] as String?,
      branchId: branchId?.toString() ?? '',
      branchName: map['branchName'] as String? ?? '',
      onHand: (map['onHand'] as num?)?.toDouble() ?? 0,
      reserved: (map['reserved'] as num?)?.toDouble() ?? 0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0,
      onOrder: (map['onOrder'] as num?)?.toDouble(),
      minQuality: (map['minQuality'] as num?)?.toDouble(),
      maxQuality: (map['maxQuality'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productCode': productCode,
        'productName': productName,
        'branchId': branchId,
        'branchName': branchName,
        'onHand': onHand,
        'reserved': reserved,
        'cost': cost,
        'onOrder': onOrder,
        'minQuality': minQuality,
        'maxQuality': maxQuality,
      };
}

/// Lô hàng & Hạn sử dụng (KiotViet 2.4.1, 2.12.1 — Batch & Expire Date).
/// Dùng cho ngành Dược, Thực phẩm.
class ProductBatchExpire {
  /// Mã/Tên lô (KiotViet: batchName)
  final String batchName;
  /// Ngày hết hạn (KiotViet: expiredDate)
  final DateTime? expireDate;
  /// Tồn kho lô tại chi nhánh (KiotViet: onHand)
  final double onHand;
  /// ID chi nhánh (KiotViet: branchId). Lưu String để đồng bộ BranchModel.id.
  final String branchId;

  ProductBatchExpire({
    required this.batchName,
    this.expireDate,
    this.onHand = 0,
    required this.branchId,
  });

  factory ProductBatchExpire.fromMap(Map<String, dynamic> map) {
    DateTime? exp;
    if (map['expireDate'] != null) {
      if (map['expireDate'] is DateTime) {
        exp = map['expireDate'] as DateTime;
      } else if (map['expireDate'] is String) {
        exp = DateTime.tryParse(map['expireDate'] as String);
      } else if (map['expiredDate'] != null) {
        final s = map['expiredDate'].toString();
        exp = DateTime.tryParse(s);
      }
    } else if (map['expiredDate'] != null) {
      final v = map['expiredDate'];
      exp = v is DateTime ? v : DateTime.tryParse(v.toString());
    }
    return ProductBatchExpire(
      batchName: map['batchName'] as String? ?? map['batchCode'] as String? ?? '',
      expireDate: exp,
      onHand: (map['onHand'] as num?)?.toDouble() ?? 0,
      branchId: map['branchId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'batchName': batchName,
        'expireDate': expireDate?.toIso8601String(),
        'onHand': onHand,
        'branchId': branchId,
      };
}

// ============== Biến thể & Sản phẩm ==============

/// Model đại diện cho biến thể sản phẩm (ví dụ: "S - Đỏ", "M - Xanh")
class ProductVariant {
  final String id;
  final String sku; // Mã SKU của biến thể
  final String name; // Tên biến thể (VD: "S - Đỏ")
  final Map<String, double> branchPrices; // Giá bán theo chi nhánh (Key: branchId)
  final double costPrice; // Giá nhập
  final Map<String, double> branchStock; // Số lượng tồn kho theo chi nhánh (Key: branchId)
  final String? barcode; // Mã vạch của biến thể

  ProductVariant({
    required this.id,
    required this.sku,
    required this.name,
    required this.branchPrices,
    required this.costPrice,
    required this.branchStock,
    this.barcode,
  });

  /// Giá bán mặc định (backward compatibility - lấy giá đầu tiên)
  double get price => branchPrices.values.isNotEmpty ? branchPrices.values.first : 0.0;

  /// Tồn kho mặc định (backward compatibility - tổng tồn kho tất cả chi nhánh)
  double get stock => branchStock.values.fold(0.0, (total, stock) => total + stock);

  /// Tạo ProductVariant từ Map
  factory ProductVariant.fromMap(Map<String, dynamic> map) {
    // Xử lý branchPrices
    Map<String, double> branchPrices = {};
    if (map['branchPrices'] != null) {
      if (map['branchPrices'] is Map) {
        branchPrices = Map<String, double>.from(
          (map['branchPrices'] as Map).map((key, value) => MapEntry(
                key.toString(),
                (value as num).toDouble(),
              )),
        );
      }
    } else if (map['price'] != null) {
      // Backward compatibility: chuyển price cũ sang branchPrices với key 'default'
      branchPrices['default'] = (map['price'] as num).toDouble();
    }

    // Xử lý branchStock
    Map<String, double> branchStock = {};
    if (map['branchStock'] != null) {
      if (map['branchStock'] is Map) {
        branchStock = Map<String, double>.from(
          (map['branchStock'] as Map).map((key, value) => MapEntry(
                key.toString(),
                (value as num).toDouble(),
              )),
        );
      }
    } else if (map['stock'] != null) {
      // Backward compatibility: chuyển stock cũ sang branchStock với key 'default'
      branchStock['default'] = (map['stock'] as num).toDouble();
    }

    return ProductVariant(
      id: map['id'] as String? ?? '',
      sku: map['sku'] as String? ?? '',
      name: map['name'] as String? ?? '',
      branchPrices: branchPrices,
      costPrice: (map['costPrice'] as num?)?.toDouble() ?? 0.0,
      branchStock: branchStock,
      barcode: map['barcode'] as String?,
    );
  }

  /// Chuyển đổi sang Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sku': sku,
      'name': name,
      'branchPrices': branchPrices,
      'price': price, // Backward compatibility
      'costPrice': costPrice,
      'branchStock': branchStock,
      'stock': stock, // Backward compatibility
      'barcode': barcode,
    };
  }

  /// Tạo bản copy với các trường được cập nhật
  ProductVariant copyWith({
    String? id,
    String? sku,
    String? name,
    Map<String, double>? branchPrices,
    double? costPrice,
    Map<String, double>? branchStock,
    String? barcode,
  }) {
    return ProductVariant(
      id: id ?? this.id,
      sku: sku ?? this.sku,
      name: name ?? this.name,
      branchPrices: branchPrices ?? this.branchPrices,
      costPrice: costPrice ?? this.costPrice,
      branchStock: branchStock ?? this.branchStock,
      barcode: barcode ?? this.barcode,
    );
  }
}

/// Model đại diện cho sản phẩm/hàng hóa. Tương thích KiotViet API 2.4 (trang 8–12).
class ProductModel {
  /// ID nội bộ (Firestore document id)
  final String id;
  /// ID hàng hóa từ KiotViet (KiotViet: id long). Dùng cho migration.
  final int? kiotId;
  /// Mã hàng hóa (KiotViet: code)
  final String? code;
  final String name;
  /// Tên đầy đủ bao gồm thuộc tính và đơn vị (KiotViet: fullName)
  final String? fullName;
  /// Danh sách đơn vị quy đổi (KiotViet: units[] - id, code, name, fullName, unit, conversionValue, basePrice)
  final List<UnitConversion> units;
  final Map<String, double> branchPrices;
  /// Bảng giá theo nhóm khách hàng (Pricebooks): tên nhóm (VIP, Sỉ, ...) -> giá bán.
  final Map<String, double> groupPrices;
  final double importPrice;
  final Map<String, double> branchStock;
  final String? barcode; // KiotViet: barCode
  final String? category; // Backward compatibility; KiotViet: categoryName
  final String? categoryId; // KiotViet: categoryId int
  final String? categoryName; // KiotViet: categoryName
  final String? manufacturer;
  final String? sku;
  final String? imageUrl; // Ảnh đầu (backward). KiotViet: images[]
  /// Danh sách hình ảnh (KiotViet: images[])
  final List<String> images;
  final double? minStock; // KiotViet: minQuantity / minQuality
  final double? maxStock; // KiotViet: maxQuantity / maxQuality
  /// ID hàng hóa đơn vị cơ bản (KiotViet: masterUnitId). Null nếu là đơn vị cơ bản.
  final int? masterUnitId;
  /// ID hàng hóa cùng loại / cha biến thể (KiotViet: masterProductId)
  final int? masterProductId;
  /// Sản phẩm có thuộc tính biến thể hay không (KiotViet: hasVariants)
  final bool hasVariants;
  /// Thuộc tính động: Màu sắc, Size... (KiotViet: attributes[])
  final List<ProductAttribute> attributes;
  /// Tồn kho đa chi nhánh (KiotViet: inventories[] - branchId, branchName, onHand, reserved, cost)
  final List<ProductInventory> inventories;
  final List<ProductVariant> variants;
  final bool isInventoryManaged;
  final bool isImeiManaged;
  final bool isBatchManaged;
  /// Quản lý hàng theo Lô & Hạn sử dụng (KiotViet 2.4.1, 2.12.1 — Batch & Expire). Dùng cho Dược, Thực phẩm.
  final bool isBatchExpireControl;
  /// Danh sách lô hàng theo chi nhánh (batchName, expireDate, onHand, branchId).
  final List<ProductBatchExpire> batchExpires;
  final bool isSellable; // KiotViet: allowsSale
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  /// ID cửa hàng (KiotViet: retailerId)
  final int? retailerId;
  /// ID thương hiệu (KiotViet: tradeMarkId)
  final int? tradeMarkId;
  final String? tradeMarkName;
  /// Mô tả (KiotViet: description)
  final String? description;
  /// Trọng lượng (KiotViet: weight)
  final double? weight;

  ProductModel({
    required this.id,
    this.kiotId,
    this.code,
    required this.name,
    this.fullName,
    this.units = const [],
    required this.branchPrices,
    this.groupPrices = const {},
    required this.importPrice,
    required this.branchStock,
    this.barcode,
    this.category,
    this.categoryId,
    this.categoryName,
    this.manufacturer,
    this.sku,
    this.imageUrl,
    this.images = const [],
    this.minStock,
    this.maxStock,
    this.masterUnitId,
    this.masterProductId,
    this.hasVariants = false,
    this.attributes = const [],
    this.inventories = const [],
    this.variants = const [],
    this.isInventoryManaged = true,
    this.isImeiManaged = false,
    this.isBatchManaged = false,
    this.isBatchExpireControl = false,
    this.batchExpires = const [],
    this.isSellable = true,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.retailerId,
    this.tradeMarkId,
    this.tradeMarkName,
    this.description,
    this.weight,
  });

  /// Getter cho backward compatibility - trả về đơn vị đầu tiên nếu có
  String get unit {
    if (units.isNotEmpty) {
      return units.first.unitName;
    }
    return ''; // Mặc định trống
  }

  /// Giá bán mặc định (backward compatibility - lấy giá đầu tiên hoặc tổng từ variants)
  double get price {
    if (branchPrices.isNotEmpty) {
      return branchPrices.values.first;
    }
    if (variants.isNotEmpty) {
      return variants.first.price;
    }
    return 0.0;
  }

  /// Giá bán theo nhóm khách hàng (Bảng giá). Ưu tiên nhóm đầu tiên trùng trong [customerGroups].
  double getPriceForGroups(List<String> customerGroups) {
    if (customerGroups.isEmpty || groupPrices.isEmpty) return price;
    for (final g in customerGroups) {
      final groupPrice = groupPrices[g];
      if (groupPrice != null) return groupPrice;
    }
    return price;
  }

  /// Tồn kho mặc định (backward compatibility - tổng tồn kho tất cả chi nhánh và variants)
  double get stock {
    double total = branchStock.values.fold(0.0, (acc, stock) => acc + stock);
    if (variants.isNotEmpty) {
      total = variants.fold(0.0, (acc, variant) => acc + variant.stock);
    }
    return total;
  }

  /// Tạo ProductModel từ Firestore document. Hỗ trợ cả KiotViet payload và dữ liệu nội bộ.
  factory ProductModel.fromFirestore(Map<String, dynamic> data, String id) {
    // Parse attributes (KiotViet)
    List<ProductAttribute> attributes = [];
    if (data['attributes'] != null) {
      final list = data['attributes'] as List<dynamic>;
      attributes = list.map((e) => ProductAttribute.fromMap(Map<String, dynamic>.from(e))).toList();
    }

    // Parse inventories (KiotViet - tồn kho đa chi nhánh)
    List<ProductInventory> inventories = [];
    if (data['inventories'] != null) {
      final list = data['inventories'] as List<dynamic>;
      inventories = list.map((e) => ProductInventory.fromMap(Map<String, dynamic>.from(e))).toList();
    }

    // Parse variants từ Firestore
    List<ProductVariant> variants = [];
    if (data['variants'] != null) {
      final variantsList = data['variants'] as List<dynamic>;
      variants = variantsList
          .map((v) => ProductVariant.fromMap(Map<String, dynamic>.from(v)))
          .toList();
    }

    // Parse batchExpires (KiotViet 2.4.1, 2.12.1 — Lô & Hạn sử dụng)
    List<ProductBatchExpire> batchExpires = [];
    if (data['batchExpires'] != null && data['batchExpires'] is List) {
      batchExpires = (data['batchExpires'] as List<dynamic>)
          .map((e) => ProductBatchExpire.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else if (data['batches'] != null && data['batches'] is List) {
      batchExpires = (data['batches'] as List<dynamic>)
          .map((e) => ProductBatchExpire.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    final isBatchExpireControl = data['isBatchExpireControl'] as bool? ?? data['isBatchManaged'] as bool? ?? false;

    // Xử lý branchPrices
    Map<String, double> branchPrices = {};
    if (data['branchPrices'] != null) {
      branchPrices = Map<String, double>.from(
        (data['branchPrices'] as Map).map((key, value) => MapEntry(
              key.toString(),
              (value as num).toDouble(),
            )),
      );
    } else if (data['price'] != null) {
      branchPrices['default'] = (data['price'] as num).toDouble();
    }

    Map<String, double> groupPrices = {};
    if (data['groupPrices'] != null && data['groupPrices'] is Map) {
      groupPrices = Map<String, double>.from(
        (data['groupPrices'] as Map).map((key, value) => MapEntry(
              key.toString(),
              (value as num).toDouble(),
            )),
      );
    }

    // Xử lý branchStock: ưu tiên từ inventories (KiotViet), sau đó branchStock, cuối cùng stock
    Map<String, double> branchStock = {};
    if (inventories.isNotEmpty) {
      for (var inv in inventories) {
        branchStock[inv.branchId] = inv.onHand;
      }
    }
    if (data['branchStock'] != null) {
      branchStock.addAll(Map<String, double>.from(
        (data['branchStock'] as Map).map((key, value) => MapEntry(
              key.toString(),
              (value as num).toDouble(),
            )),
      ));
    }
    if (branchStock.isEmpty && data['stock'] != null) {
      branchStock['default'] = (data['stock'] as num).toDouble();
    }

    if (variants.isNotEmpty) {
      for (var variant in variants) {
        variant.branchStock.forEach((branchId, stock) {
          branchStock[branchId] = (branchStock[branchId] ?? 0.0) + stock;
        });
      }
    }

    // Parse units từ Firestore
    List<UnitConversion> units = [];
    if (data['units'] != null) {
      final unitsList = data['units'] as List<dynamic>?;
      if (unitsList != null) {
        units = unitsList
            .map((u) => UnitConversion.fromMap(Map<String, dynamic>.from(u)))
            .toList();
      }
    } else if (data['unit'] != null) {
      final oldUnit = data['unit'] as String;
      if (oldUnit.isNotEmpty) {
        units = [
          UnitConversion(
            id: 'default',
            unitName: oldUnit,
            conversionValue: 1.0,
            price: branchPrices.values.isNotEmpty ? branchPrices.values.first : 0.0,
            barcode: data['barcode'] as String?,
          ),
        ];
      }
    }

    // Images: KiotViet là mảng; nội bộ có thể imageUrl string
    List<String> images = [];
    if (data['images'] != null) {
      final imgs = data['images'];
      if (imgs is List) {
        for (var e in imgs) {
          if (e is Map && e['Image'] != null) {
            images.add(e['Image'].toString());
          } else if (e is String) {
            images.add(e);
          }
        }
      }
    }
    if (images.isEmpty && data['imageUrl'] != null) {
      images = [data['imageUrl'] as String];
    }

    return ProductModel(
      id: id,
      kiotId: data['kiotId'] is int ? data['kiotId'] as int : (data['kiotId'] as num?)?.toInt(),
      code: data['code'] as String?,
      name: data['name'] ?? '',
      fullName: data['fullName'] as String?,
      units: units,
      branchPrices: branchPrices,
      groupPrices: groupPrices,
      importPrice: (data['importPrice'] ?? data['basePrice'] ?? 0).toDouble(),
      branchStock: branchStock,
      barcode: data['barcode'] as String? ?? data['barCode'] as String?,
      category: data['category'],
      categoryId: data['categoryId']?.toString(),
      categoryName: data['categoryName'] as String?,
      manufacturer: data['manufacturer'],
      sku: data['sku'],
      imageUrl: data['imageUrl'] as String?,
      images: images,
      minStock: data['minStock'] != null ? (data['minStock'] as num).toDouble() : null,
      maxStock: data['maxStock'] != null ? (data['maxStock'] as num).toDouble() : null,
      masterUnitId: data['masterUnitId'] is int ? data['masterUnitId'] as int : (data['masterUnitId'] as num?)?.toInt(),
      masterProductId: data['masterProductId'] is int ? data['masterProductId'] as int : (data['masterProductId'] as num?)?.toInt(),
      hasVariants: data['hasVariants'] ?? false,
      attributes: attributes,
      inventories: inventories,
      variants: variants,
      isInventoryManaged: data['isInventoryManaged'] ?? true,
      isImeiManaged: data['isImeiManaged'] ?? false,
      isBatchManaged: data['isBatchManaged'] ?? false,
      isBatchExpireControl: isBatchExpireControl,
      batchExpires: batchExpires,
      isSellable: data['isSellable'] ?? data['allowsSale'] ?? true,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
      isActive: data['isActive'] ?? true,
      retailerId: data['retailerId'] is int ? data['retailerId'] as int : (data['retailerId'] as num?)?.toInt(),
      tradeMarkId: data['tradeMarkId'] is int ? data['tradeMarkId'] as int : (data['tradeMarkId'] as num?)?.toInt(),
      tradeMarkName: data['tradeMarkName'] as String?,
      description: data['description'] as String?,
      weight: data['weight'] != null ? (data['weight'] as num).toDouble() : null,
    );
  }

  /// Tạo ProductModel từ JSON (KiotViet API response hoặc nội bộ).
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    List<ProductAttribute> attributes = [];
    if (json['attributes'] != null) {
      final list = json['attributes'] as List<dynamic>;
      attributes = list.map((e) => ProductAttribute.fromMap(Map<String, dynamic>.from(e))).toList();
    }

    List<ProductInventory> inventories = [];
    if (json['inventories'] != null) {
      final list = json['inventories'] as List<dynamic>;
      inventories = list.map((e) => ProductInventory.fromMap(Map<String, dynamic>.from(e))).toList();
    }

    List<ProductVariant> variants = [];
    if (json['variants'] != null) {
      final variantsList = json['variants'] as List<dynamic>;
      variants = variantsList
          .map((v) => ProductVariant.fromMap(Map<String, dynamic>.from(v)))
          .toList();
    }

    Map<String, double> branchPrices = {};
    if (json['branchPrices'] != null) {
      branchPrices = Map<String, double>.from(
        (json['branchPrices'] as Map).map((key, value) => MapEntry(
              key.toString(),
              (value as num).toDouble(),
            )),
      );
    } else if (json['price'] != null) {
      branchPrices['default'] = (json['price'] as num).toDouble();
    }

    Map<String, double> groupPrices = {};
    if (json['groupPrices'] != null && json['groupPrices'] is Map) {
      groupPrices = Map<String, double>.from(
        (json['groupPrices'] as Map).map((key, value) => MapEntry(
              key.toString(),
              (value as num).toDouble(),
            )),
      );
    }

    Map<String, double> branchStock = {};
    if (inventories.isNotEmpty) {
      for (var inv in inventories) {
        branchStock[inv.branchId] = inv.onHand;
      }
    }
    if (json['branchStock'] != null) {
      branchStock.addAll(Map<String, double>.from(
        (json['branchStock'] as Map).map((key, value) => MapEntry(
              key.toString(),
              (value as num).toDouble(),
            )),
      ));
    }
    if (branchStock.isEmpty && json['stock'] != null) {
      branchStock['default'] = (json['stock'] as num).toDouble();
    }

    if (variants.isNotEmpty) {
      for (var variant in variants) {
        variant.branchStock.forEach((branchId, stock) {
          branchStock[branchId] = (branchStock[branchId] ?? 0.0) + stock;
        });
      }
    }

    List<UnitConversion> units = [];
    if (json['units'] != null) {
      final unitsList = json['units'] as List<dynamic>?;
      if (unitsList != null) {
        units = unitsList
            .map((u) => UnitConversion.fromMap(Map<String, dynamic>.from(u)))
            .toList();
      }
    } else if (json['unit'] != null) {
      final oldUnit = json['unit'] as String;
      if (oldUnit.isNotEmpty) {
        units = [
          UnitConversion(
            id: 'default',
            unitName: oldUnit,
            conversionValue: 1.0,
            price: branchPrices.values.isNotEmpty ? branchPrices.values.first : 0.0,
            barcode: json['barcode'] as String?,
          ),
        ];
      }
    }

    List<String> images = [];
    if (json['images'] != null) {
      final imgs = json['images'];
      if (imgs is List) {
        for (var e in imgs) {
          if (e is Map && e['Image'] != null) {
            images.add(e['Image'].toString());
          } else if (e is String) {
            images.add(e);
          }
        }
      }
    }
    if (images.isEmpty && json['imageUrl'] != null) {
      images = [json['imageUrl'] as String];
    }

    List<ProductBatchExpire> batchExpires = [];
    if (json['batchExpires'] != null && json['batchExpires'] is List) {
      batchExpires = (json['batchExpires'] as List<dynamic>)
          .map((e) => ProductBatchExpire.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } else if (json['batches'] != null && json['batches'] is List) {
      batchExpires = (json['batches'] as List<dynamic>)
          .map((e) => ProductBatchExpire.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    final isBatchExpireControl = json['isBatchExpireControl'] as bool? ?? json['isBatchManaged'] as bool? ?? false;

    return ProductModel(
      id: json['id']?.toString() ?? '',
      kiotId: json['kiotId'] is int ? json['kiotId'] as int : (json['kiotId'] as num?)?.toInt(),
      code: json['code'] as String?,
      name: json['name'] ?? '',
      fullName: json['fullName'] as String?,
      units: units,
      branchPrices: branchPrices,
      groupPrices: groupPrices,
      importPrice: (json['importPrice'] ?? json['basePrice'] ?? 0).toDouble(),
      branchStock: branchStock,
      barcode: json['barcode'] as String? ?? json['barCode'] as String?,
      category: json['category'],
      categoryId: json['categoryId']?.toString(),
      categoryName: json['categoryName'] as String?,
      manufacturer: json['manufacturer'],
      sku: json['sku'],
      imageUrl: json['imageUrl'] as String?,
      images: images,
      minStock: json['minStock'] != null ? (json['minStock'] as num).toDouble() : null,
      maxStock: json['maxStock'] != null ? (json['maxStock'] as num).toDouble() : null,
      masterUnitId: json['masterUnitId'] is int ? json['masterUnitId'] as int : (json['masterUnitId'] as num?)?.toInt(),
      masterProductId: json['masterProductId'] is int ? json['masterProductId'] as int : (json['masterProductId'] as num?)?.toInt(),
      hasVariants: json['hasVariants'] ?? false,
      attributes: attributes,
      inventories: inventories,
      variants: variants,
      isInventoryManaged: json['isInventoryManaged'] ?? true,
      isImeiManaged: json['isImeiManaged'] ?? false,
      isBatchManaged: json['isBatchManaged'] ?? false,
      isBatchExpireControl: isBatchExpireControl,
      batchExpires: batchExpires,
      isSellable: json['isSellable'] ?? json['allowsSale'] ?? true,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
      isActive: json['isActive'] ?? true,
      retailerId: json['retailerId'] is int ? json['retailerId'] as int : (json['retailerId'] as num?)?.toInt(),
      tradeMarkId: json['tradeMarkId'] is int ? json['tradeMarkId'] as int : (json['tradeMarkId'] as num?)?.toInt(),
      tradeMarkName: json['tradeMarkName'] as String?,
      description: json['description'] as String?,
      weight: json['weight'] != null ? (json['weight'] as num).toDouble() : null,
    );
  }

  /// Tạo ProductModel từ Map (dùng cho SQLite). Các list lưu dạng JSON string.
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    List<ProductAttribute> attributes = [];
    if (map['attributes'] != null) {
      try {
        final s = map['attributes'] is String ? map['attributes'] as String : null;
        if (s != null && s.isNotEmpty) {
          final decoded = jsonDecode(s) as List<dynamic>;
          attributes = decoded.map((e) => ProductAttribute.fromMap(Map<String, dynamic>.from(e))).toList();
        }
      } catch (_) {}
    }

    List<ProductInventory> inventories = [];
    if (map['inventories'] != null) {
      try {
        final s = map['inventories'] is String ? map['inventories'] as String : null;
        if (s != null && s.isNotEmpty) {
          final decoded = jsonDecode(s) as List<dynamic>;
          inventories = decoded.map((e) => ProductInventory.fromMap(Map<String, dynamic>.from(e))).toList();
        }
      } catch (_) {}
    }

    List<ProductVariant> variants = [];
    if (map['variants'] != null) {
      try {
        final variantsJson = map['variants'] as String;
        if (variantsJson.isNotEmpty) {
          final decoded = jsonDecode(variantsJson) as List<dynamic>;
          variants = decoded
              .map((v) => ProductVariant.fromMap(Map<String, dynamic>.from(v)))
              .toList();
        }
      } catch (_) {}
    }

    List<ProductBatchExpire> batchExpires = [];
    if (map['batchExpires'] != null) {
      try {
        final s = map['batchExpires'] is String ? map['batchExpires'] as String : null;
        if (s != null && s.isNotEmpty) {
          final decoded = jsonDecode(s) as List<dynamic>;
          batchExpires = decoded.map((e) => ProductBatchExpire.fromMap(Map<String, dynamic>.from(e))).toList();
        }
      } catch (_) {}
    }
    final isBatchExpireControl = (map['isBatchExpireControl'] as int?) == 1 || map['isBatchExpireControl'] == true;

    Map<String, double> branchPrices = {};
    if (map['branchPrices'] != null) {
      try {
        final pricesJson = map['branchPrices'] as String;
        if (pricesJson.isNotEmpty) {
          final decoded = jsonDecode(pricesJson) as Map<String, dynamic>;
          branchPrices = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
        }
      } catch (_) {}
    }
    if (branchPrices.isEmpty && map['price'] != null) {
      branchPrices['default'] = (map['price'] as num).toDouble();
    }

    Map<String, double> groupPrices = {};
    if (map['groupPrices'] != null) {
      try {
        final gpJson = map['groupPrices'] as String;
        if (gpJson.isNotEmpty) {
          final decoded = jsonDecode(gpJson) as Map<String, dynamic>;
          groupPrices = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
        }
      } catch (_) {}
    }

    Map<String, double> branchStock = {};
    if (inventories.isNotEmpty) {
      for (var inv in inventories) {
        branchStock[inv.branchId] = inv.onHand;
      }
    }
    if (map['branchStock'] != null) {
      try {
        final stockJson = map['branchStock'] as String;
        if (stockJson.isNotEmpty) {
          final decoded = jsonDecode(stockJson) as Map<String, dynamic>;
          branchStock.addAll(decoded.map((key, value) => MapEntry(key, (value as num).toDouble())));
        }
      } catch (_) {}
    }
    if (branchStock.isEmpty && map['stock'] != null) {
      branchStock['default'] = (map['stock'] as num?)?.toDouble() ?? 0.0;
    }

    if (variants.isNotEmpty) {
      for (var variant in variants) {
        variant.branchStock.forEach((branchId, stock) {
          branchStock[branchId] = (branchStock[branchId] ?? 0.0) + stock;
        });
      }
    }

    List<UnitConversion> units = [];
    if (map['units'] != null) {
      try {
        final unitsJson = map['units'] as String;
        if (unitsJson.isNotEmpty) {
          final decoded = jsonDecode(unitsJson) as List<dynamic>;
          units = decoded.map((u) => UnitConversion.fromMap(Map<String, dynamic>.from(u))).toList();
        }
      } catch (_) {}
    }
    if (units.isEmpty && map['unit'] != null) {
      final oldUnit = map['unit'] as String;
      if (oldUnit.isNotEmpty) {
        units = [
          UnitConversion(
            id: 'default',
            unitName: oldUnit,
            conversionValue: 1.0,
            price: branchPrices.values.isNotEmpty ? branchPrices.values.first : 0.0,
            barcode: map['barcode'] as String?,
          ),
        ];
      }
    }

    List<String> images = [];
    if (map['images'] != null) {
      try {
        final s = map['images'] is String ? map['images'] as String : null;
        if (s != null && s.isNotEmpty) {
          final decoded = jsonDecode(s) as List<dynamic>;
          images = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }
    if (images.isEmpty && map['imageUrl'] != null) images = [map['imageUrl'] as String];

    return ProductModel(
      id: map['id'] as String,
      kiotId: map['kiotId'] is int ? map['kiotId'] as int : (map['kiotId'] as num?)?.toInt(),
      code: map['code'] as String?,
      name: map['name'] as String,
      fullName: map['fullName'] as String?,
      units: units,
      branchPrices: branchPrices,
      groupPrices: groupPrices,
      importPrice: (map['importPrice'] as num?)?.toDouble() ?? 0.0,
      branchStock: branchStock,
      barcode: map['barcode'] as String?,
      category: map['category'] as String?,
      categoryId: map['categoryId'] as String?,
      categoryName: map['categoryName'] as String?,
      manufacturer: map['manufacturer'] as String?,
      sku: map['sku'] as String?,
      imageUrl: map['imageUrl'] as String?,
      images: images,
      minStock: map['minStock'] != null ? (map['minStock'] as num).toDouble() : null,
      maxStock: map['maxStock'] != null ? (map['maxStock'] as num).toDouble() : null,
      masterUnitId: map['masterUnitId'] is int ? map['masterUnitId'] as int : (map['masterUnitId'] as num?)?.toInt(),
      masterProductId: map['masterProductId'] is int ? map['masterProductId'] as int : (map['masterProductId'] as num?)?.toInt(),
      hasVariants: (map['hasVariants'] as int?) == 1,
      attributes: attributes,
      inventories: inventories,
      variants: variants,
      isInventoryManaged: (map['isInventoryManaged'] as int?) != 0,
      isImeiManaged: (map['isImeiManaged'] as int?) == 1,
      isBatchManaged: (map['isBatchManaged'] as int?) == 1,
      isBatchExpireControl: isBatchExpireControl,
      batchExpires: batchExpires,
      isSellable: (map['isSellable'] as int?) != 0,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
      isActive: (map['isActive'] as int?) == 1,
      retailerId: map['retailerId'] is int ? map['retailerId'] as int : (map['retailerId'] as num?)?.toInt(),
      tradeMarkId: map['tradeMarkId'] is int ? map['tradeMarkId'] as int : (map['tradeMarkId'] as num?)?.toInt(),
      tradeMarkName: map['tradeMarkName'] as String?,
      description: map['description'] as String?,
      weight: map['weight'] != null ? (map['weight'] as num).toDouble() : null,
    );
  }

  /// Chuyển đổi sang JSON (KiotViet-compatible + nội bộ).
  Map<String, dynamic> toJson() {
    double totalStock = stock;
    if (variants.isNotEmpty) {
      totalStock = variants.fold(0.0, (acc, variant) => acc + variant.stock);
    }

    return {
      'id': id,
      'kiotId': kiotId,
      'code': code,
      'name': name,
      'fullName': fullName ?? name,
      'units': units.map((u) => u.toMap()).toList(),
      'unit': unit,
      'branchPrices': branchPrices,
      'groupPrices': groupPrices,
      'price': price,
      'importPrice': importPrice,
      'basePrice': importPrice,
      'branchStock': branchStock,
      'stock': totalStock,
      'barcode': barcode,
      'barCode': barcode,
      'category': category,
      'categoryId': categoryId,
      'categoryName': categoryName ?? category,
      'manufacturer': manufacturer,
      'sku': sku,
      'imageUrl': imageUrl ?? (images.isNotEmpty ? images.first : null),
      'images': images,
      'minStock': minStock,
      'maxStock': maxStock,
      'masterUnitId': masterUnitId,
      'masterProductId': masterProductId,
      'hasVariants': hasVariants,
      'attributes': attributes.map((a) => a.toMap()).toList(),
      'inventories': inventories.map((i) => i.toMap()).toList(),
      'variants': variants.map((v) => v.toMap()).toList(),
      'isInventoryManaged': isInventoryManaged,
      'isImeiManaged': isImeiManaged,
      'isBatchManaged': isBatchManaged,
      'isBatchExpireControl': isBatchExpireControl,
      'batchExpires': batchExpires.map((e) => e.toMap()).toList(),
      'isSellable': isSellable,
      'allowsSale': isSellable,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
      'retailerId': retailerId,
      'tradeMarkId': tradeMarkId,
      'tradeMarkName': tradeMarkName,
      'description': description,
      'weight': weight,
    };
  }

  /// Chuyển đổi sang Firestore document (KiotViet-compatible).
  Map<String, dynamic> toFirestore() {
    double totalStock = stock;
    if (variants.isNotEmpty) {
      totalStock = variants.fold(0.0, (acc, variant) => acc + variant.stock);
    }

    return {
      'name': name,
      'kiotId': kiotId,
      'code': code,
      'fullName': fullName ?? name,
      'units': units.map((u) => u.toMap()).toList(),
      'unit': unit,
      'branchPrices': branchPrices,
      'groupPrices': groupPrices,
      'price': price,
      'importPrice': importPrice,
      'branchStock': branchStock,
      'stock': totalStock,
      'barcode': barcode,
      'category': category,
      'categoryId': categoryId,
      'categoryName': categoryName ?? category,
      'manufacturer': manufacturer,
      'sku': sku,
      'imageUrl': imageUrl ?? (images.isNotEmpty ? images.first : null),
      'images': images,
      'minStock': minStock,
      'maxStock': maxStock,
      'masterUnitId': masterUnitId,
      'masterProductId': masterProductId,
      'hasVariants': hasVariants,
      'attributes': attributes.map((a) => a.toMap()).toList(),
      'inventories': inventories.map((i) => i.toMap()).toList(),
      'variants': variants.map((v) => v.toMap()).toList(),
      'isInventoryManaged': isInventoryManaged,
      'isImeiManaged': isImeiManaged,
      'isBatchManaged': isBatchManaged,
      'isBatchExpireControl': isBatchExpireControl,
      'batchExpires': batchExpires.map((e) => e.toMap()).toList(),
      'isSellable': isSellable,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
      'retailerId': retailerId,
      'tradeMarkId': tradeMarkId,
      'tradeMarkName': tradeMarkName,
      'description': description,
      'weight': weight,
    };
  }

  /// Chuyển đổi sang Map (dùng cho SQLite). List lưu dạng JSON string.
  Map<String, dynamic> toMap() {
    double totalStock = stock;
    if (variants.isNotEmpty) {
      totalStock = variants.fold(0.0, (acc, variant) => acc + variant.stock);
    }

    return {
      'id': id,
      'kiotId': kiotId,
      'code': code,
      'name': name,
      'fullName': fullName ?? name,
      'units': jsonEncode(units.map((u) => u.toMap()).toList()),
      'unit': unit,
      'branchPrices': jsonEncode(branchPrices),
      'groupPrices': jsonEncode(groupPrices),
      'price': price,
      'importPrice': importPrice,
      'branchStock': jsonEncode(branchStock),
      'stock': totalStock,
      'barcode': barcode,
      'category': category,
      'categoryId': categoryId,
      'categoryName': categoryName ?? category,
      'manufacturer': manufacturer,
      'sku': sku,
      'imageUrl': imageUrl ?? (images.isNotEmpty ? images.first : null),
      'images': jsonEncode(images),
      'minStock': minStock,
      'maxStock': maxStock,
      'masterUnitId': masterUnitId,
      'masterProductId': masterProductId,
      'hasVariants': hasVariants ? 1 : 0,
      'attributes': jsonEncode(attributes.map((a) => a.toMap()).toList()),
      'inventories': jsonEncode(inventories.map((i) => i.toMap()).toList()),
      'variants': jsonEncode(variants.map((v) => v.toMap()).toList()),
      'isInventoryManaged': isInventoryManaged ? 1 : 0,
      'isImeiManaged': isImeiManaged ? 1 : 0,
      'isBatchManaged': isBatchManaged ? 1 : 0,
      'isBatchExpireControl': isBatchExpireControl ? 1 : 0,
      'batchExpires': jsonEncode(batchExpires.map((e) => e.toMap()).toList()),
      'isSellable': isSellable ? 1 : 0,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'retailerId': retailerId,
      'tradeMarkId': tradeMarkId,
      'tradeMarkName': tradeMarkName,
      'description': description,
      'weight': weight,
    };
  }

  /// Tính giá bán dựa trên đơn vị được chọn
  /// Nếu không có unitId, trả về giá mặc định
  double getPriceByUnit({String? unitId, String? branchId}) {
    // Nếu có unitId, tìm unit tương ứng
    if (unitId != null && units.isNotEmpty) {
      final unit = units.firstWhere(
        (u) => u.id == unitId,
        orElse: () => units.first,
      );
      return unit.price;
    }

    // Nếu có branchId, lấy giá theo chi nhánh
    if (branchId != null && branchPrices.containsKey(branchId)) {
      return branchPrices[branchId]!;
    }

    // Trả về giá mặc định (đơn vị đầu tiên hoặc giá đầu tiên)
    if (units.isNotEmpty) {
      return units.first.price;
    }

    return branchPrices.values.isNotEmpty ? branchPrices.values.first : 0.0;
  }

  /// Tạo bản copy với các trường được cập nhật
  ProductModel copyWith({
    String? id,
    int? kiotId,
    String? code,
    String? name,
    String? fullName,
    List<UnitConversion>? units,
    Map<String, double>? branchPrices,
    Map<String, double>? groupPrices,
    double? importPrice,
    Map<String, double>? branchStock,
    String? barcode,
    String? category,
    String? categoryId,
    String? categoryName,
    String? manufacturer,
    String? sku,
    String? imageUrl,
    List<String>? images,
    double? minStock,
    double? maxStock,
    int? masterUnitId,
    int? masterProductId,
    bool? hasVariants,
    List<ProductAttribute>? attributes,
    List<ProductInventory>? inventories,
    List<ProductVariant>? variants,
    bool? isInventoryManaged,
    bool? isImeiManaged,
    bool? isBatchManaged,
    bool? isBatchExpireControl,
    List<ProductBatchExpire>? batchExpires,
    bool? isSellable,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    int? retailerId,
    int? tradeMarkId,
    String? tradeMarkName,
    String? description,
    double? weight,
  }) {
    Map<String, double> finalBranchStock = Map.from(branchStock ?? this.branchStock);
    final finalVariants = variants ?? this.variants;
    if (finalVariants.isNotEmpty) {
      for (var variant in finalVariants) {
        variant.branchStock.forEach((branchId, stock) {
          finalBranchStock[branchId] = (finalBranchStock[branchId] ?? 0.0) + stock;
        });
      }
    }

    return ProductModel(
      id: id ?? this.id,
      kiotId: kiotId ?? this.kiotId,
      code: code ?? this.code,
      name: name ?? this.name,
      fullName: fullName ?? this.fullName,
      units: units ?? this.units,
      branchPrices: branchPrices ?? this.branchPrices,
      groupPrices: groupPrices ?? this.groupPrices,
      importPrice: importPrice ?? this.importPrice,
      branchStock: finalBranchStock,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      manufacturer: manufacturer ?? this.manufacturer,
      sku: sku ?? this.sku,
      imageUrl: imageUrl ?? this.imageUrl,
      images: images ?? this.images,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      masterUnitId: masterUnitId ?? this.masterUnitId,
      masterProductId: masterProductId ?? this.masterProductId,
      hasVariants: hasVariants ?? this.hasVariants,
      attributes: attributes ?? this.attributes,
      inventories: inventories ?? this.inventories,
      variants: finalVariants,
      isInventoryManaged: isInventoryManaged ?? this.isInventoryManaged,
      isImeiManaged: isImeiManaged ?? this.isImeiManaged,
      isBatchManaged: isBatchManaged ?? this.isBatchManaged,
      isBatchExpireControl: isBatchExpireControl ?? this.isBatchExpireControl,
      batchExpires: batchExpires ?? this.batchExpires,
      isSellable: isSellable ?? this.isSellable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      retailerId: retailerId ?? this.retailerId,
      tradeMarkId: tradeMarkId ?? this.tradeMarkId,
      tradeMarkName: tradeMarkName ?? this.tradeMarkName,
      description: description ?? this.description,
      weight: weight ?? this.weight,
    );
  }
}

