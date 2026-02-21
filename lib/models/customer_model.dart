import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Model đại diện cho khách hàng. Tương thích KiotViet API 2.6 (Khách hàng).
class CustomerModel {
  /// ID nội bộ (Firestore document id)
  final String id;
  /// ID khách hàng từ KiotViet (KiotViet: id long). Dùng cho migration.
  final int? kiotId;
  /// Mã khách hàng (KiotViet: code)
  final String? code;
  final String name;
  /// Số điện thoại (KiotViet: contactNumber)
  final String phone;
  final String? address;
  /// ID nhóm khách hàng (một nhóm - backward compatibility). KiotViet dùng groupIds[].
  final String? groupId;
  /// Danh sách ID nhóm khách hàng (KiotViet: groupIds int[]). Mapping khi migration.
  final List<int> groupIds;
  /// Danh sách tên nhóm khách hàng (KiotViet: groups string - danh sách tên, hoặc mảng)
  final List<String> groups;
  /// Nợ hiện tại (KiotViet: debt). Backward: totalDebt.
  final double totalDebt;
  /// Tổng doanh thu tích lũy (KiotViet: totalRevenue)
  final double totalRevenue;
  /// Tổng bán (KiotViet: totalInvoiced)
  final double? totalInvoiced;
  /// Mã số thuế (KiotViet: taxCode)
  final String? taxCode;
  /// Giới tính (KiotViet: gender - true: nam, false: nữ)
  final bool? gender;
  /// Ngày sinh (KiotViet: birthDate)
  final DateTime? birthDate;
  /// Email (KiotViet: email)
  final String? email;
  /// Khu vực (KiotViet: locationName)
  final String? locationName;
  /// Phường xã (KiotViet: wardName)
  final String? wardName;
  /// Công ty (KiotViet: organization)
  final String? organization;
  /// Ghi chú (KiotViet: comments)
  final String? comments;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  CustomerModel({
    required this.id,
    this.kiotId,
    this.code,
    required this.name,
    required this.phone,
    this.address,
    this.groupId,
    this.groupIds = const [],
    this.groups = const [],
    this.totalDebt = 0.0,
    this.totalRevenue = 0.0,
    this.totalInvoiced,
    this.taxCode,
    this.gender,
    this.birthDate,
    this.email,
    this.locationName,
    this.wardName,
    this.organization,
    this.comments,
    this.createdAt,
    this.updatedAt,
  });

  /// Nợ hiện tại - alias cho totalDebt (KiotViet: debt)
  double get debt => totalDebt;

