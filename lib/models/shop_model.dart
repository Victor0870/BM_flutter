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

/// Nhà cung cấp hóa đơn điện tử: FPT, Viettel hoặc MISA
enum EinvoiceProvider {
  fpt('FPT'),
  viettel('Viettel'),
  misa('MISA');

  final String label;
  const EinvoiceProvider(this.label);

  static EinvoiceProvider fromString(String value) {
    return EinvoiceProvider.values.firstWhere(
      (e) => e.name == value || e.label == value,
      orElse: () => EinvoiceProvider.fpt,
    );
  }
}

/// Cấu hình hóa đơn điện tử (FPT, Viettel, MISA)
class EinvoiceConfig {
  final EinvoiceProvider provider;
  final String username;
  final String password;
  final String baseUrl;
  /// Mẫu hóa đơn (Viettel: ví dụ 1/001; FPT không dùng; MISA: có thể dùng InvSeries)
  final String? templateCode;
  /// AppID do MISA cung cấp (bắt buộc khi provider = MISA)
  final String? appId;

  EinvoiceConfig({
    this.provider = EinvoiceProvider.fpt,
    required this.username,
    required this.password,
    required this.baseUrl,
    this.templateCode,
    this.appId,
  });

  factory EinvoiceConfig.fromMap(Map<String, dynamic> map) {
    return EinvoiceConfig(
      provider: EinvoiceProvider.fromString(map['provider']?.toString() ?? 'fpt'),
      username: map['username'] ?? '',
      password: map['password'] ?? '',
      baseUrl: map['baseUrl'] ?? 'https://api-uat.einvoice.fpt.com.vn/create-icr',
      templateCode: map['templateCode']?.toString(),
      appId: map['appId']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'provider': provider.name,
      'username': username,
      'password': password,
      'baseUrl': baseUrl,
      if (templateCode != null && templateCode!.isNotEmpty) 'templateCode': templateCode,
      if (appId != null && appId!.isNotEmpty) 'appId': appId,
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
  final String? website;
  final String? logoUrl;
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
  
  // Feature flag & cấu hình đồng bộ KiotViet (chỉ hiển thị khi isKiotVietEnabled = true)
  final bool isKiotVietEnabled; // Biến điều khiển từ Admin (mặc định false)
  final bool syncWithKiotViet; // Toggle cho phép người dùng bật/tắt đồng bộ (mặc định false)
  final String? kiotClientId; // Client ID của KiotViet
  final String? kiotClientSecret; // Client Secret của KiotViet
  /// Tên kết nối KiotViet (Retailer) — ví dụ: danganhauto. Dùng làm header Retailer khi gọi API.
  final String? kiotRetailer;
  
  // Cấu hình cập nhật tồn kho
  final bool allowQuickStockUpdate; // Cho phép cập nhật nhanh tồn kho tại danh sách (mặc định true)
  
  /// Khi bật: không trừ kho khi thanh toán, chỉ trừ kho khi phát hành hóa đơn điện tử (mặc định false)
  final bool deductStockOnEinvoiceOnly;
  
  /// Thuế VAT (%) áp dụng cho hóa đơn bán hàng (0 = không thuế)
  final double vatRate;

  /// Cấu hình máy in: khổ giấy mặc định (58 hoặc 80 mm)
  final int printerPaperSizeMm;
  /// Tự động in hóa đơn sau khi thanh toán xong
  final bool autoPrintAfterPayment;
  /// Tên máy in (Desktop) để Silent Print đúng thiết bị
  final String? printerName;

  /// Tùy chỉnh nội dung hóa đơn: lời chào/cảm ơn (cuối hóa đơn)
  final String? invoiceThankYouMessage;
  /// Chính sách đổi trả (in ở dưới cùng hóa đơn)
  final String? invoiceReturnPolicy;
  /// VietQR: mã BIN ngân hàng (6 số), tên ngân hàng, số TK, tên chủ tài khoản
  final String? vietqrBankBin;
  final String? vietqrBankName;
  final String? vietqrAccountNumber;
  final String? vietqrAccountName;

  // Các trường khác có thể có
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? settings;
  final bool isActive;

  /// Tổng số hóa đơn bán hàng (tăng 1 mỗi lần lưu đơn vào Firestore) — dùng cho admin xem shop có đang hoạt động
  final int totalSalesCount;

  ShopModel({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.logoUrl,
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
    this.isKiotVietEnabled = false,
    this.syncWithKiotViet = false,
    this.kiotClientId,
    this.kiotClientSecret,
    this.kiotRetailer,
    this.allowQuickStockUpdate = true,
    this.deductStockOnEinvoiceOnly = false,
    this.vatRate = 0.0,
    this.printerPaperSizeMm = 80,
    this.autoPrintAfterPayment = false,
    this.printerName,
    this.invoiceThankYouMessage,
    this.invoiceReturnPolicy,
    this.vietqrBankBin,
    this.vietqrBankName,
    this.vietqrAccountNumber,
    this.vietqrAccountName,
    this.createdAt,
    this.updatedAt,
    this.settings,
    this.isActive = true,
    this.totalSalesCount = 0,
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
      website: data['website']?.toString(),
      logoUrl: data['logoUrl']?.toString(),
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
      isKiotVietEnabled: data['isKiotVietEnabled'] ?? false,
      syncWithKiotViet: data['syncWithKiotViet'] ?? false,
      kiotClientId: data['kiotClientId']?.toString(),
      kiotClientSecret: data['kiotClientSecret']?.toString(),
      kiotRetailer: data['kiotRetailer']?.toString(),
      allowQuickStockUpdate: data['allowQuickStockUpdate'] ?? true,
      deductStockOnEinvoiceOnly: data['deductStockOnEinvoiceOnly'] ?? false,
      vatRate: (data['vatRate'] as num?)?.toDouble() ?? 0.0,
      printerPaperSizeMm: (data['printerPaperSizeMm'] as num?)?.toInt() ?? 80,
      autoPrintAfterPayment: data['autoPrintAfterPayment'] ?? false,
      printerName: data['printerName']?.toString(),
      invoiceThankYouMessage: data['invoiceThankYouMessage']?.toString(),
      invoiceReturnPolicy: data['invoiceReturnPolicy']?.toString(),
      vietqrBankBin: data['vietqrBankBin']?.toString(),
      vietqrBankName: data['vietqrBankName']?.toString(),
      vietqrAccountNumber: data['vietqrAccountNumber']?.toString(),
      vietqrAccountName: data['vietqrAccountName']?.toString(),
      settings: data['settings'] != null
          ? Map<String, dynamic>.from(data['settings'])
          : null,
      isActive: data['isActive'] ?? true,
      totalSalesCount: (data['totalSalesCount'] as num?)?.toInt() ?? 0,
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
      website: json['website']?.toString(),
      logoUrl: json['logoUrl']?.toString(),
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
      isKiotVietEnabled: json['isKiotVietEnabled'] ?? false,
      syncWithKiotViet: json['syncWithKiotViet'] ?? false,
      kiotClientId: json['kiotClientId']?.toString(),
      kiotClientSecret: json['kiotClientSecret']?.toString(),
      kiotRetailer: json['kiotRetailer']?.toString(),
      allowQuickStockUpdate: json['allowQuickStockUpdate'] ?? true,
      deductStockOnEinvoiceOnly: json['deductStockOnEinvoiceOnly'] ?? false,
      vatRate: (json['vatRate'] as num?)?.toDouble() ?? 0.0,
      printerPaperSizeMm: (json['printerPaperSizeMm'] as num?)?.toInt() ?? 80,
      autoPrintAfterPayment: json['autoPrintAfterPayment'] ?? false,
      printerName: json['printerName']?.toString(),
      invoiceThankYouMessage: json['invoiceThankYouMessage']?.toString(),
      invoiceReturnPolicy: json['invoiceReturnPolicy']?.toString(),
      vietqrBankBin: json['vietqrBankBin']?.toString(),
      vietqrBankName: json['vietqrBankName']?.toString(),
      vietqrAccountNumber: json['vietqrAccountNumber']?.toString(),
      vietqrAccountName: json['vietqrAccountName']?.toString(),
      settings: json['settings'] != null
          ? Map<String, dynamic>.from(json['settings'])
          : null,
      isActive: json['isActive'] ?? true,
      totalSalesCount: (json['totalSalesCount'] as num?)?.toInt() ?? 0,
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
      'website': website,
      'logoUrl': logoUrl,
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
      'isKiotVietEnabled': isKiotVietEnabled,
      'syncWithKiotViet': syncWithKiotViet,
      'kiotClientId': kiotClientId,
      'kiotClientSecret': kiotClientSecret,
      'kiotRetailer': kiotRetailer,
      'allowQuickStockUpdate': allowQuickStockUpdate,
      'deductStockOnEinvoiceOnly': deductStockOnEinvoiceOnly,
      'vatRate': vatRate,
      'printerPaperSizeMm': printerPaperSizeMm,
      'autoPrintAfterPayment': autoPrintAfterPayment,
      'printerName': printerName,
      'invoiceThankYouMessage': invoiceThankYouMessage,
      'invoiceReturnPolicy': invoiceReturnPolicy,
      'vietqrBankBin': vietqrBankBin,
      'vietqrBankName': vietqrBankName,
      'vietqrAccountNumber': vietqrAccountNumber,
      'vietqrAccountName': vietqrAccountName,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'settings': settings,
      'isActive': isActive,
      'totalSalesCount': totalSalesCount,
    };
  }

  /// Chuyển đổi sang Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'logoUrl': logoUrl,
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
      'isKiotVietEnabled': isKiotVietEnabled,
      'syncWithKiotViet': syncWithKiotViet,
      'kiotClientId': kiotClientId,
      'kiotClientSecret': kiotClientSecret,
      'kiotRetailer': kiotRetailer,
      'allowQuickStockUpdate': allowQuickStockUpdate,
      'deductStockOnEinvoiceOnly': deductStockOnEinvoiceOnly,
      'vatRate': vatRate,
      'printerPaperSizeMm': printerPaperSizeMm,
      'autoPrintAfterPayment': autoPrintAfterPayment,
      'printerName': printerName,
      'invoiceThankYouMessage': invoiceThankYouMessage,
      'invoiceReturnPolicy': invoiceReturnPolicy,
      'vietqrBankBin': vietqrBankBin,
      'vietqrBankName': vietqrBankName,
      'vietqrAccountNumber': vietqrAccountNumber,
      'vietqrAccountName': vietqrAccountName,
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
    String? website,
    String? logoUrl,
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
    bool? isKiotVietEnabled,
    bool? syncWithKiotViet,
    String? kiotClientId,
    String? kiotClientSecret,
    String? kiotRetailer,
    bool? allowQuickStockUpdate,
    bool? deductStockOnEinvoiceOnly,
    double? vatRate,
    int? printerPaperSizeMm,
    bool? autoPrintAfterPayment,
    String? printerName,
    String? invoiceThankYouMessage,
    String? invoiceReturnPolicy,
    String? vietqrBankBin,
    String? vietqrBankName,
    String? vietqrAccountNumber,
    String? vietqrAccountName,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? settings,
    bool? isActive,
    int? totalSalesCount,
  }) {
    return ShopModel(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      website: website ?? this.website,
      logoUrl: logoUrl ?? this.logoUrl,
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
      isKiotVietEnabled: isKiotVietEnabled ?? this.isKiotVietEnabled,
      syncWithKiotViet: syncWithKiotViet ?? this.syncWithKiotViet,
      kiotClientId: kiotClientId ?? this.kiotClientId,
      kiotClientSecret: kiotClientSecret ?? this.kiotClientSecret,
      kiotRetailer: kiotRetailer ?? this.kiotRetailer,
      allowQuickStockUpdate: allowQuickStockUpdate ?? this.allowQuickStockUpdate,
      deductStockOnEinvoiceOnly: deductStockOnEinvoiceOnly ?? this.deductStockOnEinvoiceOnly,
      vatRate: vatRate ?? this.vatRate,
      printerPaperSizeMm: printerPaperSizeMm ?? this.printerPaperSizeMm,
      autoPrintAfterPayment: autoPrintAfterPayment ?? this.autoPrintAfterPayment,
      printerName: printerName ?? this.printerName,
      invoiceThankYouMessage: invoiceThankYouMessage ?? this.invoiceThankYouMessage,
      invoiceReturnPolicy: invoiceReturnPolicy ?? this.invoiceReturnPolicy,
      vietqrBankBin: vietqrBankBin ?? this.vietqrBankBin,
      vietqrBankName: vietqrBankName ?? this.vietqrBankName,
      vietqrAccountNumber: vietqrAccountNumber ?? this.vietqrAccountNumber,
      vietqrAccountName: vietqrAccountName ?? this.vietqrAccountName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      settings: settings ?? this.settings,
      isActive: isActive ?? this.isActive,
      totalSalesCount: totalSalesCount ?? this.totalSalesCount,
    );
  }
}

