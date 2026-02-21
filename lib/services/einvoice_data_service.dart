import '../models/sale_model.dart';
import '../models/shop_model.dart';

/// Service chuẩn bị dữ liệu cho hóa đơn điện tử (FPT và Viettel).
/// FPT dùng format 01/MTT (inv, items, sum, vat, total...). Viettel dùng generalInvoiceInfo, sellerInfo, buyerInfo, itemInfo, summarizeInfo, taxBreakdowns.
class EinvoiceDataService {
  /// Chuẩn bị payload JSON theo đặc tả FPT (01/MTT) từ SaleModel và ShopModel
  static Map<String, dynamic> prepareFptPayload({
    required SaleModel sale,
    required ShopModel shop,
  }) {
    // Tính toán tổng tiền và thuế
    double sum = 0.0; // Tổng tiền chưa thuế
    double vat = 0.0; // Tổng tiền thuế

    // Chuyển đổi items (01/MTT yêu cầu: amount, vat, total cho mỗi dòng)
    final List<Map<String, dynamic>> itemsList = sale.items.map((item) {
      // Thành tiền chưa thuế (dùng subtotal đã trừ chiết khấu dòng nếu có)
      final amount = item.subtotal;
      sum += amount;

      // Sử dụng vatRate từ từng item
      final vatRate = item.vatRate;
      final itemVat = (amount * vatRate) / 100;
      vat += itemVat;

      // Map thuế suất: 0, 5, 8, 10 hoặc -1 (không chịu thuế)
      int vrt = 10; // Mặc định 10%
      if (vatRate == 0) {
        vrt = 0;
      } else if (vatRate == 5) {
        vrt = 5;
      } else if (vatRate == 8) {
        vrt = 8;
      } else if (vatRate == 10) {
        vrt = 10;
      } else if (vatRate < 0) {
        vrt = -1; // Không chịu thuế
      }

      return {
        'name': item.productName,
        'unit': 'cái', // Đơn vị mặc định, có thể lấy từ ProductModel nếu cần
        'price': item.price.toStringAsFixed(2),
        'quantity': item.quantity.toStringAsFixed(2),
        'vrt': vrt.toString(),
        'amount': amount.toStringAsFixed(2),
        'vat': itemVat.toStringAsFixed(2), // Bắt buộc 01/MTT: Số tiền thuế từng hàng hóa
        'total': (amount + itemVat).toStringAsFixed(2), // Bắt buộc 01/MTT: Tổng tiền đã bao gồm thuế
      };
    }).toList();

    // Format ngày hóa đơn: yyyy-mm-dd hh:mm:ss
    final formattedDate = '${sale.timestamp.year.toString().padLeft(4, '0')}-'
        '${sale.timestamp.month.toString().padLeft(2, '0')}-'
        '${sale.timestamp.day.toString().padLeft(2, '0')} '
        '${sale.timestamp.hour.toString().padLeft(2, '0')}:'
        '${sale.timestamp.minute.toString().padLeft(2, '0')}:'
        '${sale.timestamp.second.toString().padLeft(2, '0')}';

    // Map payment method
    String paym = 'TM';
    if (sale.paymentMethod.toUpperCase() == 'CARD') {
      paym = 'TM';
    } else if (sale.paymentMethod.toUpperCase() == 'TRANSFER') {
      paym = 'CK';
    } else if (sale.paymentMethod.toUpperCase() == 'CASH') {
      paym = 'TM';
    }

    // Chiết khấu: tradeamount (chiết khấu thương mại), discount (giảm trừ khác) - bắt buộc theo FPT
    final tradeamount = sale.totalDiscountAmount ?? 0.0;
    const discount = 0.0; // Giảm trừ khác - thường = 0 với hóa đơn bán lẻ

    // total = sum - tradeamount - discount + vat (theo công thức FPT)
    final total = sum - tradeamount - discount + vat;

    // Cấu trúc payload theo đặc tả FPT
    final invMap = {
      'type': '01/MTT', // Hóa đơn GTGT từ máy tính tiền
      'form': '1', // Mẫu số cho hóa đơn GTGT
      'sid': sale.id, // Mã duy nhất cho mỗi giao dịch
      'idt': formattedDate, // Ngày hóa đơn
      'paym': paym, // Hình thức thanh toán
      'aun': '2', // Gán cố định = 2 (Để hệ thống FPT tự động cấp số và mã CQT)
      'stax': shop.stax ?? '', // Mã số thuế người bán
      'serial': shop.serial ?? '', // Ký hiệu hóa đơn
    };

    // Thêm thông tin khách hàng nếu có
    if (sale.customerName != null && sale.customerName!.isNotEmpty) {
      invMap['bname'] = sale.customerName!; // Tên khách hàng
    }
    if (sale.customerAddress != null && sale.customerAddress!.isNotEmpty) {
      invMap['baddr'] = sale.customerAddress!; // Địa chỉ khách hàng
    }
    if (sale.customerTaxCode != null && sale.customerTaxCode!.isNotEmpty) {
      invMap['btax'] = sale.customerTaxCode!; // MST khách hàng
    }

    // 01/MTT bắt buộc: sumv, vatv, totalv (quy đổi VNĐ - dùng = sum, vat, total khi nguyên tệ là VNĐ)
    return {
      'inv': invMap,
      'items': itemsList,
      'sum': sum.toStringAsFixed(2),
      'vat': vat.toStringAsFixed(2),
      'total': total.toStringAsFixed(2),
      'tradeamount': tradeamount.toStringAsFixed(2),
      'discount': discount.toStringAsFixed(2),
      'sumv': sum.toStringAsFixed(2),
      'vatv': vat.toStringAsFixed(2),
      'totalv': total.toStringAsFixed(2),
    };
  }