  /// Tạo CustomerModel từ Firestore document. Hỗ trợ cả KiotViet và nội bộ.
  factory CustomerModel.fromFirestore(Map<String, dynamic> data, String id) {
    List<int> groupIds = [];
    if (data['groupIds'] != null) {
      final list = data['groupIds'] as List<dynamic>?;
      if (list != null) {
        groupIds = list.map((e) => e is int ? e : (e as num).toInt()).toList();
      }
    }

    List<String> groupsList = [];
    if (data['groups'] != null) {
      if (data['groups'] is List) {
        groupsList = (data['groups'] as List<dynamic>).map((e) => e.toString()).toList();
      } else {
        final s = data['groups'] as String?;
        if (s != null && s.isNotEmpty) groupsList = [s];
      }
    }

    final debt = (data['totalDebt'] as num?)?.toDouble() ?? (data['debt'] as num?)?.toDouble() ?? 0.0;

    return CustomerModel(
      id: id,
      kiotId: data['kiotId'] is int ? data['kiotId'] as int : (data['kiotId'] as num?)?.toInt(),
      code: data['code'] as String?,
      name: data['name'] ?? '',
      phone: data['phone'] ?? data['contactNumber'] ?? '',
      address: data['address'] as String?,
      groupId: data['groupId']?.toString(),
      groupIds: groupIds,
      groups: groupsList,
      totalDebt: debt,
      totalRevenue: (data['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalInvoiced: (data['totalInvoiced'] as num?)?.toDouble(),
      taxCode: data['taxCode'] as String?,
      gender: data['gender'] as bool?,
      birthDate: data['birthDate'] != null ? (data['birthDate'] as Timestamp).toDate() : null,
      email: data['email'] as String?,
      locationName: data['locationName'] as String?,
      wardName: data['wardName'] as String?,
      organization: data['organization'] as String?,
      comments: data['comments'] as String?,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      updatedAt: data['updatedAt'] != null ? (data['updatedAt'] as Timestamp).toDate() : null,
    );
  }

  /// Tạo CustomerModel từ JSON (KiotViet API response hoặc nội bộ).
  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    List<int> groupIds = [];
    if (json['groupIds'] != null) {
      final list = json['groupIds'] as List<dynamic>?;
      if (list != null) {
        groupIds = list.map((e) => e is int ? e : (e as num).toInt()).toList();
      }
    }

    List<String> groupsList = [];
    if (json['groups'] != null) {
      if (json['groups'] is List) {
        groupsList = (json['groups'] as List<dynamic>).map((e) => e.toString()).toList();
      } else {
        final s = json['groups'] as String?;
        if (s != null && s.isNotEmpty) groupsList = [s];
      }
    }

    final debt = (json['totalDebt'] as num?)?.toDouble() ?? (json['debt'] as num?)?.toDouble() ?? 0.0;

    return CustomerModel(
      id: json['id']?.toString() ?? '',
      kiotId: json['kiotId'] is int ? json['kiotId'] as int : (json['kiotId'] as num?)?.toInt(),
      code: json['code'] as String?,
      name: json['name'] ?? '',
      phone: json['phone'] ?? json['contactNumber'] ?? '',
      address: json['address'] as String?,
      groupId: json['groupId']?.toString(),
      groupIds: groupIds,
      groups: groupsList,
      totalDebt: debt,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalInvoiced: (json['totalInvoiced'] as num?)?.toDouble(),
      taxCode: json['taxCode'] as String?,
      gender: json['gender'] as bool?,
      birthDate: json['birthDate'] != null ? DateTime.parse(json['birthDate']) : null,
      email: json['email'] as String?,
      locationName: json['locationName'] as String?,
      wardName: json['wardName'] as String?,
      organization: json['organization'] as String?,
      comments: json['comments'] as String?,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt']) : null,
    );
  }

  /// Tạo CustomerModel từ Map (SQLite / nội bộ).
  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    List<int> groupIds = [];
    if (map['groupIds'] != null) {
      if (map['groupIds'] is List) {
        groupIds = (map['groupIds'] as List<dynamic>).map((e) => e is int ? e : (e as num).toInt()).toList();
      } else if (map['groupIds'] is String) {
        final s = map['groupIds'] as String;
        if (s.startsWith('[')) {
          groupIds = _parseJsonListInt(s);
        } else if (s.isNotEmpty) {
          groupIds = s.split(',').map((e) => int.tryParse(e.trim()) ?? 0).where((e) => e != 0).toList();
        }
      }
    }

    List<String> groupsList = [];
    if (map['groups'] != null) {
      if (map['groups'] is List) {
        groupsList = (map['groups'] as List<dynamic>).map((e) => e.toString()).toList();
      } else if (map['groups'] is String) {
        final s = map['groups'] as String;
        if (s.isNotEmpty) {
          groupsList = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          if (groupsList.isEmpty) groupsList = [s];
        }
      }
    }

    final debt = (map['totalDebt'] as num?)?.toDouble() ?? (map['debt'] as num?)?.toDouble() ?? 0.0;

    return CustomerModel(
      id: map['id'] as String,
      kiotId: map['kiotId'] is int ? map['kiotId'] as int : (map['kiotId'] as num?)?.toInt(),
      code: map['code'] as String?,
      name: map['name'] as String,
      phone: map['phone'] as String,
      address: map['address'] as String?,
      groupId: map['groupId']?.toString(),
      groupIds: groupIds,
      groups: groupsList,
      totalDebt: debt,
      totalRevenue: (map['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      totalInvoiced: (map['totalInvoiced'] as num?)?.toDouble(),
      taxCode: map['taxCode'] as String?,
      gender: map['gender'] == null ? null : (map['gender'] as int) == 1,
      birthDate: map['birthDate'] != null ? DateTime.parse(map['birthDate'] as String) : null,
      email: map['email'] as String?,
      locationName: map['locationName'] as String?,
      wardName: map['wardName'] as String?,
      organization: map['organization'] as String?,
      comments: map['comments'] as String?,
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt'] as String) : null,
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt'] as String) : null,
    );
  }

  static List<int> _parseJsonListInt(String s) {
    try {
      if (s.isEmpty || !s.startsWith('[')) return [];
      final decoded = jsonDecode(s);
      final list = decoded is List ? decoded : [];
      return list.map((e) => e is int ? e : (e as num).toInt()).toList();
    } catch (_) {
      return [];
    }
  }

  /// Chuyển đổi sang Firestore document (KiotViet-compatible).
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'code': code,
      'phone': phone,
      'contactNumber': phone,
      'address': address,
      'groupId': groupId,
      'groupIds': groupIds,
      'groups': groups,
      'totalDebt': totalDebt,
      'debt': totalDebt,
      'totalRevenue': totalRevenue,
      'totalInvoiced': totalInvoiced,
      'taxCode': taxCode,
      'gender': gender,
      'birthDate': birthDate,
      'email': email,
      'locationName': locationName,
      'wardName': wardName,
      'organization': organization,
      'comments': comments,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'kiotId': kiotId,
    };
  }

