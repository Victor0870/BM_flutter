import 'package:dio/dio.dart';
import '../models/sale_model.dart';
import '../models/shop_model.dart';
import 'sales_service.dart';
import 'einvoice/base_einvoice_provider.dart';
import 'einvoice/fpt_invoice_provider.dart';
import 'einvoice/viettel_invoice_provider.dart';
import 'einvoice/misa_invoice_provider.dart';

/// Factory service hóa đơn điện tử: chọn đúng Provider (FPT, Viettel, sau này MISA) theo cấu hình Shop.
/// Chỉ validate và delegate; logic nằm trong từng Provider.
class EinvoiceService {
  final Dio _dio = Dio();

  /// Trả về Provider tương ứng với nhà cung cấp trong cấu hình shop.
  BaseEinvoiceProvider _getProvider(ShopModel shop) {
    final config = shop.einvoiceConfig;
    if (config == null) {
      throw Exception('Chưa cấu hình thông tin hóa đơn điện tử. Vui lòng cài đặt trong Settings.');
    }
    switch (config.provider) {
      case EinvoiceProvider.fpt:
        return FptInvoiceProvider(_dio);
      case EinvoiceProvider.viettel:
        return ViettelInvoiceProvider(_dio);
      case EinvoiceProvider.misa:
        return MisaInvoiceProvider(_dio);
    }
  }

  /// Phát hành hóa đơn điện tử (delegate tới đúng Provider).
  Future<Map<String, String>> createInvoice({
    required SaleModel sale,
    required ShopModel shop,
    SalesService? salesService,
  }) async {
    if (shop.einvoiceConfig == null) {
      throw Exception('Chưa cấu hình thông tin hóa đơn điện tử. Vui lòng cài đặt trong Settings.');
    }
    if (shop.stax == null || shop.stax!.isEmpty) {
      throw Exception('Chưa cấu hình mã số thuế. Vui lòng cài đặt trong Settings.');
    }
    if (shop.serial == null || shop.serial!.isEmpty) {
      throw Exception('Chưa cấu hình ký hiệu hóa đơn. Vui lòng cài đặt trong Settings.');
    }
    final provider = _getProvider(shop);
    return provider.createInvoice(sale: sale, shop: shop, salesService: salesService);
  }

  /// Tạo hóa đơn nháp (chỉ FPT): trạng thái Chờ phát hành, không cấp số, không cập nhật đơn hàng. Dùng để test.
  Future<Map<String, String>> createDraftInvoice({
    required SaleModel sale,
    required ShopModel shop,
  }) async {
    if (shop.einvoiceConfig == null) {
      throw Exception('Chưa cấu hình thông tin hóa đơn điện tử. Vui lòng cài đặt trong Settings.');
    }
    if (shop.einvoiceConfig!.provider != EinvoiceProvider.fpt) {
      throw Exception('Hóa đơn nháp chỉ hỗ trợ FPT. Nhà cung cấp hiện tại: ${shop.einvoiceConfig!.provider.label}.');
    }
    if (shop.stax == null || shop.stax!.isEmpty || shop.serial == null || shop.serial!.isEmpty) {
      throw Exception('Chưa cấu hình mã số thuế và ký hiệu hóa đơn trong Cài đặt Shop.');
    }
    final provider = _getProvider(shop) as FptInvoiceProvider;
    return provider.createDraftInvoice(sale: sale, shop: shop);
  }

  /// Lấy link PDF / tra cứu hóa đơn (delegate tới đúng Provider).
  Future<String> getInvoicePdfUrl(String saleId, ShopModel shop) async {
    if (shop.einvoiceConfig == null) {
      throw Exception('Chưa cấu hình thông tin hóa đơn điện tử');
    }
    final provider = _getProvider(shop);
    return provider.getInvoicePdfUrl(saleId, shop);
  }

  /// Hủy hóa đơn điện tử (delegate tới đúng Provider).
  /// [invoiceIssueDateMs]: Ngày phát hành hóa đơn gốc (epoch ms). Bắt buộc khi dùng Viettel (sale.timestamp.millisecondsSinceEpoch).
  Future<Map<String, dynamic>> annulInvoice({
    required String invoiceId,
    required String reason,
    required ShopModel shop,
    String? agreementDocument,
    String? customerAgreement,
    int? invoiceIssueDateMs,
  }) async {
    if (shop.einvoiceConfig == null) {
      throw Exception('Chưa cấu hình thông tin hóa đơn điện tử');
    }
    final provider = _getProvider(shop);
    return provider.annulInvoice(
      invoiceId: invoiceId,
      reason: reason,
      shop: shop,
      agreementDocument: agreementDocument,
      customerAgreement: customerAgreement,
      invoiceIssueDateMs: invoiceIssueDateMs,
    );
  }

  /// Phát hành hóa đơn thay thế (delegate tới đúng Provider).
  Future<Map<String, String>> issueReplacementInvoice({
    required SaleModel originalSale,
    required SaleModel replacementSale,
    required ShopModel shop,
    required String reason,
    SalesService? salesService,
    String? agreementDocument,
    String? customerAgreement,
  }) async {
    if (shop.einvoiceConfig == null) {
      throw Exception('Chưa cấu hình thông tin hóa đơn điện tử');
    }
    final provider = _getProvider(shop);
    return provider.issueReplacementInvoice(
      originalSale: originalSale,
      replacementSale: replacementSale,
      shop: shop,
      reason: reason,
      salesService: salesService,
      agreementDocument: agreementDocument,
      customerAgreement: customerAgreement,
    );
  }

  /// Kiểm tra trạng thái hóa đơn (Viettel: tra cứu theo transactionUuid, cập nhật invoiceNo khi CQT đã cấp mã).
  /// Trả về Map thông tin đã cập nhật hoặc null.
  Future<Map<String, String>?> checkInvoiceStatus({
    required SaleModel sale,
    required ShopModel shop,
    SalesService? salesService,
  }) async {
    if (shop.einvoiceConfig == null) {
      return null;
    }
    final provider = _getProvider(shop);
    return provider.checkInvoiceStatus(
      sale: sale,
      shop: shop,
      salesService: salesService,
    );
  }

  /// Kiểm tra kết nối: gọi login/token của provider tương ứng. Ném Exception nếu thất bại.
  Future<void> testConnection(ShopModel shop) async {
    if (shop.einvoiceConfig == null) {
      throw Exception('Chưa cấu hình thông tin hóa đơn điện tử.');
    }
    final provider = _getProvider(shop);
    await provider.testConnection(shop);
  }

  /// Phát hành hàng loạt hóa đơn (gọi createInvoice từng đơn).
  Future<List<Map<String, dynamic>>> bulkIssueInvoices({
    required List<SaleModel> sales,
    required ShopModel shop,
    required SalesService salesService,
  }) async {
    final results = <Map<String, dynamic>>[];
    for (final sale in sales) {
      try {
        final invoiceInfo = await createInvoice(
          sale: sale,
          shop: shop,
          salesService: salesService,
        );
        results.add({
          'saleId': sale.id,
          'success': true,
          'invoiceInfo': invoiceInfo,
        });
      } catch (e) {
        results.add({
          'saleId': sale.id,
          'success': false,
          'error': e.toString(),
        });
      }
    }
    return results;
  }
}
