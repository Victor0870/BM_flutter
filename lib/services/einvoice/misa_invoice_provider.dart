import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:dio/dio.dart';
import '../../models/sale_model.dart';
import '../../models/shop_model.dart';
import '../sales_service.dart';
import '../einvoice_data_service.dart';
import 'base_einvoice_provider.dart';

/// Provider hóa đơn điện tử MISA meInvoice.
/// API: https://doc.meinvoice.vn (Token, Create invoice, Publish).
/// Lưu ý: MISA yêu cầu 3 bước — (1) Tạo hóa đơn → (2) Ký điện tử XML → (3) Phát hành.
/// Bước 2 thường cần MISA Sign Service (USB Token/HSM). Ở đây chỉ triển khai bước 1 (create raw);
/// nếu có backend ký + gọi publish thì có thể mở rộng createInvoice để gọi tiếp bước 2–3.
class MisaInvoiceProvider extends BaseEinvoiceProvider {
  MisaInvoiceProvider(super.dio);

  String _baseUrl(EinvoiceConfig config) {
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    return base;
  }

  Future<String?> _getToken(ShopModel shop) async {
    final config = shop.einvoiceConfig!;
    final appId = config.appId?.trim();
    if (appId == null || appId.isEmpty) {
      throw Exception('MISA yêu cầu AppID. Vui lòng cấu hình AppID trong Cài đặt HĐĐT.');
    }
    final base = _baseUrl(config);
    final tokenUrl = '$base/api/integration/auth/token';
    final taxCode = shop.stax?.replaceAll(RegExp(r'[^0-9\-]'), '') ?? '';
    if (taxCode.isEmpty) {
      throw Exception('Mã số thuế người bán không hợp lệ.');
    }
    try {
      final response = await dio.post(
        tokenUrl,
        data: {
          'appid': appId,
          'taxcode': taxCode,
          'username': config.username,
          'password': config.password,
        },
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final d = response.data as Map<String, dynamic>;
        final success = d['Success'] == true;
        if (success && d['Data'] != null) {
          return d['Data'].toString();
        }
        final err = d['ErrorCode']?.toString() ?? d['Errors']?.toString() ?? 'Lỗi không xác định';
        throw Exception('MISA Token: $err');
      }
      if (response.statusCode == 401) {
        throw Exception(
          'Lỗi 401 - Xác thực MISA thất bại. Kiểm tra AppID, Username, Password và Mã số thuế (Cài đặt > Hóa đơn điện tử).'
        );
      }
      throw Exception('MISA Token: HTTP ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) debugPrint('❌ MISA get token: $e');
      rethrow;
    }
  }

  @override
  Future<Map<String, String>> createInvoice({
    required SaleModel sale,
    required ShopModel shop,
    SalesService? salesService,
  }) async {
    final config = shop.einvoiceConfig!;
    final token = await _getToken(shop);
    final base = _baseUrl(config);
    final createUrl = '$base/api/v3/itg/invoicepublishing/createinvoice';
    final singlePayload = EinvoiceDataService.prepareMisaPayload(sale: sale, shop: shop);
    final body = [singlePayload];

    if (kDebugMode) debugPrint('📋 MISA Create Invoice Payload: ${jsonEncode(body)}');

    final response = await dio.post(
      createUrl,
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'CompanyTaxCode': shop.stax ?? '',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (kDebugMode) {
      debugPrint('📡 MISA Create Response Status: ${response.statusCode}');
      debugPrint('📡 MISA Create Response Data: ${response.data}');
    }

    if (response.statusCode != 200) {
      if (response.statusCode == 401) {
        throw Exception(
          'Lỗi 401 - Xác thực thất bại. Kiểm tra lại Username, Password và Base URL (Cài đặt > Hóa đơn điện tử).'
        );
      }
      throw Exception('MISA Create Invoice: HTTP ${response.statusCode}');
    }

    final responseData = response.data;
    if (responseData is! Map<String, dynamic>) {
      throw Exception('MISA trả về dữ liệu không hợp lệ.');
    }
    if (responseData['Success'] != true) {
      final err = responseData['ErrorCode']?.toString() ?? responseData['Errors']?.toString() ?? 'Lỗi không xác định';
      throw Exception('MISA: $err');
    }

    final dataStr = responseData['Data']?.toString();
    if (dataStr == null || dataStr.isEmpty) {
      throw Exception('MISA không trả về Data.');
    }

    List<dynamic> list;
    try {
      list = jsonDecode(dataStr) as List<dynamic>;
    } catch (_) {
      throw Exception('MISA Data không phải JSON array.');
    }
    if (list.isEmpty) throw Exception('MISA Data rỗng.');

    final first = list.first as Map<String, dynamic>;
    final refId = first['RefID']?.toString() ?? sale.id;
    final transactionId = first['TransactionID']?.toString() ?? '';
    final invNo = first['InvNo']?.toString() ?? '';
    final invoiceDataXml = first['InvoiceData']?.toString() ?? '';

    final link = transactionId.isNotEmpty
        ? 'https://app.meinvoice.vn/tra-cuu?transactionId=$transactionId'
        : '';

    final invoiceInfo = <String, String>{
      'invoiceNo': invNo,
      'templateCode': config.templateCode ?? '1',
      'invoiceSerial': config.templateCode ?? shop.serial ?? '',
      'link': link,
      if (refId.isNotEmpty) 'refId': refId,
      if (transactionId.isNotEmpty) 'transactionId': transactionId,
    };

    if (invoiceDataXml.isNotEmpty) {
      invoiceInfo['invoiceData'] = invoiceDataXml;
    }

    if (salesService != null && invNo.isNotEmpty) {
      try {
        if (shop.deductStockOnEinvoiceOnly && !sale.isStockUpdated) {
          await salesService.deductStockForSale(sale);
          if (kDebugMode) debugPrint('📦 Stock deducted on e-invoice issue for sale: ${sale.id}');
        }
        final updatedSale = sale.copyWith(
          invoiceNo: invNo,
          templateCode: invoiceInfo['templateCode'],
          invoiceSerial: invoiceInfo['invoiceSerial'],
          einvoiceUrl: link.isNotEmpty ? link : null,
          isStockUpdated: shop.deductStockOnEinvoiceOnly ? true : sale.isStockUpdated,
        );
        await salesService.updateSale(updatedSale);
        if (kDebugMode) debugPrint('✅ SaleModel updated with MISA invoice info: ${updatedSale.id}');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Error updating SaleModel with MISA invoice info: $e');
      }
    }

    return invoiceInfo;
  }

  @override
  Future<String> getInvoicePdfUrl(String saleId, ShopModel shop) async {
    final config = shop.einvoiceConfig!;
    final token = await _getToken(shop);
    final base = _baseUrl(config);
    final url = '$base/api/v2/v3sainvoice/?refID=$saleId';
    final response = await dio.get(
      url,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
          'CompanyTaxCode': shop.stax ?? '',
          'Content-Type': 'application/json',
        },
      ),
    );
    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      final d = response.data as Map<String, dynamic>;
      final link = d['PdfLink'] ?? d['Link'] ?? d['InvoiceLink'];
      if (link != null && link.toString().isNotEmpty) return link.toString();
    }
    throw Exception('Không tìm thấy link PDF hóa đơn MISA.');
  }

  @override
  Future<Map<String, dynamic>> annulInvoice({
    required String invoiceId,
    required String reason,
    required ShopModel shop,
    String? agreementDocument,
    String? customerAgreement,
    int? invoiceIssueDateMs,
  }) async {
    throw Exception(
      'Hủy hóa đơn MISA cần gọi API riêng trên doc.meinvoice.vn. '
      'Vui lòng thực hiện hủy trên portal MISA hoặc tích hợp API hủy theo tài liệu MISA.',
    );
  }

  @override
  Future<Map<String, String>> issueReplacementInvoice({
    required SaleModel originalSale,
    required SaleModel replacementSale,
    required ShopModel shop,
    required String reason,
    SalesService? salesService,
    String? agreementDocument,
    String? customerAgreement,
  }) async {
    final config = shop.einvoiceConfig!;
    final token = await _getToken(shop);
    final base = _baseUrl(config);
    final createUrl = '$base/api/v3/itg/invoicepublishing/createinvoice';
    final singlePayload = EinvoiceDataService.prepareMisaPayload(
      sale: replacementSale,
      shop: shop,
      originalSale: originalSale,
      replacementReason: reason,
    );
    final body = [singlePayload];

    if (kDebugMode) debugPrint('📋 MISA Replacement Invoice Payload: ${jsonEncode(body)}');

    final response = await dio.post(
      createUrl,
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'CompanyTaxCode': shop.stax ?? '',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('MISA Replacement: HTTP ${response.statusCode}');
    }
    final responseData = response.data;
    if (responseData is! Map<String, dynamic> || responseData['Success'] != true) {
      final err = responseData is Map ? (responseData['ErrorCode'] ?? responseData['Errors']) : 'Lỗi không xác định';
      throw Exception('MISA Replacement: $err');
    }

    final dataStr = responseData['Data']?.toString();
    if (dataStr == null || dataStr.isEmpty) throw Exception('MISA Replacement: Data rỗng.');
    List<dynamic> list;
    try {
      list = jsonDecode(dataStr) as List<dynamic>;
    } catch (_) {
      throw Exception('MISA Replacement: Data không hợp lệ.');
    }
    if (list.isEmpty) throw Exception('MISA Replacement: Data rỗng.');
    final first = list.first as Map<String, dynamic>;
    final invNo = first['InvNo']?.toString() ?? '';
    final transactionId = first['TransactionID']?.toString() ?? '';
    final link = transactionId.isNotEmpty
        ? 'https://app.meinvoice.vn/tra-cuu?transactionId=$transactionId'
        : '';

    final invoiceInfo = <String, String>{
      'invoiceNo': invNo,
      'templateCode': config.templateCode ?? '1',
      'invoiceSerial': shop.serial ?? '',
      'link': link,
    };

    if (salesService != null && invNo.isNotEmpty) {
      try {
        final updatedSale = replacementSale.copyWith(
          invoiceNo: invNo,
          templateCode: invoiceInfo['templateCode'],
          invoiceSerial: invoiceInfo['invoiceSerial'],
          einvoiceUrl: link.isNotEmpty ? link : null,
        );
        await salesService.updateSale(updatedSale);
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Error updating replacement SaleModel (MISA): $e');
      }
    }
    return invoiceInfo;
  }

  @override
  Future<Map<String, String>?> checkInvoiceStatus({
    required SaleModel sale,
    required ShopModel shop,
    SalesService? salesService,
  }) async {
    return null;
  }

  @override
  Future<void> testConnection(ShopModel shop) async {
    await _getToken(shop);
  }
}
