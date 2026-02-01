import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Enum cho phương thức thanh toán
enum PaymentMethodType {
  cash('CASH'),
  transfer('TRANSFER');

  final String value;
  const PaymentMethodType(this.value);

  static PaymentMethodType fromString(String value) {
    return PaymentMethodType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentMethodType.cash,
    );
  }
}

/// Enum cho trạng thái thanh toán
enum PaymentStatus {
  pending('PENDING'),
  completed('COMPLETED');

  final String value;
  const PaymentStatus(this.value);

  static PaymentStatus fromString(String value) {
    return PaymentStatus.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PaymentStatus.completed,
    );
  }
}

/// Model đại diện cho một đơn hàng/phiếu bán
class SaleModel {
  final String id;
  final DateTime timestamp;
  final double totalAmount;
  final List<SaleItem> items;
  final String paymentMethod; // 'CASH', 'TRANSFER'
  final String paymentStatus; // 'PENDING', 'COMPLETED'
  final String? customerName;
  final String? customerTaxCode; // MST khách hàng
  final String? customerAddress; // Địa chỉ khách hàng
  final String? customerId; // ID của CustomerModel (nếu có)
  final String? notes;
  final String userId; // ID của shop/user tạo đơn hàng
  final String branchId; // ID của chi nhánh thực hiện bán hàng (bắt buộc)
  final String? sellerId; // ID của nhân viên bán hàng (seller)
  final String? sellerName; // Tên nhân viên bán hàng
  final bool isStockUpdated; // Flag để kiểm soát việc trừ kho, tránh trừ kho 2 lần
  final double? totalBeforeDiscount; // Tổng tiền hàng trước chiết khấu (deprecated, dùng subTotal)
  final double? discountAmount; // Số tiền được giảm (deprecated, dùng totalDiscountAmount)
  
  // Chi tiết chiết khấu để báo cáo và audit
  final double? subTotal; // Tổng tiền hàng sau khi trừ chiết khấu từng dòng, trước khi áp dụng chiết khấu tổng
  final double? orderDiscountValue; // Giá trị chiết khấu đã nhập (có thể là % hoặc số tiền)
  final String? orderDiscountType; // Loại chiết khấu: 'percentage' hoặc 'amount'
  final double? totalDiscountAmount; // Số tiền thực tế được giảm sau khi quy đổi từ % hoặc tiền mặt
  final String? discountApprovedBy; // ID hoặc tên người đã phê duyệt mức chiết khấu này (nếu mức chiết khấu cao)
  
  // Thuế VAT áp dụng cho đơn hàng
  final double? vatRate; // Thuế suất (%)
  final double? taxAmount; // Số tiền thuế

  // Thông tin hóa đơn điện tử (FPT eInvoice)
  final String? invoiceNo; // Số hóa đơn điện tử
  final String? templateCode; // Mẫu số hóa đơn
  final String? invoiceSerial; // Ký hiệu hóa đơn
  final String? einvoiceUrl; // Link tra cứu/xem hóa đơn điện tử

  SaleModel({
    required this.id,
    required this.timestamp,
    required this.totalAmount,
    required this.items,
    required this.paymentMethod,
    this.paymentStatus = 'COMPLETED', // Mặc định hoàn tất (tiền mặt)
    required this.userId,
    required this.branchId,
    this.customerName,
    this.customerTaxCode,
    this.customerAddress,
    this.customerId,
    this.notes,
    this.sellerId, // ID của nhân viên bán hàng
    this.sellerName, // Tên nhân viên bán hàng
    this.isStockUpdated = false, // Mặc định chưa trừ kho
    this.totalBeforeDiscount, // Tổng tiền hàng trước chiết khấu (deprecated)
    this.discountAmount, // Số tiền được giảm (deprecated)
    this.subTotal, // Tổng tiền hàng sau khi trừ chiết khấu từng dòng
    this.orderDiscountValue, // Giá trị chiết khấu đã nhập
    this.orderDiscountType, // Loại chiết khấu
    this.totalDiscountAmount, // Số tiền thực tế được giảm
    this.discountApprovedBy, // Người phê duyệt
    this.vatRate, // Thuế suất (%)
    this.taxAmount, // Số tiền thuế
    this.invoiceNo, // Số hóa đơn điện tử
    this.templateCode, // Mẫu số hóa đơn
    this.invoiceSerial, // Ký hiệu hóa đơn
    this.einvoiceUrl, // Link tra cứu hóa đơn điện tử
  });

