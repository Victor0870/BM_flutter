import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum cho nhà cung cấp thanh toán
enum PaymentProvider {
  none('None'),
  payos('PayOS'),
  casso('Casso');

  final String value;
  const PaymentProvider(this.value);

  static PaymentProvider fromString(String value) {
    return PaymentProvider.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentProvider.none,
    );
  }
}

/// Cấu hình thanh toán PayOS/Casso
class PaymentConfig {
  final PaymentProvider provider;
  final String? payosClientId;
  final String? payosApiKey;
  final String? payosChecksumKey;
  final String? bankBin;
  final String? bankAccountNumber;
  final String? bankAccountName;
  final bool autoConfirmPayment; // Tự động xác nhận tiền về

  PaymentConfig({
    this.provider = PaymentProvider.none,
    this.payosClientId,
    this.payosApiKey,
    this.payosChecksumKey,
    this.bankBin,
    this.bankAccountNumber,
    this.bankAccountName,
    this.autoConfirmPayment = true, // Mặc định bật tự động xác nhận
  });

  factory PaymentConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return PaymentConfig();
    // Đảm bảo autoConfirmPayment luôn là bool, không phải null
    final autoConfirm = map['autoConfirmPayment'];
    final bool autoConfirmPaymentValue = (autoConfirm is bool) ? autoConfirm : true;
    
    return PaymentConfig(
      provider: PaymentProvider.fromString(map['provider'] ?? 'None'),
      payosClientId: map['payosClientId'],
      payosApiKey: map['payosApiKey'],
      payosChecksumKey: map['payosChecksumKey'],
      bankBin: map['bankBin'],
      bankAccountNumber: map['bankAccountNumber'],
      bankAccountName: map['bankAccountName'],
      autoConfirmPayment: autoConfirmPaymentValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'provider': provider.value,
      'payosClientId': payosClientId,
      'payosApiKey': payosApiKey,
      'payosChecksumKey': payosChecksumKey,
      'bankBin': bankBin,
      'bankAccountNumber': bankAccountNumber,
      'bankAccountName': bankAccountName,
      'autoConfirmPayment': autoConfirmPayment,
    };
  }

  bool get isConfigured {
    if (provider == PaymentProvider.none) return false;
    if (provider == PaymentProvider.payos) {
      return payosClientId != null && 
             payosClientId!.isNotEmpty &&
             payosApiKey != null && 
             payosApiKey!.isNotEmpty &&
             payosChecksumKey != null && 
             payosChecksumKey!.isNotEmpty;
    }
    if (provider == PaymentProvider.casso) {
      return bankBin != null && 
             bankBin!.isNotEmpty &&
             bankAccountNumber != null && 
             bankAccountNumber!.isNotEmpty &&
             bankAccountName != null && 
             bankAccountName!.isNotEmpty;
    }
    return false;
  }
}

/// Cấu hình hóa đơn điện tử FPT
class EinvoiceConfig {
  final String username;
  final String password;
  final String baseUrl; // Môi trường Test: https://api-uat.einvoice.fpt.com.vn/create-icr

  EinvoiceConfig({
    required this.username,
    required this.password,
    required this.baseUrl,
  });

  factory EinvoiceConfig.fromMap(Map<String, dynamic> map) {
    return EinvoiceConfig(
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      baseUrl: map['baseUrl'] ?? 'https://api-uat.einvoice.fpt.com.vn/create-icr',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'password': password,
      'baseUrl': baseUrl,
    };
  }
}

/// Model đại diện cho thông tin shop/cửa hàng
class ShopModel {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String? taxCode;
  
  // Thông tin hóa đơn điện tử FPT
  final String? stax; // Mã số thuế người bán (10 hoặc 14 số)
  final String? serial; // Ký hiệu hóa đơn (Ví dụ: C25MAA)
  final EinvoiceConfig? einvoiceConfig; // Cấu hình hóa đơn điện tử

