import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:dio/dio.dart';
import '../../models/sale_model.dart';
import '../../models/shop_model.dart';
import '../sales_service.dart';
import '../einvoice_data_service.dart';
import '../einvoice_urls.dart';
import 'base_einvoice_provider.dart';

/// Provider hóa đơn điện tử FPT (API NĐ70/2025).
/// Ưu tiên dùng Base URL đã cấu hình trong Cài đặt shop (link chính thức Production hoặc UAT tùy user).
class FptInvoiceProvider extends BaseEinvoiceProvider {
  FptInvoiceProvider(super.dio);

  /// Lấy URL: nếu shop đã cấu hình baseUrl (FPT) thì dùng link đó; không thì mặc định Production (hóa đơn thật).
  Future<EinvoiceUrls> _getUrls(ShopModel shop) async {
    final config = shop.einvoiceConfig;
    final baseUrl = (config?.baseUrl ?? '').trim();
    if (baseUrl.isNotEmpty && baseUrl.contains('einvoice.fpt.com.vn')) {
      return EinvoiceUrls.fromBaseUrl(baseUrl);
    }
    // Không cấu hình Base URL → mặc định Production để tài khoản thật xuất HĐĐT thật
    return EinvoiceUrls(isTest: false);
  }

  /// Gọi API đăng nhập FPT (c_signin). FPT có thể trả về JWT thô (chuỗi) hoặc JSON có access_token.
  /// Thử body: username/password, nếu 401 thì thử userName/passWord (camelCase).
  Future<String?> _getAccessToken({
    required String username,
    required String password,
    required String signinUrl,
  }) async {
    Future<String?> tryLogin(Map<String, String> body) async {
      final res = await dio.post<String>(
        signinUrl,
        data: body,
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status != null && status < 500,
          responseType: ResponseType.plain,
        ),
      );
      if (res.statusCode != 200 || res.data == null) return null;
      final responseText = res.data!.toString().trim();
      if (responseText.isEmpty) return null;
      // FPT có thể trả JWT thô (chuỗi có 3 phần cách nhau bởi dấu chấm)
      if (responseText.split('.').length == 3) {
        return responseText;
      }
      // Nếu trả về JSON (object hoặc string bọc trong JSON)
      try {
        final decoded = jsonDecode(responseText);
        if (decoded is String) return decoded;
        if (decoded is Map<String, dynamic>) {
          final t = decoded['access_token'] ?? decoded['data']?['access_token'];
          return t == null ? null : t.toString();
        }
      } catch (_) {}
      return null;
    }

