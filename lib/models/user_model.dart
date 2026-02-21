import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum cho vai trò người dùng (owner = chủ shop, manager = quản lý, staff = nhân viên)
enum UserRole {
  owner('owner'),
  manager('manager'),
  staff('staff');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'manager':
      case 'admin': // Tương thích ngược: admin -> manager
        return UserRole.manager;
      case 'staff':
      default:
        return UserRole.staff;
    }
  }
}

/// Model đại diện cho thông tin người dùng/nhân viên
class UserModel {
  final String uid;
  final String email;
  final String shopId;
  final UserRole role;
  final bool isApproved;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? displayName;
  final String? phone;
  final String? workingBranchId; // Chi nhánh làm việc chính của nhân viên
  final List<String> allowedBranchIds; // Danh sách ID các chi nhánh mà nhân viên có quyền truy cập
  /// ID nhóm nhân viên (để thừa hưởng quyền từ nhóm).
  final String? groupId;
  /// Quyền tùy chỉnh ghi đè (bổ sung hoặc tắt quyền so với nhóm).
  final List<String>? customPermissions;

  UserModel({
    required this.uid,
    required this.email,
    required this.shopId,
    this.role = UserRole.staff,
    this.isApproved = false,
    required this.createdAt,
    this.updatedAt,
    this.displayName,
    this.phone,
    this.workingBranchId,
    this.allowedBranchIds = const [],
    this.groupId,
    this.customPermissions,
  });

  /// Tạo UserModel từ Firestore document
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      uid: id,
      email: data['email'] ?? '',
      shopId: data['shopId'] ?? '',
      role: UserRole.fromString(data['role'] ?? 'staff'),
      isApproved: data['isApproved'] ?? false,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      displayName: data['displayName'],
      phone: data['phone'],
      workingBranchId: data['workingBranchId'],
      allowedBranchIds: data['allowedBranchIds'] != null
          ? List<String>.from(data['allowedBranchIds'] as List)
          : [],
      groupId: data['groupId'],
      customPermissions: data['customPermissions'] != null
          ? List<String>.from(data['customPermissions'] as List)
          : null,
    );
  }

  /// Tạo UserModel từ JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] ?? '',
      email: json['email'] ?? '',
      shopId: json['shopId'] ?? '',
      role: UserRole.fromString(json['role'] ?? 'staff'),
      isApproved: json['isApproved'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      displayName: json['displayName'],
      phone: json['phone'],
      workingBranchId: json['workingBranchId'],
      allowedBranchIds: json['allowedBranchIds'] != null
          ? List<String>.from(json['allowedBranchIds'] as List)
          : [],
      groupId: json['groupId'],
      customPermissions: json['customPermissions'] != null
          ? List<String>.from(json['customPermissions'] as List)
          : null,
    );
  }

  /// Chuyển đổi sang JSON
  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'shopId': shopId,
      'role': role.value,
      'isApproved': isApproved,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'displayName': displayName,
      'phone': phone,
      'workingBranchId': workingBranchId,
      'allowedBranchIds': allowedBranchIds,
      'groupId': groupId,
      'customPermissions': customPermissions,
    };
  }

  /// Chuyển đổi sang Firestore document
  /// Nhân viên trong users chỉ có role 'manager' hoặc 'staff' (owner không có doc trong users).
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'shopId': shopId,
      'role': role.value,
      'isApproved': isApproved,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'displayName': displayName,
      'phone': phone,
      'workingBranchId': workingBranchId,
      'allowedBranchIds': allowedBranchIds,
      'groupId': groupId,
      'customPermissions': customPermissions,
    };
  }

  /// Tạo bản copy với các trường được cập nhật
  UserModel copyWith({
    String? uid,
    String? email,
    String? shopId,
    UserRole? role,
    bool? isApproved,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? displayName,
    String? phone,
    String? workingBranchId,
    List<String>? allowedBranchIds,
    String? groupId,
    List<String>? customPermissions,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      shopId: shopId ?? this.shopId,
      role: role ?? this.role,
      isApproved: isApproved ?? this.isApproved,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      workingBranchId: workingBranchId ?? this.workingBranchId,
      allowedBranchIds: allowedBranchIds ?? this.allowedBranchIds,
      groupId: groupId ?? this.groupId,
      customPermissions: customPermissions ?? this.customPermissions,
    );
  }

  /// Kiểm tra xem user có phải chủ shop (owner) không
  bool get isOwner => role == UserRole.owner;

  /// Kiểm tra xem user có phải quản lý (manager) không
  bool get isManager => role == UserRole.manager;

  /// Kiểm tra xem user có phải nhân viên (staff) không
  bool get isStaff => role == UserRole.staff;

  /// Tương thích ngược: admin = manager
  bool get isAdmin => role == UserRole.manager;
}
