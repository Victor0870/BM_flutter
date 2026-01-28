/// ID chi nhánh mặc định "Cửa hàng chính"
const String kMainStoreBranchId = 'main_store';

/// Model đại diện cho chi nhánh cửa hàng
class BranchModel {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;

  BranchModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.isActive = true,
  });

  /// Tạo BranchModel từ Firestore document
  factory BranchModel.fromFirestore(Map<String, dynamic> data, String id) {
    return BranchModel(
      id: id,
      name: data['name'] ?? '',
      address: data['address'],
      phone: data['phone'],
      isActive: data['isActive'] ?? true,
    );
  }

  /// Tạo BranchModel từ Map
  factory BranchModel.fromMap(Map<String, dynamic> map) {
    return BranchModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      address: map['address'],
      phone: map['phone'],
      isActive: map['isActive'] ?? true,
    );
  }

  /// Chuyển đổi sang Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'isActive': isActive,
    };
  }

  /// Chuyển đổi sang Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'isActive': isActive,
    };
  }

  /// Tạo bản copy với các trường được cập nhật
  BranchModel copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    bool? isActive,
  }) {
    return BranchModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
    );
  }
}