    try {
      var token = await tryLogin({'username': username, 'password': password});
      if (token != null) return token;
      token = await tryLogin({'userName': username, 'passWord': password});
      if (token != null) return token;
      if (kDebugMode) debugPrint('❌ FPT get access token: 401 hoặc response không phải JWT/JSON');
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ FPT get access token: $e');
      return null;
    }
  }

  /// Lấy Authorization Bearer; không dùng Basic Auth fallback (FPT chỉ chấp nhận JWT).
  Future<String> _getAuthHeader(ShopModel shop) async {
    final config = shop.einvoiceConfig!;
    if (config.username.isEmpty || config.password.isEmpty) {
      throw Exception('Chưa cấu hình Username và Password cho HĐĐT FPT.');
    }
    final urls = await _getUrls(shop);
    final token = await _getAccessToken(
      username: config.username,
      password: config.password,
      signinUrl: urls.signinUrl,
    );
    if (token == null) {
      throw Exception(
        'Không lấy được token. Kiểm tra Username và Password. '
        'Với FPT: thử dùng Mã số thuế (MST) làm Username thay vì email đăng nhập web.'
      );
    }
    return 'Bearer $token';
  }

  @override
  Future<Map<String, String>> createInvoice({
    required SaleModel sale,
    required ShopModel shop,
    SalesService? salesService,
  }) async {
    final urls = await _getUrls(shop);
    final payload = EinvoiceDataService.prepareFptPayload(sale: sale, shop: shop);

    if (kDebugMode) debugPrint('📋 FPT Invoice Payload: ${jsonEncode(payload)}');

    final authHeader = await _getAuthHeader(shop);

    final response = await dio.post(
      urls.createUrl,
      data: payload,
      options: Options(
        headers: {'Content-Type': 'application/json', 'Authorization': authHeader},
        validateStatus: (status) => status != null && status < 600,
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
        final inner = (data is Map<String, dynamic>) ? (data['result'] ?? data['data'] ?? data) : data;
        final map = (inner is Map<String, dynamic>) ? inner : <String, dynamic>{};
        // FPT có thể trả số hóa đơn/link với nhiều tên khác nhau
        String _str(dynamic v) {
          if (v == null) return '';
          if (v is String) return v.trim();
          return v.toString().trim();
        }
        final invoiceNo = _str(map['invoiceNo'] ?? map['no'] ?? map['seq'] ?? map['soHoaDon'] ?? map['invoiceNumber']);
        final templateCode = _str(map['templateCode'] ?? map['form'] ?? map['mauSo']);
        final invoiceSerial = _str(map['invoiceSerial'] ?? map['serial'] ?? map['kyHieu']);
        final link = _str(map['link'] ?? map['url'] ?? map['viewLink'] ?? map['pdfUrl'] ?? map['traCuuUrl'] ?? map['searchLink']);

        final invoiceInfo = <String, String>{};
        if (invoiceNo.isNotEmpty) invoiceInfo['invoiceNo'] = invoiceNo;
        if (templateCode.isNotEmpty) invoiceInfo['templateCode'] = templateCode;
        if (invoiceSerial.isNotEmpty) invoiceInfo['invoiceSerial'] = invoiceSerial;
        if (link.isNotEmpty) invoiceInfo['link'] = link;

        if (salesService != null && (invoiceInfo['invoiceNo'] != null || invoiceInfo['link'] != null)) {
          try {
            if (shop.deductStockOnEinvoiceOnly && !sale.isStockUpdated) {
              await salesService.deductStockForSale(sale);
              if (kDebugMode) debugPrint('📦 Stock deducted on e-invoice issue for sale: ${sale.id}');
            }
            final updatedSale = sale.copyWith(
              invoiceNo: invoiceInfo['invoiceNo'] ?? sale.invoiceNo,
              templateCode: invoiceInfo['templateCode'] ?? sale.templateCode,
              invoiceSerial: invoiceInfo['invoiceSerial'] ?? sale.invoiceSerial,
              einvoiceUrl: invoiceInfo['link'] ?? sale.einvoiceUrl,
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
    if (response.statusCode == 401) {
      throw Exception(
        'Lỗi 401 - Xác thực thất bại. Kiểm tra Username và Password trong Cài đặt > Hóa đơn điện tử. '
        'Với FPT: Username thường là Mã số thuế (MST) của doanh nghiệp hoặc tên đăng nhập do FPT cấp—nếu bạn đăng nhập web bằng email, hãy thử dùng MST. '
        'Nếu dùng UAT/Test, đảm bảo tài khoản và Base URL đúng môi trường.'
      );
    }
    if (response.statusCode != null && response.statusCode! >= 500) {
      String message = 'Máy chủ hóa đơn điện tử FPT đang gặp sự cố (lỗi ${response.statusCode}). Vui lòng thử lại sau hoặc liên hệ FPT eInvoice.';
      final responseData = response.data;
      if (responseData is Map<String, dynamic>) {
        final detail = responseData['message'] ?? responseData['error'] ?? responseData['errors']?.toString();
        if (detail != null && detail.toString().isNotEmpty) {
          message = '$message Chi tiết: $detail';
        }
      } else if (responseData is String && responseData.isNotEmpty) {
        message = '$message Chi tiết: $responseData';
      }
      throw Exception(message);
    }
    throw Exception('Lỗi kết nối đến hệ thống hóa đơn điện tử: ${response.statusCode}');
  }

  /// Tạo hóa đơn nháp (Chờ phát hành): không cấp số, không ghi Sale. Có thể xóa trên portal FPT hoặc qua API delete-icr.
  Future<Map<String, String>> createDraftInvoice({
    required SaleModel sale,
    required ShopModel shop,
  }) async {
    final urls = await _getUrls(shop);
    final payload = EinvoiceDataService.prepareFptPayload(sale: sale, shop: shop, isDraft: true);
    if (kDebugMode) debugPrint('📋 FPT Draft Payload (no aun): ${jsonEncode(payload)}');
    final authHeader = await _getAuthHeader(shop);
    final response = await dio.post(
      urls.createUrl,
      data: payload,
      options: Options(
        headers: {'Content-Type': 'application/json', 'Authorization': authHeader},
        validateStatus: (status) => status != null && status < 600,
      ),
    );
    if (kDebugMode) {
      debugPrint('📡 FPT Draft Response: ${response.statusCode} ${response.data}');
    }
    if (response.statusCode == 200) {
      return {
        'message': 'Đã tạo hóa đơn nháp (Chờ phát hành). Bạn có thể xóa trên portal FPT hoặc dùng API xóa nếu cần.',
      };
    }
    if (response.statusCode == 400) {
      final d = response.data;
      String msg = 'Có lỗi khi tạo hóa đơn nháp';
      if (d is Map<String, dynamic>) msg = d['message'] ?? d['error'] ?? msg;
      if (d is String && d.isNotEmpty) msg = d;
      throw Exception(msg);
    }
    if (response.statusCode == 401) {
      throw Exception(
        'Lỗi 401 - Xác thực thất bại. Kiểm tra Username và Password trong Cài đặt > Hóa đơn điện tử.'
      );
    }
    if (response.statusCode != null && response.statusCode! >= 500) {
      String message = 'Máy chủ FPT đang gặp sự cố (lỗi ${response.statusCode}). Vui lòng thử lại sau.';
      final d = response.data;
      if (d is Map<String, dynamic>) {
        final detail = d['message'] ?? d['error'] ?? d['errors']?.toString();
        if (detail != null && detail.toString().isNotEmpty) message = '$message Chi tiết: $detail';
      } else if (d is String && d.isNotEmpty) message = '$message Chi tiết: $d';
      throw Exception(message);
    }
    throw Exception('Lỗi kết nối: ${response.statusCode}');
  }

  @override
  Future<String> getInvoicePdfUrl(String saleId, ShopModel shop) async {
    final urls = await _getUrls(shop);
    final authHeader = await _getAuthHeader(shop);

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
    final urls = await _getUrls(shop);
    final authHeader = await _getAuthHeader(shop);

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
    final urls = await _getUrls(shop);
    final authHeader = await _getAuthHeader(shop);

    final payload = EinvoiceDataService.prepareFptPayload(sale: replacementSale, shop: shop);
    payload['originalInvoiceId'] = originalSale.invoiceNo ?? originalSale.id;
    payload['replacementReason'] = reason;
    payload['agreementDocument'] = agreementDocument ?? '';
    payload['customerAgreement'] = customerAgreement ?? '';

    if (kDebugMode) debugPrint('📋 FPT Replacement Invoice Payload: ${jsonEncode(payload)}');

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
    await _getAuthHeader(shop);
  }
}