  /// Chuyển đổi sang JSON (KiotViet-compatible).
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kiotId': kiotId,
      'code': code,
      'name': name,
      'phone': phone,
      'contactNumber': phone,
      'address': address,
      'groupId': groupId,
      'groupIds': groupIds,
      'groups': groups,
      'totalDebt': totalDebt,
      'debt': totalDebt,
      'totalRevenue': totalRevenue,
      'totalInvoiced': totalInvoiced,
      'taxCode': taxCode,
      'gender': gender,
      'birthDate': birthDate?.toIso8601String(),
      'email': email,
      'locationName': locationName,
      'wardName': wardName,
      'organization': organization,
      'comments': comments,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Chuyển đổi sang Map (SQLite).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'kiotId': kiotId,
      'code': code,
      'name': name,
      'phone': phone,
      'address': address,
      'groupId': groupId,
      'groupIds': groupIds.isEmpty ? null : groupIds.join(','),
      'groups': groups.isEmpty ? null : groups.join(','),
      'totalDebt': totalDebt,
      'totalRevenue': totalRevenue,
      'totalInvoiced': totalInvoiced,
      'taxCode': taxCode,
      'gender': gender == null ? null : (gender! ? 1 : 0),
      'birthDate': birthDate?.toIso8601String(),
      'email': email,
      'locationName': locationName,
      'wardName': wardName,
      'organization': organization,
      'comments': comments,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  /// Tạo bản copy với các trường được cập nhật
  CustomerModel copyWith({
    String? id,
    int? kiotId,
    String? code,
    String? name,
    String? phone,
    String? address,
    String? groupId,
    List<int>? groupIds,
    List<String>? groups,
    double? totalDebt,
    double? totalRevenue,
    double? totalInvoiced,
    String? taxCode,
    bool? gender,
    DateTime? birthDate,
    String? email,
    String? locationName,
    String? wardName,
    String? organization,
    String? comments,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      kiotId: kiotId ?? this.kiotId,
      code: code ?? this.code,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      groupId: groupId ?? this.groupId,
      groupIds: groupIds ?? this.groupIds,
      groups: groups ?? this.groups,
      totalDebt: totalDebt ?? this.totalDebt,
      totalRevenue: totalRevenue ?? this.totalRevenue,
      totalInvoiced: totalInvoiced ?? this.totalInvoiced,
      taxCode: taxCode ?? this.taxCode,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      email: email ?? this.email,
      locationName: locationName ?? this.locationName,
      wardName: wardName ?? this.wardName,
      organization: organization ?? this.organization,
      comments: comments ?? this.comments,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