  /// Tạo SaleModel từ Firestore document
  factory SaleModel.fromFirestore(Map<String, dynamic> data, String id) {
    return SaleModel(
      id: id,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      totalAmount: (data['totalAmount'] ?? 0).toDouble(),
      items: (data['items'] as List<dynamic>?)
              ?.map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      paymentMethod: data['paymentMethod'] ?? 'CASH',
      paymentStatus: data['paymentStatus'] ?? 'COMPLETED',
      userId: data['userId'] ?? '',
      customerName: data['customerName'],
      customerTaxCode: data['customerTaxCode'],
      customerAddress: data['customerAddress'],
      customerId: data['customerId'],
      notes: data['notes'],
      branchId: data['branchId'] ?? '', // Bắt buộc, mặc định rỗng nếu không có
      sellerId: data['sellerId'],
      sellerName: data['sellerName'],
      isStockUpdated: data['isStockUpdated'] ?? false, // Mặc định false nếu không có
      totalBeforeDiscount: data['totalBeforeDiscount'] != null ? (data['totalBeforeDiscount'] as num).toDouble() : null,
      discountAmount: data['discountAmount'] != null ? (data['discountAmount'] as num).toDouble() : null,
      subTotal: data['subTotal'] != null ? (data['subTotal'] as num).toDouble() : null,
      orderDiscountValue: data['orderDiscountValue'] != null ? (data['orderDiscountValue'] as num).toDouble() : null,
      orderDiscountType: data['orderDiscountType'] as String?,
      totalDiscountAmount: data['totalDiscountAmount'] != null ? (data['totalDiscountAmount'] as num).toDouble() : null,
      discountApprovedBy: data['discountApprovedBy'] as String?,
      vatRate: data['vatRate'] != null ? (data['vatRate'] as num).toDouble() : null,
      taxAmount: data['taxAmount'] != null ? (data['taxAmount'] as num).toDouble() : null,
      invoiceNo: data['invoiceNo'] as String?,
      templateCode: data['templateCode'] as String?,
      invoiceSerial: data['invoiceSerial'] as String?,
      einvoiceUrl: data['einvoiceUrl'] as String?,
    );
  }

