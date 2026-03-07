import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:dio/dio.dart';
import '../../models/sale_model.dart';
import '../../models/shop_model.dart';
import '../sales_service.dart';
import '../einvoice_data_service.dart';
import 'base_einvoice_provider.dart';

/// Provider hóa đơn điện tử Viettel (SInvoice V2).
class ViettelInvoiceProvider extends BaseEinvoiceProvider {
  ViettelInvoiceProvider(super.dio);

  Future<String?> _getViettelAccessToken(EinvoiceConfig config) async {
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final loginUrl = '$base/auth/login';
    try {
      final res = await dio.post(
        loginUrl,
        data: {'username': config.username, 'password': config.password},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final d = res.data as Map<String, dynamic>;
        return d['access_token'] ?? d['result']?['access_token'];
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Viettel login error: $e');
    }
    return null;
  }

  @override
  Future<Map<String, String>> createInvoice({
    required SaleModel sale,
    required ShopModel shop,
    SalesService? salesService,
  }) async {
    final config = shop.einvoiceConfig!;
    final token = await _getViettelAccessToken(config);
    if (token == null) {
      throw Exception('Không lấy được token Viettel. Kiểm tra Username/Password và Base URL.');
    }
    final supplierTaxCode = shop.stax!.replaceAll(RegExp(r'[^0-9\-]'), '');
    if (supplierTaxCode.isEmpty) {
      throw Exception('Mã số thuế người bán không hợp lệ.');
    }
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final createUrl = '$base/InvoiceAPI/InvoiceWS/createInvoice/$supplierTaxCode';
    final payload = EinvoiceDataService.prepareViettelPayload(sale: sale, shop: shop);

    if (kDebugMode) debugPrint('📋 Viettel Invoice Payload: ${jsonEncode(payload)}');

    final response = await dio.post(
      createUrl,
      data: payload,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'access_token=$token',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (kDebugMode) {
      debugPrint('📡 Viettel Response Status: ${response.statusCode}');
      debugPrint('📡 Viettel Response Data: ${response.data}');
    }

    if (response.statusCode == 401) {
      throw Exception(
        'Lỗi 401 - Xác thực thất bại. Kiểm tra lại Username, Password và Base URL (Cài đặt > Hóa đơn điện tử).'
      );
    }

    final responseData = response.data;
    if (responseData is! Map<String, dynamic>) {
      throw Exception('Viettel trả về dữ liệu không hợp lệ.');
    }
    final errorCode = responseData['errorCode'];
    final description = responseData['description']?.toString() ?? '';
    if (errorCode != null && errorCode.toString().isNotEmpty) {
      throw Exception(description.isNotEmpty ? description : 'Lỗi Viettel: $errorCode');
    }
    final result = responseData['result'] as Map<String, dynamic>?;
    if (result == null) {
      throw Exception(description.isNotEmpty ? description : 'Viettel không trả về thông tin hóa đơn.');
    }
    final invoiceNo = result['invoiceNo']?.toString() ?? '';
    final reservationCode = result['reservationCode']?.toString() ?? '';
    final templateCode = (result['templateCode'] ?? config.templateCode ?? '1/001').toString();
    final invoiceSerial = shop.serial ?? '';
    final link = reservationCode.isNotEmpty
        ? 'https://vinvoice.viettel.vn/tra-cuu?reservationCode=$reservationCode'
        : '';

    final invoiceInfo = <String, String>{
      'invoiceNo': invoiceNo,
      'templateCode': templateCode,
      'invoiceSerial': invoiceSerial,
      'link': link,
    };

    if (salesService != null && invoiceNo.isNotEmpty) {
      try {
        if (shop.deductStockOnEinvoiceOnly && !sale.isStockUpdated) {
          await salesService.deductStockForSale(sale);
          if (kDebugMode) debugPrint('📦 Stock deducted on e-invoice issue for sale: ${sale.id}');
        }
        final updatedSale = sale.copyWith(
          invoiceNo: invoiceNo,
          templateCode: templateCode,
          invoiceSerial: invoiceSerial,
          einvoiceUrl: link.isNotEmpty ? link : null,
          isStockUpdated: shop.deductStockOnEinvoiceOnly ? true : sale.isStockUpdated,
        );
        await salesService.updateSale(updatedSale);
        if (kDebugMode) debugPrint('✅ SaleModel updated with Viettel invoice info: ${updatedSale.id}');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Error updating SaleModel with Viettel invoice info: $e');
      }
    }

    return invoiceInfo;
  }

  @override
  Future<String> getInvoicePdfUrl(String saleId, ShopModel shop) async {
    // Viettel: thường dùng link tra cứu đã lưu trong sale.einvoiceUrl. API getInvoiceRepresentationFile trả về bytes, không phải URL.
    throw Exception(
      'Viettel: Sử dụng link tra cứu đã lưu trong hóa đơn (einvoiceUrl). '
      'Nếu cần lấy file PDF qua API, cần gọi getInvoiceRepresentationFile và xử lý fileToBytes.',
    );
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
    if (invoiceIssueDateMs == null) {
      throw Exception(
        'Viettel yêu cầu ngày phát hành hóa đơn gốc (invoiceIssueDateMs). '
        'Truyền sale.timestamp.millisecondsSinceEpoch khi gọi annulInvoice.',
      );
    }
    final config = shop.einvoiceConfig!;
    final token = await _getViettelAccessToken(config);
    if (token == null) {
      throw Exception('Không lấy được token Viettel.');
    }
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final cancelUrl = '$base/InvoiceAPI/InvoiceWS/cancelTransactionInvoice';
    // Viettel: strIssueDate = ngày phát hành hóa đơn gốc (epoch ms), không phải thời điểm hủy
    final body = {
      'supplierTaxCode': shop.stax ?? '',
      'invoiceNo': invoiceId,
      'strIssueDate': invoiceIssueDateMs,
      'additionalReferenceDesc': reason,
      'additionalReferenceDate': DateTime.now().millisecondsSinceEpoch,
      'reasonDelete': reason,
    };

    final response = await dio.post(
      cancelUrl,
      data: body,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'access_token=$token',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      final data = response.data as Map<String, dynamic>;
      final errorCode = data['errorCode'];
      if (errorCode != null && errorCode.toString().isNotEmpty) {
        throw Exception(data['description']?.toString() ?? 'Không thể hủy hóa đơn Viettel');
      }
      return {
        'success': true,
        'data': data,
        'agreementDocument': agreementDocument,
        'customerAgreement': customerAgreement,
      };
    }
    throw Exception('Không thể hủy hóa đơn Viettel');
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
    final token = await _getViettelAccessToken(config);
    if (token == null) {
      throw Exception('Không lấy được token Viettel. Kiểm tra Username/Password và Base URL.');
    }
    final supplierTaxCode = shop.stax!.replaceAll(RegExp(r'[^0-9\-]'), '');
    if (supplierTaxCode.isEmpty) {
      throw Exception('Mã số thuế người bán không hợp lệ.');
    }
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final createUrl = '$base/InvoiceAPI/InvoiceWS/createInvoice/$supplierTaxCode';
    final payload = EinvoiceDataService.prepareViettelReplacementPayload(
      originalSale: originalSale,
      replacementSale: replacementSale,
      shop: shop,
      reason: reason,
    );

    if (kDebugMode) debugPrint('📋 Viettel Replacement Invoice Payload: ${jsonEncode(payload)}');

    final response = await dio.post(
      createUrl,
      data: payload,
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          'Cookie': 'access_token=$token',
        },
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (kDebugMode) {
      debugPrint('📡 Viettel Replacement Response Status: ${response.statusCode}');
      debugPrint('📡 Viettel Replacement Response Data: ${response.data}');
    }

    final responseData = response.data;
    if (responseData is! Map<String, dynamic>) {
      throw Exception('Viettel trả về dữ liệu không hợp lệ.');
    }
    final errorCode = responseData['errorCode'];
    final description = responseData['description']?.toString() ?? '';
    if (errorCode != null && errorCode.toString().isNotEmpty) {
      throw Exception(description.isNotEmpty ? description : 'Lỗi Viettel: $errorCode');
    }
    final result = responseData['result'] as Map<String, dynamic>?;
    if (result == null) {
      throw Exception(description.isNotEmpty ? description : 'Viettel không trả về thông tin hóa đơn thay thế.');
    }
    final invoiceNo = result['invoiceNo']?.toString() ?? '';
    final reservationCode = result['reservationCode']?.toString() ?? '';
    final templateCode = (result['templateCode'] ?? config.templateCode ?? '1/001').toString();
    final invoiceSerial = shop.serial ?? '';
    final link = reservationCode.isNotEmpty
        ? 'https://vinvoice.viettel.vn/tra-cuu?reservationCode=$reservationCode'
        : '';

    final invoiceInfo = <String, String>{
      'invoiceNo': invoiceNo,
      'templateCode': templateCode,
      'invoiceSerial': invoiceSerial,
      'link': link,
    };

    if (salesService != null && invoiceNo.isNotEmpty) {
      try {
        if (shop.deductStockOnEinvoiceOnly && !replacementSale.isStockUpdated) {
          await salesService.deductStockForSale(replacementSale);
          if (kDebugMode) debugPrint('📦 Stock deducted on replacement e-invoice for sale: ${replacementSale.id}');
        }
        final updatedSale = replacementSale.copyWith(
          invoiceNo: invoiceNo,
          templateCode: templateCode,
          invoiceSerial: invoiceSerial,
          einvoiceUrl: link.isNotEmpty ? link : null,
          isStockUpdated: shop.deductStockOnEinvoiceOnly ? true : replacementSale.isStockUpdated,
        );
        await salesService.updateSale(updatedSale);
        if (kDebugMode) debugPrint('✅ Replacement SaleModel updated with Viettel invoice info: ${updatedSale.id}');
      } catch (e) {
        if (kDebugMode) debugPrint('⚠️ Error updating replacement SaleModel with Viettel invoice info: $e');
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
    // Chỉ tra cứu khi đã có link (đã gửi lên Viettel, có thể chờ CQT cấp mã)
    if (sale.einvoiceUrl == null || sale.einvoiceUrl!.isEmpty) {
      return null;
    }
    final config = shop.einvoiceConfig!;
    final token = await _getViettelAccessToken(config);
    if (token == null) return null;
    final supplierTaxCode = shop.stax?.replaceAll(RegExp(r'[^0-9\-]'), '') ?? '';
    if (supplierTaxCode.isEmpty) return null;
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    final searchUrl = '$base/InvoiceAPI/InvoiceWS/searchInvoiceByTransactionUuid';
    final formBody = 'supplierTaxCode=${Uri.encodeComponent(supplierTaxCode)}&transactionUuid=${Uri.encodeComponent(sale.id)}';

    try {
      final response = await dio.post(
        searchUrl,
        data: formBody,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8',
            'Cookie': 'access_token=$token',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (kDebugMode) {
        debugPrint('📡 Viettel checkInvoiceStatus Response: ${response.statusCode} ${response.data}');
      }

      if (response.statusCode != 200 || response.data is! Map<String, dynamic>) return null;
      final data = response.data as Map<String, dynamic>;
      final errorCode = data['errorCode'];
      if (errorCode != null && errorCode.toString().isNotEmpty) return null;
      final result = data['result'];
      if (result == null) return null;
      final resultMap = result is Map<String, dynamic> ? result : null;
      if (resultMap == null) return null;

      final invoiceNo = resultMap['invoiceNo']?.toString() ?? '';
      final reservationCode = resultMap['reservationCode']?.toString() ?? '';
      final templateCode = (resultMap['templateCode'] ?? config.templateCode ?? '1/001').toString();
      final invoiceSerial = shop.serial ?? '';
      final link = reservationCode.isNotEmpty
          ? 'https://vinvoice.viettel.vn/tra-cuu?reservationCode=$reservationCode'
          : (sale.einvoiceUrl ?? '');

      final info = <String, String>{
        'invoiceNo': invoiceNo,
        'templateCode': templateCode,
        'invoiceSerial': invoiceSerial,
        'link': link,
      };

      if (salesService != null && invoiceNo.isNotEmpty) {
        try {
          final updatedSale = sale.copyWith(
            invoiceNo: invoiceNo,
            templateCode: templateCode,
            invoiceSerial: invoiceSerial,
            einvoiceUrl: link.isNotEmpty ? link : sale.einvoiceUrl,
          );
          await salesService.updateSale(updatedSale);
          if (kDebugMode) debugPrint('✅ SaleModel updated with Viettel invoiceNo from checkInvoiceStatus: ${sale.id}');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Error updating SaleModel after checkInvoiceStatus: $e');
        }
      }

      return info;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ Viettel checkInvoiceStatus error: $e');
      return null;
    }
  }

  @override
  Future<void> testConnection(ShopModel shop) async {
    final config = shop.einvoiceConfig;
    if (config == null) throw Exception('Chưa cấu hình HĐĐT.');
    final token = await _getViettelAccessToken(config);
    if (token == null) {
      throw Exception('Không lấy được token. Kiểm tra Username, Password và Base URL.');
    }
  }
}
