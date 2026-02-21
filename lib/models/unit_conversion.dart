import 'dart:convert';

/// Model đại diện cho đơn vị quy đổi của sản phẩm.
/// Tương thích KiotViet API (2.4): units[] với id, code, name, fullName, unit, conversionValue, basePrice.
/// Ví dụ: Sản phẩm "Nước suối" có thể có: "Thùng" (24 chai), "Chai" (1 chai).
class UnitConversion {
  /// ID đơn vị (KiotViet: id long - ID sản phẩm đơn vị)
  final String id;
  /// Tên đơn vị (VD: "Thùng", "Chai", "Kg", "Lít"). KiotViet: unit
  final String unitName;
  /// Hệ số quy đổi (VD: 24 = 1 thùng = 24 chai). KiotViet: conversionValue
  final double conversionValue;
  /// Giá bán cho đơn vị này. KiotViet: basePrice
  final double price;
  /// Mã vạch riêng cho đơn vị này (nếu có)
  final String? barcode;
  /// Mã sản phẩm đơn vị (KiotViet: code)
  final String? code;
  /// Tên sản phẩm (KiotViet: name). Thường trùng unit khi không có biến thể.
  final String? name;
  /// Tên đầy đủ bao gồm thuộc tính và đơn vị (KiotViet: fullName)
  final String? fullName;

  UnitConversion({
    required this.id,
    required this.unitName,
    required this.conversionValue,
    required this.price,
    this.barcode,
    this.code,
    this.name,
    this.fullName,
  });

  /// Tạo UnitConversion từ Map (Firestore/JSON). Hỗ trợ cả key KiotViet (unit, basePrice) và key nội bộ.
  factory UnitConversion.fromMap(Map<String, dynamic> map) {
    final unitName = map['unitName'] as String? ?? map['unit'] as String? ?? '';
    final price = (map['price'] as num?)?.toDouble() ?? (map['basePrice'] as num?)?.toDouble() ?? 0.0;
    final id = map['id']; // KiotViet trả long, nội bộ có thể String
    return UnitConversion(
      id: id?.toString() ?? '',
      unitName: unitName,
      conversionValue: (map['conversionValue'] as num?)?.toDouble() ?? 1.0,
      price: price,
      barcode: map['barcode'] as String?,
      code: map['code'] as String?,
      name: map['name'] as String?,
      fullName: map['fullName'] as String?,
    );
  }

  /// Chuyển đổi sang Map. Xuất cả key nội bộ và key KiotViet (unit, basePrice) để migration.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unitName': unitName,
      'unit': unitName, // KiotViet
      'conversionValue': conversionValue,
      'price': price,
      'basePrice': price, // KiotViet
      'barcode': barcode,
      'code': code,
      'name': name ?? unitName,
      'fullName': fullName ?? unitName,
    };
  }

  /// Tạo từ JSON String (dùng cho SQLite)
  factory UnitConversion.fromJson(String jsonString) {
    final Map<String, dynamic> map = jsonDecode(jsonString);
    return UnitConversion.fromMap(map);
  }

  /// Chuyển sang JSON String (dùng cho SQLite)
  String toJson() {
    return jsonEncode(toMap());
  }

  /// Tạo bản copy với các trường được cập nhật
  UnitConversion copyWith({
    String? id,
    String? unitName,
    double? conversionValue,
    double? price,
    String? barcode,
    String? code,
    String? name,
    String? fullName,
  }) {
    return UnitConversion(
      id: id ?? this.id,
      unitName: unitName ?? this.unitName,
      conversionValue: conversionValue ?? this.conversionValue,
      price: price ?? this.price,
      barcode: barcode ?? this.barcode,
      code: code ?? this.code,
      name: name ?? this.name,
      fullName: fullName ?? this.fullName,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UnitConversion &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