  /// Tạo SaleModel từ JSON
  factory SaleModel.fromJson(Map<String, dynamic> json) {
    return SaleModel(
      id: json['id'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
      totalAmount: (json['totalAmount'] ?? 0).toDouble(),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
              .toList() ??
          [],
      paymentMethod: json['paymentMethod'] ?? 'CASH',
      paymentStatus: json['paymentStatus'] ?? 'COMPLETED',
      userId: json['userId'] ?? '',
      customerName: json['customerName'],
      customerTaxCode: json['customerTaxCode'],
      customerAddress: json['customerAddress'],
      customerId: json['customerId'],
      notes: json['notes'],
      branchId: json['branchId'] ?? '', // Bắt buộc, mặc định rỗng nếu không có
      sellerId: json['sellerId'],
      sellerName: json['sellerName'],
      isStockUpdated: json['isStockUpdated'] ?? false, // Mặc định false nếu không có
      totalBeforeDiscount: json['totalBeforeDiscount'] != null ? (json['totalBeforeDiscount'] as num).toDouble() : null,
      discountAmount: json['discountAmount'] != null ? (json['discountAmount'] as num).toDouble() : null,
      subTotal: json['subTotal'] != null ? (json['subTotal'] as num).toDouble() : null,
      orderDiscountValue: json['orderDiscountValue'] != null ? (json['orderDiscountValue'] as num).toDouble() : null,
      orderDiscountType: json['orderDiscountType'] as String?,
      totalDiscountAmount: json['totalDiscountAmount'] != null ? (json['totalDiscountAmount'] as num).toDouble() : null,
      discountApprovedBy: json['discountApprovedBy'] as String?,
      vatRate: json['vatRate'] != null ? (json['vatRate'] as num).toDouble() : null,
      taxAmount: json['taxAmount'] != null ? (json['taxAmount'] as num).toDouble() : null,
      invoiceNo: json['invoiceNo'] as String?,
      templateCode: json['templateCode'] as String?,
      invoiceSerial: json['invoiceSerial'] as String?,
      einvoiceUrl: json['einvoiceUrl'] as String?,
    );
  }

  /// Tạo SaleModel từ Map (dùng cho SQLite)
  factory SaleModel.fromMap(Map<String, dynamic> map) {
    return SaleModel(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      totalAmount: (map['totalAmount'] as num).toDouble(),
      items: (map['items'] as String?) != null
          ? (SaleItem.fromJsonList(map['items'] as String))
          : [],
      paymentMethod: map['paymentMethod'] as String,
      paymentStatus: map['paymentStatus'] as String? ?? 'COMPLETED',
      userId: map['userId'] as String,
      customerName: map['customerName'] as String?,
      customerTaxCode: map['customerTaxCode'] as String?,
      customerAddress: map['customerAddress'] as String?,
      customerId: map['customerId'] as String?,
      notes: map['notes'] as String?,
      branchId: map['branchId'] as String? ?? '', // Bắt buộc, mặc định rỗng nếu không có
      sellerId: map['sellerId'] as String?,
      sellerName: map['sellerName'] as String?,
      isStockUpdated: (map['isStockUpdated'] as int? ?? 0) == 1, // SQLite lưu boolean dạng int
      totalBeforeDiscount: map['totalBeforeDiscount'] != null ? (map['totalBeforeDiscount'] as num).toDouble() : null,
      discountAmount: map['discountAmount'] != null ? (map['discountAmount'] as num).toDouble() : null,
      subTotal: map['subTotal'] != null ? (map['subTotal'] as num).toDouble() : null,
      orderDiscountValue: map['orderDiscountValue'] != null ? (map['orderDiscountValue'] as num).toDouble() : null,
      orderDiscountType: map['orderDiscountType'] as String?,
      totalDiscountAmount: map['totalDiscountAmount'] != null ? (map['totalDiscountAmount'] as num).toDouble() : null,
      discountApprovedBy: map['discountApprovedBy'] as String?,
      vatRate: map['vatRate'] != null ? (map['vatRate'] as num).toDouble() : null,
      taxAmount: map['taxAmount'] != null ? (map['taxAmount'] as num).toDouble() : null,
      invoiceNo: map['invoiceNo'] as String?,
      templateCode: map['templateCode'] as String?,
      invoiceSerial: map['invoiceSerial'] as String?,
      einvoiceUrl: map['einvoiceUrl'] as String?,
    );
  }

  /// Chuyển đổi sang JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'totalAmount': totalAmount,
      'items': items.map((item) => item.toMap()).toList(),
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'userId': userId,
      'customerName': customerName,
      'customerTaxCode': customerTaxCode,
      'customerAddress': customerAddress,
      'customerId': customerId,
      'notes': notes,
      'branchId': branchId,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'isStockUpdated': isStockUpdated,
      'totalBeforeDiscount': totalBeforeDiscount,
      'discountAmount': discountAmount,
      'subTotal': subTotal,
      'orderDiscountValue': orderDiscountValue,
      'orderDiscountType': orderDiscountType,
      'totalDiscountAmount': totalDiscountAmount,
      'discountApprovedBy': discountApprovedBy,
      'vatRate': vatRate,
      'taxAmount': taxAmount,
    };
  }

  /// Chuyển đổi sang Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'timestamp': Timestamp.fromDate(timestamp),
      'totalAmount': totalAmount,
      'items': items.map((item) => item.toMap()).toList(),
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'userId': userId,
      'customerName': customerName,
      'customerTaxCode': customerTaxCode,
      'customerAddress': customerAddress,
      'customerId': customerId,
      'notes': notes,
      'branchId': branchId,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'isStockUpdated': isStockUpdated,
      'totalBeforeDiscount': totalBeforeDiscount,
      'discountAmount': discountAmount,
      'subTotal': subTotal,
      'orderDiscountValue': orderDiscountValue,
      'orderDiscountType': orderDiscountType,
      'totalDiscountAmount': totalDiscountAmount,
      'discountApprovedBy': discountApprovedBy,
      'vatRate': vatRate,
      'taxAmount': taxAmount,
      'invoiceNo': invoiceNo,
      'templateCode': templateCode,
      'invoiceSerial': invoiceSerial,
      'einvoiceUrl': einvoiceUrl,
      'createdAt': Timestamp.now(), // Thời điểm tạo hóa đơn
    };
  }

  /// Chuyển đổi sang Map (dùng cho SQLite)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'totalAmount': totalAmount,
      'items': items.map((item) => item.toMap()).toList().toString(), // Lưu dạng JSON string
      'paymentMethod': paymentMethod,
      'userId': userId,
      'customerName': customerName,
      'customerTaxCode': customerTaxCode,
      'customerAddress': customerAddress,
      'customerId': customerId,
      'notes': notes,
      'branchId': branchId,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'isStockUpdated': isStockUpdated ? 1 : 0, // SQLite lưu boolean dạng int
      'totalBeforeDiscount': totalBeforeDiscount,
      'discountAmount': discountAmount,
      'subTotal': subTotal,
      'orderDiscountValue': orderDiscountValue,
      'orderDiscountType': orderDiscountType,
      'totalDiscountAmount': totalDiscountAmount,
      'discountApprovedBy': discountApprovedBy,
      'vatRate': vatRate,
      'taxAmount': taxAmount,
      'invoiceNo': invoiceNo,
      'templateCode': templateCode,
      'invoiceSerial': invoiceSerial,
      'einvoiceUrl': einvoiceUrl,
    };
  }

  /// Tạo bản copy với các trường được cập nhật
  SaleModel copyWith({
    String? id,
    DateTime? timestamp,
    double? totalAmount,
    List<SaleItem>? items,
    String? paymentMethod,
    String? paymentStatus,
    String? userId,
    String? customerName,
    String? customerTaxCode,
    String? customerAddress,
    String? customerId,
    String? notes,
    String? branchId,
    String? sellerId,
    String? sellerName,
    bool? isStockUpdated,
    double? totalBeforeDiscount,
    double? discountAmount,
    double? subTotal,
    double? orderDiscountValue,
    String? orderDiscountType,
    double? totalDiscountAmount,
    String? discountApprovedBy,
    double? vatRate,
    double? taxAmount,
    String? invoiceNo,
    String? templateCode,
    String? invoiceSerial,
    String? einvoiceUrl,
  }) {
    return SaleModel(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      totalAmount: totalAmount ?? this.totalAmount,
      items: items ?? this.items,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerTaxCode: customerTaxCode ?? this.customerTaxCode,
      customerAddress: customerAddress ?? this.customerAddress,
      customerId: customerId ?? this.customerId,
      notes: notes ?? this.notes,
      branchId: branchId ?? this.branchId,
      sellerId: sellerId ?? this.sellerId,
      sellerName: sellerName ?? this.sellerName,
      isStockUpdated: isStockUpdated ?? this.isStockUpdated,
      totalBeforeDiscount: totalBeforeDiscount ?? this.totalBeforeDiscount,
      discountAmount: discountAmount ?? this.discountAmount,
      subTotal: subTotal ?? this.subTotal,
      orderDiscountValue: orderDiscountValue ?? this.orderDiscountValue,
      orderDiscountType: orderDiscountType ?? this.orderDiscountType,
      totalDiscountAmount: totalDiscountAmount ?? this.totalDiscountAmount,
      discountApprovedBy: discountApprovedBy ?? this.discountApprovedBy,
      vatRate: vatRate ?? this.vatRate,
      taxAmount: taxAmount ?? this.taxAmount,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      templateCode: templateCode ?? this.templateCode,
      invoiceSerial: invoiceSerial ?? this.invoiceSerial,
      einvoiceUrl: einvoiceUrl ?? this.einvoiceUrl,
    );
  }
}

