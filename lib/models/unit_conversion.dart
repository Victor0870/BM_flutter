import 'dart:convert';

/// Model đại diện cho đơn vị quy đổi của sản phẩm
/// Ví dụ: Sản phẩm "Nước suối" có thể có: "Thùng" (24 chai), "Chai" (1 chai)
class UnitConversion {
  final String id; // ID duy nhất của đơn vị
  final String unitName; // Tên đơn vị (VD: "Thùng", "Chai", "Kg", "Lít")
  final double conversionValue; // Hệ số quy đổi (VD: 24 = 1 thùng = 24 chai)
  final double price; // Giá bán cho đơn vị này
  final String? barcode; // Mã vạch riêng cho đơn vị này (nếu có)

  UnitConversion({
    required this.id,
    required this.unitName,
    required this.conversionValue,
    required this.price,
    this.barcode,
  });

  /// Tạo UnitConversion từ Map
  factory UnitConversion.fromMap(Map<String, dynamic> map) {
    return UnitConversion(
      id: map['id'] as String? ?? '',
      unitName: map['unitName'] as String? ?? '',
      conversionValue: (map['conversionValue'] as num?)?.toDouble() ?? 1.0,
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      barcode: map['barcode'] as String?,
    );
  }

  /// Chuyển đổi sang Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'unitName': unitName,
      'conversionValue': conversionValue,
      'price': price,
      'barcode': barcode,
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
  }) {
    return UnitConversion(
      id: id ?? this.id,
      unitName: unitName ?? this.unitName,
      conversionValue: conversionValue ?? this.conversionValue,
      price: price ?? this.price,
      barcode: barcode ?? this.barcode,
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