  /// Chuẩn bị payload JSON theo đặc tả Viettel (SInvoice V2) từ SaleModel và ShopModel.
  /// Viettel dùng templateCode, invoiceSeries trong generalInvoiceInfo; itemInfo với itemTotalAmountWithoutTax, taxPercentage, taxAmount; summarizeInfo; taxBreakdowns.
  static Map<String, dynamic> prepareViettelPayload({
    required SaleModel sale,
    required ShopModel shop,
  }) {
    final stax = shop.stax ?? '';
    final serial = shop.serial ?? '';
    final templateCode = shop.einvoiceConfig?.templateCode ?? '1/001';

    final invoiceIssuedDate = sale.timestamp.millisecondsSinceEpoch;

    final generalInvoiceInfo = {
      'transactionUuid': sale.id,
      'invoiceType': '1',
      'templateCode': templateCode,
      'invoiceSeries': serial,
      'invoiceIssuedDate': invoiceIssuedDate,
      'currencyCode': 'VND',
      'exchangeRate': 1,
      'adjustmentType': '1',
      'paymentStatus': true,
      'cusGetInvoiceRight': true,
    };

    final sellerInfo = {
      'sellerLegalName': shop.name,
      'sellerTaxCode': stax,
      'sellerAddressLine': shop.address ?? '',
      'sellerPhoneNumber': shop.phone ?? '',
      'sellerEmail': shop.email ?? '',
    };

    final buyerName = sale.customerName ?? sale.customerTaxCode ?? 'Khách lẻ';
    final buyerInfo = {
      'buyerName': buyerName,
      'buyerLegalName': sale.customerName ?? sale.customerTaxCode ?? buyerName,
      'buyerTaxCode': sale.customerTaxCode ?? '',
      'buyerAddressLine': sale.customerAddress ?? '',
    };

    final paymentMethodName = sale.paymentMethod.toUpperCase() == 'TRANSFER' ? 'Chuyển khoản' : 'Tiền mặt';
    final payments = [
      {'paymentMethodName': paymentMethodName}
    ];

    double sumWithoutTax = 0.0;
    double totalTax = 0.0;
    final List<Map<String, dynamic>> itemInfo = [];
    int lineNumber = 1;
    for (final item in sale.items) {
      final amount = item.subtotal;
      final vatRate = item.vatRate;
      final taxPct = vatRate == 0 ? 0 : (vatRate == 5 ? 5 : (vatRate == 8 ? 8 : (vatRate == 10 ? 10 : -1)));
      final taxAmount = (amount * vatRate) / 100;
      sumWithoutTax += amount;
      totalTax += taxAmount;
      itemInfo.add({
        'lineNumber': lineNumber++,
        'itemCode': item.productId,
        'itemName': item.productName,
        'unitName': 'cái',
        'unitPrice': item.price,
        'quantity': item.quantity,
        'selection': 1,
        'itemTotalAmountWithoutTax': amount,
        'taxPercentage': taxPct,
        'taxAmount': taxAmount,
        'discount': 0,
        'itemDiscount': 0,
      });
    }

    final discountAmount = sale.totalDiscountAmount ?? 0.0;
    final totalAmountWithTax = sumWithoutTax + totalTax - discountAmount;
    final totalAmountAfterDiscount = sumWithoutTax - discountAmount;

    final summarizeInfo = {
      'totalAmountWithoutTax': sumWithoutTax,
      'totalTaxAmount': totalTax,
      'totalAmountWithTax': totalAmountWithTax,
      'discountAmount': discountAmount,
      'totalAmountAfterDiscount': totalAmountAfterDiscount,
    };

    final Map<double, double> taxToAmount = {};
    final Map<double, double> taxToTaxAmount = {};
    for (final item in sale.items) {
      final amount = item.subtotal;
      final vatRate = item.vatRate;
      final taxAmount = (amount * vatRate) / 100;
      taxToAmount[vatRate] = (taxToAmount[vatRate] ?? 0) + amount;
      taxToTaxAmount[vatRate] = (taxToTaxAmount[vatRate] ?? 0) + taxAmount;
    }
    final taxBreakdowns = <Map<String, dynamic>>[];
    for (final e in taxToAmount.entries) {
      final taxPct = e.key == 0 ? 0 : (e.key == 5 ? 5 : (e.key == 8 ? 8 : (e.key == 10 ? 10 : -1)));
      taxBreakdowns.add({
        'taxPercentage': taxPct,
        'taxableAmount': e.value,
        'taxAmount': taxToTaxAmount[e.key]!,
      });
    }

    return {
      'generalInvoiceInfo': generalInvoiceInfo,
      'sellerInfo': sellerInfo,
      'buyerInfo': buyerInfo,
      'payments': payments,
      'itemInfo': itemInfo,
      'summarizeInfo': summarizeInfo,
      'taxBreakdowns': taxBreakdowns,
    };
  }

