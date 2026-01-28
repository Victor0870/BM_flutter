import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'unit_conversion.dart';

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
  double get stock => branchStock.values.fold(0.0, (sum, stock) => sum + stock);

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

/// Model đại diện cho sản phẩm/hàng hóa
class ProductModel {
  final String id;
  final String name;
  final List<UnitConversion> units; // Danh sách đơn vị quy đổi (thay thế unit cũ)
  final Map<String, double> branchPrices; // Giá bán theo chi nhánh (Key: branchId)
  final double importPrice; // Giá nhập (mặc định, dùng khi không có variants)
  final Map<String, double> branchStock; // Số lượng tồn kho theo chi nhánh (Key: branchId)
  final String? barcode; // Mã vạch (mặc định, dùng khi không có variants)
  final String? category; // Danh mục (backward compatibility - string cũ)
  final String? categoryId; // ID của CategoryModel (mới)
  final String? manufacturer; // Nhà sản xuất
  final String? sku; // Mã SKU sản phẩm
  final String? imageUrl; // Link ảnh sản phẩm
  final double? minStock; // Định mức tồn kho tối thiểu
  final double? maxStock; // Định mức tồn kho tối đa
  final List<ProductVariant> variants; // Danh sách biến thể
  final bool isInventoryManaged; // Quản lý tồn kho (mặc định true)
  final bool isImeiManaged; // Quản lý IMEI (cho hàng công nghệ)
  final bool isBatchManaged; // Quản lý lô hàng (cho hàng thực phẩm/thuốc)
  final bool isSellable; // Cho phép bán (mặc định true)
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  ProductModel({
    required this.id,
    required this.name,
    this.units = const [], // Danh sách đơn vị quy đổi
    required this.branchPrices,
    required this.importPrice,
    required this.branchStock,
    this.barcode,
    this.category, // Backward compatibility
    this.categoryId,
    this.manufacturer,
    this.sku,
    this.imageUrl,
    this.minStock,
    this.maxStock,
    this.variants = const [],
    this.isInventoryManaged = true,
    this.isImeiManaged = false,
    this.isBatchManaged = false,
    this.isSellable = true,
    this.createdAt,
    this.updatedAt,
    this.isActive = true,
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

  /// Tồn kho mặc định (backward compatibility - tổng tồn kho tất cả chi nhánh và variants)
  double get stock {
    double total = branchStock.values.fold(0.0, (sum, stock) => sum + stock);
    if (variants.isNotEmpty) {
      total = variants.fold(0.0, (sum, variant) => sum + variant.stock);
    }
    return total;
  }

  /// Tạo ProductModel từ Firestore document
  factory ProductModel.fromFirestore(Map<String, dynamic> data, String id) {
    // Parse variants từ Firestore
    List<ProductVariant> variants = [];
    if (data['variants'] != null) {
      final variantsList = data['variants'] as List<dynamic>;
      variants = variantsList
          .map((v) => ProductVariant.fromMap(Map<String, dynamic>.from(v)))
          .toList();
    }

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
      // Backward compatibility: chuyển price cũ sang branchPrices với key 'default'
      branchPrices['default'] = (data['price'] as num).toDouble();
    }

    // Xử lý branchStock
    Map<String, double> branchStock = {};
    if (data['branchStock'] != null) {
      branchStock = Map<String, double>.from(
        (data['branchStock'] as Map).map((key, value) => MapEntry(
              key.toString(),
              (value as num).toDouble(),
            )),
      );
    } else if (data['stock'] != null) {
      // Backward compatibility: chuyển stock cũ sang branchStock với key 'default'
      branchStock['default'] = (data['stock'] as num).toDouble();
    }

    // Tính tổng stock từ variants nếu có
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
      // Backward compatibility: chuyển unit cũ (String) thành UnitConversion
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

    return ProductModel(
      id: id,
      name: data['name'] ?? '',
      units: units,
      branchPrices: branchPrices,
      importPrice: (data['importPrice'] ?? 0).toDouble(),
      branchStock: branchStock,
      barcode: data['barcode'],
      category: data['category'], // Backward compatibility
      categoryId: data['categoryId'],
      manufacturer: data['manufacturer'],
      sku: data['sku'],
      imageUrl: data['imageUrl'],
      minStock: data['minStock'] != null ? (data['minStock'] as num).toDouble() : null,
      maxStock: data['maxStock'] != null ? (data['maxStock'] as num).toDouble() : null,
      variants: variants,
      isInventoryManaged: data['isInventoryManaged'] ?? true,
      isImeiManaged: data['isImeiManaged'] ?? false,
      isBatchManaged: data['isBatchManaged'] ?? false,
      isSellable: data['isSellable'] ?? true,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  /// Tạo ProductModel từ JSON
  factory ProductModel.fromJson(Map<String, dynamic> json) {
    // Parse variants từ JSON
    List<ProductVariant> variants = [];
    if (json['variants'] != null) {
      final variantsList = json['variants'] as List<dynamic>;
      variants = variantsList
          .map((v) => ProductVariant.fromMap(Map<String, dynamic>.from(v)))
          .toList();
    }

    // Xử lý branchPrices
    Map<String, double> branchPrices = {};
    if (json['branchPrices'] != null) {
      branchPrices = Map<String, double>.from(
        (json['branchPrices'] as Map).map((key, value) => MapEntry(
              key.toString(),
              (value as num).toDouble(),
            )),
      );
    } else if (json['price'] != null) {
      // Backward compatibility
      branchPrices['default'] = (json['price'] as num).toDouble();
    }

    // Xử lý branchStock
    Map<String, double> branchStock = {};
    if (json['branchStock'] != null) {
      branchStock = Map<String, double>.from(
        (json['branchStock'] as Map).map((key, value) => MapEntry(
              key.toString(),
              (value as num).toDouble(),
            )),
      );
    } else if (json['stock'] != null) {
      // Backward compatibility
      branchStock['default'] = (json['stock'] as num).toDouble();
    }

    // Tính tổng stock từ variants nếu có
    if (variants.isNotEmpty) {
      for (var variant in variants) {
        variant.branchStock.forEach((branchId, stock) {
          branchStock[branchId] = (branchStock[branchId] ?? 0.0) + stock;
        });
      }
    }

    // Parse units từ JSON
    List<UnitConversion> units = [];
    if (json['units'] != null) {
      final unitsList = json['units'] as List<dynamic>?;
      if (unitsList != null) {
        units = unitsList
            .map((u) => UnitConversion.fromMap(Map<String, dynamic>.from(u)))
            .toList();
      }
    } else if (json['unit'] != null) {
      // Backward compatibility
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

    return ProductModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      units: units,
      branchPrices: branchPrices,
      importPrice: (json['importPrice'] ?? 0).toDouble(),
      branchStock: branchStock,
      barcode: json['barcode'],
      category: json['category'], // Backward compatibility
      categoryId: json['categoryId'],
      manufacturer: json['manufacturer'],
      sku: json['sku'],
      imageUrl: json['imageUrl'],
      minStock: json['minStock'] != null ? (json['minStock'] as num).toDouble() : null,
      maxStock: json['maxStock'] != null ? (json['maxStock'] as num).toDouble() : null,
      variants: variants,
      isInventoryManaged: json['isInventoryManaged'] ?? true,
      isImeiManaged: json['isImeiManaged'] ?? false,
      isBatchManaged: json['isBatchManaged'] ?? false,
      isSellable: json['isSellable'] ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      isActive: json['isActive'] ?? true,
    );
  }

  /// Tạo ProductModel từ Map (dùng cho SQLite)
  factory ProductModel.fromMap(Map<String, dynamic> map) {
    // Parse variants từ JSON string (SQLite lưu dạng JSON)
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
      } catch (e) {
        // Nếu parse lỗi, để variants rỗng
      }
    }

    // Xử lý branchPrices từ JSON string (SQLite)
    Map<String, double> branchPrices = {};
    if (map['branchPrices'] != null) {
      try {
        final pricesJson = map['branchPrices'] as String;
        if (pricesJson.isNotEmpty) {
          final decoded = jsonDecode(pricesJson) as Map<String, dynamic>;
          branchPrices = decoded.map((key, value) => MapEntry(
                key,
                (value as num).toDouble(),
              ));
        }
      } catch (e) {
        // Parse lỗi, thử backward compatibility
      }
    }
    if (branchPrices.isEmpty && map['price'] != null) {
      branchPrices['default'] = (map['price'] as num).toDouble();
    }

    // Xử lý branchStock từ JSON string (SQLite)
    Map<String, double> branchStock = {};
    if (map['branchStock'] != null) {
      try {
        final stockJson = map['branchStock'] as String;
        if (stockJson.isNotEmpty) {
          final decoded = jsonDecode(stockJson) as Map<String, dynamic>;
          branchStock = decoded.map((key, value) => MapEntry(
                key,
                (value as num).toDouble(),
              ));
        }
      } catch (e) {
        // Parse lỗi, thử backward compatibility
      }
    }
    if (branchStock.isEmpty && map['stock'] != null) {
      branchStock['default'] = (map['stock'] as num?)?.toDouble() ?? 0.0;
    }

    // Tính tổng stock từ variants nếu có
    if (variants.isNotEmpty) {
      for (var variant in variants) {
        variant.branchStock.forEach((branchId, stock) {
          branchStock[branchId] = (branchStock[branchId] ?? 0.0) + stock;
        });
      }
    }

    // Parse units từ JSON string (SQLite)
    List<UnitConversion> units = [];
    if (map['units'] != null) {
      try {
        final unitsJson = map['units'] as String;
        if (unitsJson.isNotEmpty) {
          final decoded = jsonDecode(unitsJson) as List<dynamic>;
          units = decoded
              .map((u) => UnitConversion.fromMap(Map<String, dynamic>.from(u)))
              .toList();
        }
      } catch (e) {
        // Parse lỗi, thử backward compatibility với unit cũ
      }
    }
    if (units.isEmpty && map['unit'] != null) {
      // Backward compatibility: chuyển unit cũ (String) thành UnitConversion
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

    return ProductModel(
      id: map['id'] as String,
      name: map['name'] as String,
      units: units,
      branchPrices: branchPrices,
      importPrice: (map['importPrice'] as num).toDouble(),
      branchStock: branchStock,
      barcode: map['barcode'] as String?,
      category: map['category'] as String?, // Backward compatibility
      categoryId: map['categoryId'] as String?,
      manufacturer: map['manufacturer'] as String?,
      sku: map['sku'] as String?,
      imageUrl: map['imageUrl'] as String?,
      minStock: map['minStock'] != null ? (map['minStock'] as num).toDouble() : null,
      maxStock: map['maxStock'] != null ? (map['maxStock'] as num).toDouble() : null,
      variants: variants,
      isInventoryManaged: (map['isInventoryManaged'] as int?) == 1,
      isImeiManaged: (map['isImeiManaged'] as int?) == 1,
      isBatchManaged: (map['isBatchManaged'] as int?) == 1,
      isSellable: (map['isSellable'] as int?) != 0, // Default true nếu null
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
      isActive: (map['isActive'] as int) == 1,
    );
  }

  /// Chuyển đổi sang JSON
  Map<String, dynamic> toJson() {
    // Tính tổng stock từ variants nếu có
    double totalStock = stock;
    if (variants.isNotEmpty) {
      totalStock = variants.fold(0.0, (sum, variant) => sum + variant.stock);
    }

    return {
      'id': id,
      'name': name,
      'units': units.map((u) => u.toMap()).toList(),
      'unit': unit, // Backward compatibility
      'branchPrices': branchPrices,
      'price': price, // Backward compatibility
      'importPrice': importPrice,
      'branchStock': branchStock,
      'stock': totalStock, // Backward compatibility
      'barcode': barcode,
      'category': category, // Backward compatibility
      'categoryId': categoryId,
      'manufacturer': manufacturer,
      'sku': sku,
      'imageUrl': imageUrl,
      'minStock': minStock,
      'maxStock': maxStock,
      'variants': variants.map((v) => v.toMap()).toList(),
      'isInventoryManaged': isInventoryManaged,
      'isImeiManaged': isImeiManaged,
      'isBatchManaged': isBatchManaged,
      'isSellable': isSellable,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
    };
  }

  /// Chuyển đổi sang Firestore document
  Map<String, dynamic> toFirestore() {
    // Tính tổng stock từ variants nếu có
    double totalStock = stock;
    if (variants.isNotEmpty) {
      totalStock = variants.fold(0.0, (sum, variant) => sum + variant.stock);
    }

    return {
      'name': name,
      'units': units.map((u) => u.toMap()).toList(),
      'unit': unit, // Backward compatibility
      'branchPrices': branchPrices,
      'price': price, // Backward compatibility
      'importPrice': importPrice,
      'branchStock': branchStock,
      'stock': totalStock, // Backward compatibility
      'barcode': barcode,
      'category': category, // Backward compatibility
      'categoryId': categoryId,
      'manufacturer': manufacturer,
      'sku': sku,
      'imageUrl': imageUrl,
      'minStock': minStock,
      'maxStock': maxStock,
      'variants': variants.map((v) => v.toMap()).toList(),
      'isInventoryManaged': isInventoryManaged,
      'isImeiManaged': isImeiManaged,
      'isBatchManaged': isBatchManaged,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }

  /// Chuyển đổi sang Map (dùng cho SQLite)
  Map<String, dynamic> toMap() {
    // Tính tổng stock từ variants nếu có
    double totalStock = stock;
    if (variants.isNotEmpty) {
      totalStock = variants.fold(0.0, (sum, variant) => sum + variant.stock);
    }

    // Lưu variants dạng JSON string (SQLite không hỗ trợ array/list trực tiếp)
    final variantsJson = jsonEncode(variants.map((v) => v.toMap()).toList());
    
    // Lưu branchPrices và branchStock dạng JSON string (SQLite)
    final branchPricesJson = jsonEncode(branchPrices);
    final branchStockJson = jsonEncode(branchStock);

    // Lưu units dạng JSON string (SQLite)
    final unitsJson = jsonEncode(units.map((u) => u.toMap()).toList());

    return {
      'id': id,
      'name': name,
      'units': unitsJson,
      'unit': unit, // Backward compatibility - lưu đơn vị đầu tiên
      'branchPrices': branchPricesJson,
      'price': price, // Backward compatibility
      'importPrice': importPrice,
      'branchStock': branchStockJson,
      'stock': totalStock, // Backward compatibility
      'barcode': barcode,
      'category': category, // Backward compatibility
      'categoryId': categoryId,
      'manufacturer': manufacturer,
      'sku': sku,
      'imageUrl': imageUrl,
      'minStock': minStock,
      'maxStock': maxStock,
      'variants': variantsJson,
      'isInventoryManaged': isInventoryManaged ? 1 : 0,
      'isImeiManaged': isImeiManaged ? 1 : 0,
      'isBatchManaged': isBatchManaged ? 1 : 0,
      'isSellable': isSellable ? 1 : 0,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive ? 1 : 0,
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
    String? name,
    List<UnitConversion>? units,
    Map<String, double>? branchPrices,
    double? importPrice,
    Map<String, double>? branchStock,
    String? barcode,
    String? category,
    String? categoryId,
    String? manufacturer,
    String? sku,
    String? imageUrl,
    double? minStock,
    double? maxStock,
    List<ProductVariant>? variants,
    bool? isInventoryManaged,
    bool? isImeiManaged,
    bool? isBatchManaged,
    bool? isSellable,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
  }) {
    // Nếu có variants mới, tính lại branchStock
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
      name: name ?? this.name,
      units: units ?? this.units,
      branchPrices: branchPrices ?? this.branchPrices,
      importPrice: importPrice ?? this.importPrice,
      branchStock: finalBranchStock,
      barcode: barcode ?? this.barcode,
      category: category ?? this.category,
      categoryId: categoryId ?? this.categoryId,
      manufacturer: manufacturer ?? this.manufacturer,
      sku: sku ?? this.sku,
      imageUrl: imageUrl ?? this.imageUrl,
      minStock: minStock ?? this.minStock,
      maxStock: maxStock ?? this.maxStock,
      variants: finalVariants,
      isInventoryManaged: isInventoryManaged ?? this.isInventoryManaged,
      isImeiManaged: isImeiManaged ?? this.isImeiManaged,
      isBatchManaged: isBatchManaged ?? this.isBatchManaged,
      isSellable: isSellable ?? this.isSellable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
    );
  }
}