/// Model đại diện cho một item trong đơn hàng
class SaleItem {
  final String productId;
  final String productName;
  final double quantity;
  final double price; // Giá gốc của sản phẩm
  final double vatRate; // Thuế suất VAT (%)
  final double? discount; // Giá trị chiết khấu (có thể là % hoặc số tiền)
  final bool? isDiscountPercentage; // true nếu discount là %, false nếu là số tiền

  SaleItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    this.vatRate = 10.0, // Mặc định 10%
    this.discount,
    this.isDiscountPercentage,
  });

  /// Tính subtotal sau khi áp dụng chiết khấu
  double get subtotal {
    final baseAmount = quantity * price;
    if (discount == null || discount == 0) {
      return baseAmount;
    }
    
    double discountAmount = 0.0;
    if (isDiscountPercentage == true) {
      // Chiết khấu theo phần trăm
      discountAmount = baseAmount * (discount! / 100);
    } else {
      // Chiết khấu theo số tiền
      discountAmount = discount!;
      // Đảm bảo không vượt quá tổng tiền
      if (discountAmount > baseAmount) {
        discountAmount = baseAmount;
      }
    }
    
    return baseAmount - discountAmount;
  }
  
  /// Số tiền được giảm cho item này
  double get discountAmount {
    if (discount == null || discount == 0) {
      return 0.0;
    }
    
    final baseAmount = quantity * price;
    if (isDiscountPercentage == true) {
      return baseAmount * (discount! / 100);
    } else {
      final discountValue = discount!;
      return discountValue > baseAmount ? baseAmount : discountValue;
    }
  }

  /// Tạo SaleItem từ Map
  factory SaleItem.fromMap(Map<String, dynamic> map) {
    return SaleItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] ?? 0).toDouble(),
      price: (map['price'] ?? 0).toDouble(),
      vatRate: (map['vatRate'] ?? 10.0).toDouble(),
      discount: map['discount'] != null ? (map['discount'] as num).toDouble() : null,
      isDiscountPercentage: map['isDiscountPercentage'] as bool?,
    );
  }

  /// Tạo danh sách SaleItem từ JSON string (dùng cho SQLite)
  static List<SaleItem> fromJsonList(String jsonString) {
    try {
      // Parse JSON string thành List
      final List<dynamic> itemsList = jsonDecode(jsonString);
      return itemsList
          .map((item) => SaleItem.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Chuyển đổi sang Map
  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal, // Tính toán tự động
      'vatRate': vatRate,
      'discount': discount,
      'isDiscountPercentage': isDiscountPercentage,
    };
  }

  /// Copy với các trường được cập nhật
  SaleItem copyWith({
    String? productId,
    String? productName,
    double? quantity,
    double? price,
    double? vatRate,
    double? discount,
    bool? isDiscountPercentage,
  }) {
    return SaleItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      vatRate: vatRate ?? this.vatRate,
      discount: discount ?? this.discount,
      isDiscountPercentage: isDiscountPercentage ?? this.isDiscountPercentage,
    );
  }
}