  /// Chuẩn bị payload hóa đơn thay thế Viettel (SInvoice V2): adjustmentType=3, thông tin hóa đơn gốc.
  static Map<String, dynamic> prepareViettelReplacementPayload({
    required SaleModel originalSale,
    required SaleModel replacementSale,
    required ShopModel shop,
    required String reason,
  }) {
    final payload = prepareViettelPayload(sale: replacementSale, shop: shop);
    final general = payload['generalInvoiceInfo'] as Map<String, dynamic>;
    general['adjustmentType'] = '3'; // 3 = Thay thế hóa đơn
    general['originalInvoiceId'] = originalSale.invoiceNo ?? originalSale.id;
    general['originalInvoiceIssueDate'] = originalSale.timestamp.millisecondsSinceEpoch;
    general['additionalReferenceDesc'] = reason;
    general['transactionUuid'] = replacementSale.id;
    general['invoiceIssuedDate'] = replacementSale.timestamp.millisecondsSinceEpoch;
    return payload;
  }

  /// Chuẩn bị payload theo đặc tả MISA meInvoice (OriginalInvoiceData).
  /// API: POST /api/v3/itg/invoicepublishing/createinvoice
  /// Tham khảo: https://doc.meinvoice.vn/api/Document/InvoicePublishing.html
  static Map<String, dynamic> prepareMisaPayload({
    required SaleModel sale,
    required ShopModel shop,
    SaleModel? originalSale,
    String? replacementReason,
  }) {
    final serial = shop.serial ?? '1K21TAA';
    final invDate = sale.timestamp.toUtc().toIso8601String();

    double sumWithoutVat = 0.0;
    double totalVat = 0.0;
    int lineNum = 1;
    final List<Map<String, dynamic>> details = [];
    final Map<double, double> taxToAmount = {};
    final Map<double, double> taxToVat = {};

    for (final item in sale.items) {
      final amount = item.subtotal;
      final vatRate = item.vatRate;
      final vatAmount = (amount * vatRate) / 100;
      sumWithoutVat += amount;
      totalVat += vatAmount;
      taxToAmount[vatRate] = (taxToAmount[vatRate] ?? 0) + amount;
      taxToVat[vatRate] = (taxToVat[vatRate] ?? 0) + vatAmount;

      final vatRateName = vatRate == 0 ? '0%' : (vatRate == 5 ? '5%' : (vatRate == 8 ? '8%' : (vatRate == 10 ? '10%' : 'Không chịu thuế')));
      details.add({
        'ItemType': 1,
        'LineNumber': lineNum,
        'SortOrder': lineNum,
        'ItemCode': item.productId,
        'ItemName': item.productName,
        'UnitName': 'cái',
        'Quantity': item.quantity,
        'UnitPrice': item.price,
        'DiscountRate': 0.0,
        'DiscountAmountOC': 0.0,
        'DiscountAmount': 0.0,
        'AmountOC': amount,
        'Amount': amount,
        'AmountWithoutVATOC': amount,
        'AmountWithoutVAT': amount,
        'VATRateName': vatRateName,
        'VATAmountOC': vatAmount,
        'VATAmount': vatAmount,
      });
      lineNum++;
    }

    final discountAmount = sale.totalDiscountAmount ?? 0.0;
    final totalAmount = sumWithoutVat + totalVat - discountAmount;
    final totalAmountInWords = _numberToWordsVn(totalAmount.round());

    final taxRateInfo = <Map<String, dynamic>>[];
    for (final e in taxToAmount.entries) {
      taxRateInfo.add({
        'VATRateName': e.key == 0 ? '0%' : (e.key == 5 ? '5%' : (e.key == 8 ? '8%' : (e.key == 10 ? '10%' : 'Không chịu thuế'))),
        'AmountWithoutVATOC': e.value,
        'VATAmountOC': taxToVat[e.key] ?? 0,
      });
    }

    final payMethod = sale.paymentMethod.toUpperCase() == 'TRANSFER' ? 'CK' : 'TM';
    final payload = {
      'RefID': sale.id,
      'InvSeries': serial,
      'InvoiceName': 'Hóa đơn giá trị gia tăng',
      'InvDate': invDate,
      'CurrencyCode': 'VND',
      'ExchangeRate': 1.0,
      'PaymentMethodName': payMethod == 'CK' ? 'TM/CK' : 'TM',
      'BuyerLegalName': sale.customerName ?? sale.customerTaxCode ?? 'Khách lẻ',
      'BuyerTaxCode': sale.customerTaxCode ?? '',
      'BuyerAddress': sale.customerAddress ?? '',
      'BuyerCode': '',
      'BuyerPhoneNumber': '',
      'BuyerEmail': '',
      'BuyerFullName': sale.customerName ?? 'Khách lẻ',
      'BuyerBankAccount': '',
      'BuyerBankName': '',
      'ReferenceType': null,
      'OrgInvoiceType': null,
      'OrgInvTemplateNo': null,
      'OrgInvSeries': null,
      'OrgInvNo': null,
      'OrgInvDate': null,
      'TotalSaleAmountOC': sumWithoutVat,
      'TotalAmountWithoutVATOC': sumWithoutVat,
      'TotalVATAmountOC': totalVat,
      'TotalDiscountAmountOC': discountAmount,
      'TotalAmountOC': totalAmount,
      'TotalSaleAmount': sumWithoutVat,
      'TotalAmountWithoutVAT': sumWithoutVat,
      'TotalVATAmount': totalVat,
      'TotalDiscountAmount': discountAmount,
      'TotalAmount': totalAmount,
      'TotalAmountInWords': totalAmountInWords,
      'OriginalInvoiceDetail': details,
      'TaxRateInfo': taxRateInfo,
      'OptionUserDefined': {
        'MainCurrency': 'VND',
        'AmountDecimalDigits': '0',
        'AmountOCDecimalDigits': '2',
        'UnitPriceOCDecimalDigits': '0',
        'UnitPriceDecimalDigits': '1',
        'QuantityDecimalDigits': '2',
        'CoefficientDecimalDigits': '2',
        'ExchangRateDecimalDigits': '0',
      },
    };

    if (originalSale != null && replacementReason != null) {
      payload['ReferenceType'] = 1;
      payload['OrgInvoiceType'] = 1;
      payload['OrgInvTemplateNo'] = '1';
      payload['OrgInvSeries'] = originalSale.invoiceSerial ?? shop.serial ?? '';
      payload['OrgInvNo'] = originalSale.invoiceNo ?? originalSale.id;
      payload['OrgInvDate'] = originalSale.timestamp.toUtc().toIso8601String().split('T').first;
    }

    return payload;
  }

  static String _numberToWordsVn(int n) {
    if (n <= 0) return 'Không đồng chẵn.';
    const u = ['', 'một', 'hai', 'ba', 'bốn', 'năm', 'sáu', 'bảy', 'tám', 'chín'];
    String block(int x) {
      if (x == 0) return '';
      if (x < 10) return u[x];
      if (x < 20) return 'mười ${x == 10 ? "" : u[x - 10]}'.trim();
      if (x < 100) return '${u[x ~/ 10]} mươi ${x % 10 == 0 ? "" : u[x % 10]}'.trim();
      return '${u[x ~/ 100]} trăm ${block(x % 100)}'.trim();
    }
    if (n < 1000) return '${block(n)} đồng chẵn.';
    if (n < 1000000) return '${block(n ~/ 1000)} nghìn ${n % 1000 == 0 ? "" : block(n % 1000)} đồng chẵn.'.trim();
    if (n < 1000000000) return '${block(n ~/ 1000000)} triệu ${n % 1000000 == 0 ? "" : _numberToWordsVn(n % 1000000).replaceAll(" đồng chẵn.", "")} đồng chẵn.'.trim();
    return '$n đồng chẵn.';
  }
}

