import 'package:cloud_firestore/cloud_firestore.dart';

/// Hằng số quyền (Permissions) để dễ bảo trì và tránh typo.
class EmployeePermissions {
  EmployeePermissions._();

  static const String viewSales = 'view_sales';
  static const String createSale = 'create_sale';
  static const String viewInventory = 'view_inventory';
  static const String manageInventory = 'manage_inventory';
  static const String viewReports = 'view_reports';
  static const String viewInvoices = 'view_invoices';
  static const String manageEmployees = 'manage_employees';
  static const String shopSettings = 'shop_settings';

  /// Tất cả quyền có thể gán cho nhóm (dùng cho UI danh sách checkbox).
  static const List<String> all = [
    viewSales,
    createSale,
    viewInventory,
    manageInventory,
    viewReports,
    viewInvoices,
    manageEmployees,
    shopSettings,
  ];

  /// Nhãn tiếng Việt cho từng quyền.
  static String label(String permission) {
    switch (permission) {
      case viewSales:
        return 'Xem bán hàng';
      case createSale:
        return 'Tạo đơn bán hàng';
      case viewInventory:
        return 'Xem kho';
      case manageInventory:
        return 'Quản lý kho';
      case viewReports:
        return 'Xem báo cáo';
      case viewInvoices:
        return 'Xem hóa đơn';
      case manageEmployees:
        return 'Quản lý nhân viên';
      case shopSettings:
        return 'Cài đặt cửa hàng';
      default:
        return permission;
    }
  }
}

/// Model đại diện cho nhóm nhân viên (phân quyền).
class EmployeeGroupModel {
  final String id;
  final String name;
  final String shopId;
  /// Danh sách quyền được bật (ví dụ: ['view_sales', 'create_sale']).
  final List<String> permissions;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmployeeGroupModel({
    required this.id,
    required this.name,
    required this.shopId,
    this.permissions = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Kiểm tra nhóm có quyền [permission] hay không.
  bool hasPermission(String permission) =>
      permissions.contains(permission);

  /// Tạo từ Firestore document
  factory EmployeeGroupModel.fromFirestore(Map<String, dynamic> data, String id) {
    final perms = data['permissions'];
    List<String> list = const [];
    if (perms is List) {
      list = perms.map((e) => e.toString()).toList();
    } else if (perms is Map) {
      list = (perms as Map<String, dynamic>)
          .entries
          .where((e) => e.value == true)
          .map((e) => e.key)
          .toList();
    }
    return EmployeeGroupModel(
      id: id,
      name: data['name'] ?? '',
      shopId: data['shopId'] ?? '',
      permissions: list,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  /// Tạo từ Map (SQLite / local)
  factory EmployeeGroupModel.fromMap(Map<String, dynamic> map) {
    final perms = map['permissions'];
    List<String> list = const [];
    if (perms is List) {
      list = perms.map((e) => e.toString()).toList();
    }
    return EmployeeGroupModel(
      id: map['id'] as String,
      name: map['name'] as String,
      shopId: map['shopId'] as String,
      permissions: list,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'shopId': shopId,
      'permissions': permissions,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'shopId': shopId,
      'permissions': permissions,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  EmployeeGroupModel copyWith({
    String? id,
    String? name,
    String? shopId,
    List<String>? permissions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeGroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      shopId: shopId ?? this.shopId,
      permissions: permissions ?? this.permissions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
