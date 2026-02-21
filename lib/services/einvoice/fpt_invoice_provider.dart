import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:dio/dio.dart';
import '../../models/sale_model.dart';
import '../../models/shop_model.dart';
import '../sales_service.dart';
import '../einvoice_data_service.dart';
import '../einvoice_urls.dart';
import '../firebase_service.dart';
import 'base_einvoice_provider.dart';

/// Provider hóa đơn điện tử FPT (API NĐ70/2025).
class FptInvoiceProvider extends BaseEinvoiceProvider {
  FptInvoiceProvider(super.dio);
  final FirebaseService _firebaseService = FirebaseService();

  Future<EinvoiceUrls> _getUrls() async {
    final isTest = await _firebaseService.getIsTestMode();
    return EinvoiceUrls(isTest: isTest);
  }

  Future<String?> _getAccessToken({
    required String username,
    required String password,
    required String signinUrl,
  }) async {
    try {
      final response = await dio.post(
        signinUrl,
        data: {'username': username, 'password': password},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
        final d = response.data as Map<String, dynamic>;
        return d['access_token'] ?? d['data']?['access_token'];
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ FPT get access token: $e');
      return null;
    }
  }

  @override
  Future<Map<String, String>> createInvoice({
    required SaleModel sale,
    required ShopModel shop,
    SalesService? salesService,
  }) async {
    final config = shop.einvoiceConfig!;
    final urls = await _getUrls();
    final payload = EinvoiceDataService.prepareFptPayload(sale: sale, shop: shop);

    if (kDebugMode) debugPrint('📋 FPT Invoice Payload: ${jsonEncode(payload)}');

    String? accessToken;
    String authHeader;
    if (config.username.isNotEmpty && config.password.isNotEmpty) {
      accessToken = await _getAccessToken(
        username: config.username,
        password: config.password,
        signinUrl: urls.signinUrl,
      );
      if (accessToken != null) {
        authHeader = 'Bearer $accessToken';
      } else {
        authHeader = 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
      }
    } else {
      authHeader = 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
    }

    final response = await dio.post(
      urls.createUrl,
      data: payload,
      options: Options(
        headers: {'Content-Type': 'application/json', 'Authorization': authHeader},
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (kDebugMode) {
      debugPrint('📡 FPT Response Status: ${response.statusCode}');
      debugPrint('📡 FPT Response Data: ${response.data}');
    }

    if (response.statusCode == 200) {
      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        final data = responseData['data'] ?? responseData;
        final invoiceNo = data['invoiceNo'] ?? data['no'] ?? '';
        final templateCode = data['templateCode'] ?? data['form'] ?? '';
        final invoiceSerial = data['invoiceSerial'] ?? data['serial'] ?? '';
        final link = data['link'] ?? data['url'] ?? '';
        final invoiceInfo = <String, String>{};
        if (invoiceNo.isNotEmpty) invoiceInfo['invoiceNo'] = invoiceNo;
        if (templateCode.isNotEmpty) invoiceInfo['templateCode'] = templateCode;
        if (invoiceSerial.isNotEmpty) invoiceInfo['invoiceSerial'] = invoiceSerial;
        if (link.isNotEmpty) invoiceInfo['link'] = link;

        if (salesService != null && invoiceInfo.isNotEmpty) {
          try {
            if (shop.deductStockOnEinvoiceOnly && !sale.isStockUpdated) {
              await salesService.deductStockForSale(sale);
              if (kDebugMode) debugPrint('📦 Stock deducted on e-invoice issue for sale: ${sale.id}');
            }
            final updatedSale = sale.copyWith(
              invoiceNo: invoiceInfo['invoiceNo'],
              templateCode: invoiceInfo['templateCode'],
              invoiceSerial: invoiceInfo['invoiceSerial'],
              einvoiceUrl: invoiceInfo['link'],
              isStockUpdated: shop.deductStockOnEinvoiceOnly ? true : sale.isStockUpdated,
            );
            await salesService.updateSale(updatedSale);
            if (kDebugMode) debugPrint('✅ SaleModel updated with invoice info: ${updatedSale.id}');
          } catch (e) {
            if (kDebugMode) debugPrint('⚠️ Error updating SaleModel with invoice info: $e');
          }
        }
        return invoiceInfo;
      }
      return {'message': 'Tạo hóa đơn thành công'};
    }
    if (response.statusCode == 400) {
      final responseData = response.data;
      String errorMessage = 'Có lỗi khi tạo hóa đơn';
      if (responseData is Map<String, dynamic>) {
        errorMessage = responseData['message'] ?? responseData['error'] ?? responseData['errors']?.toString() ?? errorMessage;
      } else if (responseData is String) {
        errorMessage = responseData;
      }
      throw Exception(errorMessage);
    }
    throw Exception('Lỗi kết nối đến hệ thống hóa đơn điện tử: ${response.statusCode}');
  }

  @override
  Future<String> getInvoicePdfUrl(String saleId, ShopModel shop) async {
    final config = shop.einvoiceConfig!;
    final urls = await _getUrls();

    String? accessToken;
    String authHeader;
    if (config.username.isNotEmpty && config.password.isNotEmpty) {
      accessToken = await _getAccessToken(
        username: config.username,
        password: config.password,
        signinUrl: urls.signinUrl,
      );
      if (accessToken != null) {
        authHeader = 'Bearer $accessToken';
      } else {
        authHeader = 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
      }
    } else {
      authHeader = 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
    }

    final response = await dio.get(
      '${urls.searchUrl}/$saleId',
      options: Options(headers: {'Authorization': authHeader}),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      final data = (response.data['data'] ?? response.data) as Map<String, dynamic>?;
      if (data != null) {
        final url = data['pdfUrl'] ?? data['link'] ?? data['url'] ?? '';
        if (url.isNotEmpty) return url;
      }
    }
    throw Exception('Không tìm thấy hóa đơn');
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
    final config = shop.einvoiceConfig!;
    final urls = await _getUrls();

    String? accessToken;
    String authHeader;
    if (config.username.isNotEmpty && config.password.isNotEmpty) {
      accessToken = await _getAccessToken(
        username: config.username,
        password: config.password,
        signinUrl: urls.signinUrl,
      );
      if (accessToken != null) {
        authHeader = 'Bearer $accessToken';
      } else {
        authHeader = 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
      }
    } else {
      authHeader = 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
    }

    final payload = {
      'invoiceId': invoiceId,
      'reason': reason,
      'agreementDocument': agreementDocument ?? '',
      'customerAgreement': customerAgreement ?? '',
      'annulDate': DateTime.now().toIso8601String(),
    };

    final response = await dio.post(
      urls.deleteUrl,
      data: payload,
      options: Options(
        headers: {'Content-Type': 'application/json', 'Authorization': authHeader},
      ),
    );

    if (response.statusCode == 200) {
      return {
        'success': true,
        'data': response.data,
        'agreementDocument': agreementDocument,
        'customerAgreement': customerAgreement,
      };
    }
    throw Exception('Không thể hủy hóa đơn');
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
    final urls = await _getUrls();

    final payload = EinvoiceDataService.prepareFptPayload(sale: replacementSale, shop: shop);
    payload['originalInvoiceId'] = originalSale.invoiceNo ?? originalSale.id;
    payload['replacementReason'] = reason;
    payload['agreementDocument'] = agreementDocument ?? '';
    payload['customerAgreement'] = customerAgreement ?? '';

    if (kDebugMode) debugPrint('📋 FPT Replacement Invoice Payload: ${jsonEncode(payload)}');

    String? accessToken;
    String authHeader;
    if (config.username.isNotEmpty && config.password.isNotEmpty) {
      accessToken = await _getAccessToken(
        username: config.username,
        password: config.password,
        signinUrl: urls.signinUrl,
      );
      if (accessToken != null) {
        authHeader = 'Bearer $accessToken';
      } else {
        authHeader = 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
      }
    } else {
      authHeader = 'Basic ${base64Encode(utf8.encode('${config.username}:${config.password}'))}';
    }

    final response = await dio.post(
      urls.replaceUrl,
      data: payload,
      options: Options(
        headers: {'Content-Type': 'application/json', 'Authorization': authHeader},
      ),
    );

    if (response.statusCode == 200 && response.data is Map<String, dynamic>) {
      final responseData = response.data as Map<String, dynamic>;
      final data = responseData['data'] ?? responseData;
      final invoiceNo = data['invoiceNo'] ?? data['no'] ?? '';
      final templateCode = data['templateCode'] ?? data['form'] ?? '';
      final invoiceSerial = data['invoiceSerial'] ?? data['serial'] ?? '';
      final link = data['link'] ?? data['url'] ?? '';
      final invoiceInfo = <String, String>{
        'invoiceNo': invoiceNo,
        'templateCode': templateCode,
        'invoiceSerial': invoiceSerial,
        'link': link,
        'agreementDocument': agreementDocument ?? '',
        'customerAgreement': customerAgreement ?? '',
      };
      if (salesService != null && invoiceNo.isNotEmpty) {
        try {
          final updatedSale = replacementSale.copyWith(
            invoiceNo: invoiceNo,
            templateCode: templateCode,
            invoiceSerial: invoiceSerial,
            einvoiceUrl: link,
          );
          await salesService.updateSale(updatedSale);
          if (kDebugMode) debugPrint('✅ Replacement SaleModel updated with invoice info: ${updatedSale.id}');
        } catch (e) {
          if (kDebugMode) debugPrint('⚠️ Error updating replacement SaleModel: $e');
        }
      }
      return invoiceInfo;
    }
    throw Exception('Không thể phát hành hóa đơn thay thế');
  }

  @override
  Future<Map<String, String>?> checkInvoiceStatus({
    required SaleModel sale,
    required ShopModel shop,
    SalesService? salesService,
  }) async {
    // FPT thường trả về invoiceNo ngay khi tạo; không cần tra cứu trạng thái chờ CQT.
    return null;
  }

  @override
  Future<void> testConnection(ShopModel shop) async {
    final config = shop.einvoiceConfig;
    if (config == null) throw Exception('Chưa cấu hình HĐĐT.');
    final urls = await _getUrls();
    final token = await _getAccessToken(
      username: config.username,
      password: config.password,
      signinUrl: urls.signinUrl,
    );
    if (token == null) {
      throw Exception('Không lấy được token. Kiểm tra Username và Password.');
    }
  }
}