  // Thông tin cấu hình thanh toán
  final PaymentConfig? paymentConfig; // Cấu hình thanh toán PayOS/Casso

  // Thông tin gói dịch vụ
  final String packageType; // 'PRO' hoặc 'BASIC'
  final DateTime? licenseEndDate; // Ngày hết hạn license
  
  // Cấu hình bán hàng & Kho
  final bool allowNegativeStock; // Cho phép bán âm kho (mặc định false)
  final bool enableCostPrice; // Sử dụng giá nhập (mặc định true)
  
  // Cấu hình đăng ký nhân viên
  final bool allowRegistration; // Cho phép nhân viên đăng ký (mặc định false)
  
  // Cấu hình cập nhật tồn kho
  final bool allowQuickStockUpdate; // Cho phép cập nhật nhanh tồn kho tại danh sách (mặc định true)
  
  /// Thuế VAT (%) áp dụng cho hóa đơn bán hàng (0 = không thuế)
  final double vatRate;

  // Các trường khác có thể có
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? settings;
  final bool isActive;

  ShopModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.taxCode,
    this.stax,
    this.serial,
    this.einvoiceConfig,
    this.paymentConfig,
    required this.packageType,
    this.licenseEndDate,
    this.allowNegativeStock = false,
    this.enableCostPrice = true,
    this.allowRegistration = false,
    this.allowQuickStockUpdate = true,
    this.vatRate = 0.0,
    this.createdAt,
    this.updatedAt,
    this.settings,
    this.isActive = true,
  });

  /// Parse ngày từ Firestore (Timestamp hoặc chuỗi ISO) — tránh crash khi định dạng khác.
  static DateTime? _parseFirestoreDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Tạo ShopModel từ Firestore document
  factory ShopModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ShopModel(
      id: id,
      name: data['name'] ?? '',
      address: data['address'],
      phone: data['phone'],
      email: data['email'],
      taxCode: data['taxCode'],
      stax: data['stax'],
      serial: data['serial'],
      einvoiceConfig: data['einvoiceConfig'] != null
          ? EinvoiceConfig.fromMap(Map<String, dynamic>.from(data['einvoiceConfig']))
          : null,
      paymentConfig: data['paymentConfig'] != null
          ? PaymentConfig.fromMap(Map<String, dynamic>.from(data['paymentConfig']))
          : null,
      packageType: data['packageType'] ?? 'BASIC',
      licenseEndDate: _parseFirestoreDate(data['licenseEndDate']),
      createdAt: _parseFirestoreDate(data['createdAt']),
      updatedAt: _parseFirestoreDate(data['updatedAt']),
      allowNegativeStock: data['allowNegativeStock'] ?? false,
      enableCostPrice: data['enableCostPrice'] ?? true,
      allowRegistration: data['allowRegistration'] ?? false,
      allowQuickStockUpdate: data['allowQuickStockUpdate'] ?? true,
      vatRate: (data['vatRate'] as num?)?.toDouble() ?? 0.0,
      settings: data['settings'] != null
          ? Map<String, dynamic>.from(data['settings'])
          : null,
      isActive: data['isActive'] ?? true,
    );
  }

  /// Tạo ShopModel từ JSON
  factory ShopModel.fromJson(Map<String, dynamic> json) {
    return ShopModel(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      address: json['address'],
      phone: json['phone'],
      email: json['email'],
      taxCode: json['taxCode'],
      stax: json['stax'],
      serial: json['serial'],
      einvoiceConfig: json['einvoiceConfig'] != null
          ? EinvoiceConfig.fromMap(Map<String, dynamic>.from(json['einvoiceConfig']))
          : null,
      paymentConfig: json['paymentConfig'] != null
          ? PaymentConfig.fromMap(Map<String, dynamic>.from(json['paymentConfig']))
          : null,
      packageType: json['packageType'] ?? 'BASIC',
      licenseEndDate: json['licenseEndDate'] != null
          ? DateTime.parse(json['licenseEndDate'])
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : null,
      allowNegativeStock: json['allowNegativeStock'] ?? false,
      enableCostPrice: json['enableCostPrice'] ?? true,
      allowRegistration: json['allowRegistration'] ?? false,
      allowQuickStockUpdate: json['allowQuickStockUpdate'] ?? true,
      vatRate: (json['vatRate'] as num?)?.toDouble() ?? 0.0,
      settings: json['settings'] != null
          ? Map<String, dynamic>.from(json['settings'])
          : null,
      isActive: json['isActive'] ?? true,
    );
  }

  /// Chuyển đổi sang JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'taxCode': taxCode,
      'stax': stax,
      'serial': serial,
      'einvoiceConfig': einvoiceConfig?.toMap(),
      'paymentConfig': paymentConfig?.toMap(), // Thêm paymentConfig
      'packageType': packageType,
      'licenseEndDate': licenseEndDate?.toIso8601String(),
      'allowNegativeStock': allowNegativeStock,
      'enableCostPrice': enableCostPrice,
      'allowRegistration': allowRegistration,
      'allowQuickStockUpdate': allowQuickStockUpdate,
      'vatRate': vatRate,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'settings': settings,
      'isActive': isActive,
    };
  }

  /// Chuyển đổi sang Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'taxCode': taxCode,
      'stax': stax,
      'serial': serial,
      'einvoiceConfig': einvoiceConfig?.toMap(),
      'paymentConfig': paymentConfig?.toMap(), // Thêm paymentConfig
      'packageType': packageType,
      'licenseEndDate': licenseEndDate != null
          ? Timestamp.fromDate(licenseEndDate!)
          : null,
      'allowNegativeStock': allowNegativeStock,
      'enableCostPrice': enableCostPrice,
      'allowRegistration': allowRegistration,
      'allowQuickStockUpdate': allowQuickStockUpdate,
      'vatRate': vatRate,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : null,
      'updatedAt': updatedAt != null
          ? Timestamp.fromDate(updatedAt!)
          : null,
      'settings': settings,
      'isActive': isActive,
    };
  }

  /// Kiểm tra xem license có còn hiệu lực không.
  /// PRO không có licenseEndDate (null) được coi là không giới hạn (valid).
  bool get isLicenseValid {
    if (licenseEndDate == null) {
      return packageType == 'PRO'; // PRO không hạn = unlimited
    }
    return DateTime.now().isBefore(licenseEndDate!);
  }

  /// Tạo bản copy với các trường được cập nhật
  ShopModel copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? taxCode,
    String? stax,
    String? serial,
    EinvoiceConfig? einvoiceConfig,
    PaymentConfig? paymentConfig,
    String? packageType,
    DateTime? licenseEndDate,
    bool? allowNegativeStock,
    bool? enableCostPrice,
    bool? allowRegistration,
    bool? allowQuickStockUpdate,
    double? vatRate,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? settings,
    bool? isActive,
  }) {
    return ShopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      taxCode: taxCode ?? this.taxCode,
      stax: stax ?? this.stax,
      serial: serial ?? this.serial,
      einvoiceConfig: einvoiceConfig ?? this.einvoiceConfig,
      paymentConfig: paymentConfig ?? this.paymentConfig,
      packageType: packageType ?? this.packageType,
      licenseEndDate: licenseEndDate ?? this.licenseEndDate,
      allowNegativeStock: allowNegativeStock ?? this.allowNegativeStock,
      enableCostPrice: enableCostPrice ?? this.enableCostPrice,
      allowRegistration: allowRegistration ?? this.allowRegistration,
      allowQuickStockUpdate: allowQuickStockUpdate ?? this.allowQuickStockUpdate,
      vatRate: vatRate ?? this.vatRate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settings: settings ?? this.settings,
      isActive: isActive ?? this.isActive,
    );
  }
}

