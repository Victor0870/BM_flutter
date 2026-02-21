import 'package:cloud_firestore/cloud_firestore.dart';

/// ID chi nhánh mặc định "Cửa hàng chính"
const String kMainStoreBranchId = 'main_store';

/// Model đại diện cho chi nhánh cửa hàng. Tương thích KiotViet API 2.7 (Lấy danh sách chi nhánh).
class BranchModel {
  /// ID nội bộ (Firestore document id hoặc string)
  final String id;
  /// ID chi nhánh từ KiotViet (KiotViet: id int). Dùng cho migration và mapping tồn kho.
  final int? kiotId;
  /// Mã chi nhánh (KiotViet: branchCode)
  final String? branchCode;
  /// Tên chi nhánh (KiotViet: branchName)
  final String name;
  /// Địa chỉ (KiotViet: address)
  final String? address;
  /// Số điện thoại (KiotViet: contactNumber)
  final String? phone;
  /// Email (KiotViet: email)
  final String? email;
  /// ID cửa hàng (KiotViet: retailerId)
  final int? retailerId;
  final bool isActive;
  /// Thời gian cập nhật (KiotViet: modifiedDate)
  final DateTime? modifiedDate;
  /// Thời gian tạo (KiotViet: createdDate)
  final DateTime? createdDate;

  BranchModel({
    required this.id,
    this.kiotId,
    this.branchCode,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.retailerId,
    this.isActive = true,
    this.modifiedDate,
    this.createdDate,
  });

  /// Tạo BranchModel từ Firestore document. Hỗ trợ cả KiotViet và nội bộ.
  factory BranchModel.fromFirestore(Map<String, dynamic> data, String id) {
    return BranchModel(
      id: id,
      kiotId: data['kiotId'] is int ? data['kiotId'] as int : (data['kiotId'] as num?)?.toInt(),
      branchCode: data['branchCode'] as String? ?? data['code'] as String?,
      name: data['name'] ?? data['branchName'] ?? '',
      address: data['address'] as String?,
      phone: data['phone'] as String? ?? data['contactNumber'] as String?,
      email: data['email'] as String?,
      retailerId: data['retailerId'] is int ? data['retailerId'] as int : (data['retailerId'] as num?)?.toInt(),
      isActive: data['isActive'] ?? true,
      modifiedDate: data['modifiedDate'] != null ? (data['modifiedDate'] as Timestamp).toDate() : null,
      createdDate: data['createdDate'] != null ? (data['createdDate'] as Timestamp).toDate() : null,
    );
  }

  /// Tạo BranchModel từ JSON (KiotViet API response hoặc nội bộ).
  factory BranchModel.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    return BranchModel(
      id: id?.toString() ?? '',
      kiotId: json['kiotId'] is int ? json['kiotId'] as int : (json['kiotId'] as num?)?.toInt() ?? (json['id'] is int ? json['id'] as int : (json['id'] as num?)?.toInt()),
      branchCode: json['branchCode'] as String? ?? json['code'] as String?,
      name: json['name'] ?? json['branchName'] ?? '',
      address: json['address'] as String?,
      phone: json['phone'] as String? ?? json['contactNumber'] as String?,
      email: json['email'] as String?,
      retailerId: json['retailerId'] is int ? json['retailerId'] as int : (json['retailerId'] as num?)?.toInt(),
      isActive: json['isActive'] ?? true,
      modifiedDate: json['modifiedDate'] != null ? DateTime.tryParse(json['modifiedDate']) : null,
      createdDate: json['createdDate'] != null ? DateTime.tryParse(json['createdDate']) : null,
    );
  }

  /// Tạo BranchModel từ Map (SQLite / nội bộ).
  factory BranchModel.fromMap(Map<String, dynamic> map) {
    return BranchModel(
      id: map['id']?.toString() ?? '',
      kiotId: map['kiotId'] is int ? map['kiotId'] as int : (map['kiotId'] as num?)?.toInt(),
      branchCode: map['branchCode'] as String? ?? map['code'] as String?,
      name: map['name'] ?? map['branchName'] ?? '',
      address: map['address'] as String?,
      phone: map['phone'] as String? ?? map['contactNumber'] as String?,
      email: map['email'] as String?,
      retailerId: map['retailerId'] is int ? map['retailerId'] as int : (map['retailerId'] as num?)?.toInt(),
      isActive: map['isActive'] ?? true,
      modifiedDate: map['modifiedDate'] != null ? DateTime.tryParse(map['modifiedDate'] as String) : null,
      createdDate: map['createdDate'] != null ? DateTime.tryParse(map['createdDate'] as String) : null,
    );
  }

  /// Chuyển đổi sang Map (KiotViet-compatible).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kiotId': kiotId,
      'branchCode': branchCode,
      'branchName': name,
      'name': name,
      'address': address,
      'phone': phone,
      'contactNumber': phone,
      'email': email,
      'retailerId': retailerId,
      'isActive': isActive,
      'modifiedDate': modifiedDate?.toIso8601String(),
      'createdDate': createdDate?.toIso8601String(),
    };
  }

  /// Chuyển đổi sang Firestore document (KiotViet-compatible).
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'branchName': name,
      'branchCode': branchCode,
      'address': address,
      'phone': phone,
      'contactNumber': phone,
      'email': email,
      'retailerId': retailerId,
      'isActive': isActive,
      'modifiedDate': modifiedDate != null ? Timestamp.fromDate(modifiedDate!) : FieldValue.serverTimestamp(),
      'createdDate': createdDate != null ? Timestamp.fromDate(createdDate!) : FieldValue.serverTimestamp(),
      'kiotId': kiotId,
    };
  }

  /// Chuyển đổi sang JSON (KiotViet-compatible).
  Map<String, dynamic> toJson() => toMap();

  /// Tạo bản copy với các trường được cập nhật
  BranchModel copyWith({
    String? id,
    int? kiotId,
    String? branchCode,
    String? name,
    String? address,
    String? phone,
    String? email,
    int? retailerId,
    bool? isActive,
    DateTime? modifiedDate,
    DateTime? createdDate,
  }) {
    return BranchModel(
      id: id ?? this.id,
      kiotId: kiotId ?? this.kiotId,
      branchCode: branchCode ?? this.branchCode,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      retailerId: retailerId ?? this.retailerId,
      isActive: isActive ?? this.isActive,
      modifiedDate: modifiedDate ?? this.modifiedDate,
      createdDate: createdDate ?? this.createdDate,
    );
  }
}
