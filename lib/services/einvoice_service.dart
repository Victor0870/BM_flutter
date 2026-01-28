import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:dio/dio.dart';
import '../models/sale_model.dart';
import '../models/shop_model.dart';
import '../services/sales_service.dart';
import 'einvoice_data_service.dart';

/// Service để gửi yêu cầu tạo hóa đơn điện tử đến FPT
/// Theo tài liệu API của FPT eInvoice: API cua FPT.pdf
class EinvoiceService {
  final Dio _dio;

  EinvoiceService() : _dio = Dio();

  /// Lấy access token từ FPT API
  /// API: https://api-uat.einvoice.fpt.com.vn/c_signin (hoặc production URL)
  Future<String?> _getAccessToken({
    required String username,
    required String password,
    required String baseUrl,
  }) async {
    try {
      // Xác định URL signin (từ baseUrl)
      final signinUrl = baseUrl.replaceAll('/api/invoice', '/c_signin');
      
      final response = await _dio.post(
        signinUrl,
        data: {
          'username': username,
          'password': password,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic>) {
          return responseData['access_token'] ?? responseData['data']?['access_token'];
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting access token: $e');
      }
      return null;
    }
  }

  /// Gửi yêu cầu tạo/phát hành hóa đơn điện tử
  /// Trả về Map chứa thông tin hóa đơn: {invoiceNo, templateCode, invoiceSerial, link}
  /// Throw exception nếu có lỗi
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

    final config = shop.einvoiceConfig!;

    try {
      // Chuẩn bị payload
      final payload = EinvoiceDataService.prepareFptPayload(
        sale: sale,
        shop: shop,
      );

      if (kDebugMode) {
        debugPrint('📋 FPT Invoice Payload: ${jsonEncode(payload)}');
      }

      // Lấy access token nếu có (Bearer Token method)
      String? accessToken;
      String? authHeader;
      
      // Thử dùng Bearer Token trước
      if (config.username.isNotEmpty && config.password.isNotEmpty) {
        accessToken = await _getAccessToken(
          username: config.username,
          password: config.password,
          baseUrl: config.baseUrl,
        );
        
        if (accessToken != null) {
          authHeader = 'Bearer $accessToken';
        }
      }
      
      // Nếu không có token, dùng Basic Auth
      if (authHeader == null) {
        final credentials = base64Encode(
          utf8.encode('${config.username}:${config.password}'),
        );
        authHeader = 'Basic $credentials';
      }

      // Gửi request
      final response = await _dio.post(
        config.baseUrl,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': authHeader,
          },
          validateStatus: (status) => status! < 500, // Cho phép 400 để xử lý lỗi nghiệp vụ
        ),
      );

      if (kDebugMode) {
        debugPrint('📡 FPT Response Status: ${response.statusCode}');
        debugPrint('📡 FPT Response Data: ${response.data}');
      }

      // Xử lý response
      if (response.statusCode == 200) {
        // Thành công
        final responseData = response.data;
        if (responseData is Map<String, dynamic>) {
          // Lấy thông tin hóa đơn từ response
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
          
          // Cập nhật SaleModel với thông tin hóa đơn
          if (salesService != null && invoiceInfo.isNotEmpty) {
            try {
              final updatedSale = sale.copyWith(
                invoiceNo: invoiceInfo['invoiceNo'],
                templateCode: invoiceInfo['templateCode'],
                invoiceSerial: invoiceInfo['invoiceSerial'],
                einvoiceUrl: invoiceInfo['link'],
              );
              await salesService.updateSale(updatedSale);
              
              if (kDebugMode) {
                debugPrint('✅ SaleModel updated with invoice info: ${updatedSale.id}');
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('⚠️ Error updating SaleModel with invoice info: $e');
              }
              // Không throw lỗi này vì hóa đơn đã được tạo thành công
            }
          }
          
          return invoiceInfo;
        }
        return {'message': 'Tạo hóa đơn thành công'};
      } else if (response.statusCode == 400) {
        // Lỗi nghiệp vụ
        final responseData = response.data;
        String errorMessage = 'Có lỗi khi tạo hóa đơn';
        
        if (responseData is Map<String, dynamic>) {
          errorMessage = responseData['message'] ?? 
                        responseData['error'] ?? 
                        responseData['errors']?.toString() ?? 
                        errorMessage;
        } else if (responseData is String) {
          errorMessage = responseData;
        }

        throw Exception(errorMessage);
      } else {
        // Lỗi khác
        throw Exception('Lỗi kết nối đến hệ thống hóa đơn điện tử: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('❌ DioException: ${e.message}');
        debugPrint('❌ Response: ${e.response?.data}');
      }

      if (e.response != null) {
        final responseData = e.response!.data;
        String errorMessage = 'Có lỗi khi tạo hóa đơn';

        if (responseData is Map<String, dynamic>) {
          errorMessage = responseData['message'] ?? 
                        responseData['error'] ?? 
                        responseData['errors']?.toString() ?? 
                        errorMessage;
        } else if (responseData is String) {
          errorMessage = responseData;
        }

        throw Exception(errorMessage);
      } else {
        throw Exception('Không thể kết nối đến hệ thống hóa đơn điện tử: ${e.message}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating invoice: $e');
      }
      rethrow;
    }
  }

  /// Lấy link PDF hóa đơn điện tử
  /// API: Tra cứu thông tin/lấy file hóa đơn
  Future<String> getInvoicePdfUrl(String saleId, ShopModel shop) async {
    if (shop.einvoiceConfig == null) {
      throw Exception('Chưa cấu hình thông tin hóa đơn điện tử');
    }

    final config = shop.einvoiceConfig!;

    try {
      // Lấy access token
      String? accessToken;
      String? authHeader;
      
      if (config.username.isNotEmpty && config.password.isNotEmpty) {
        accessToken = await _getAccessToken(
          username: config.username,
          password: config.password,
          baseUrl: config.baseUrl,
        );
        
        if (accessToken != null) {
          authHeader = 'Bearer $accessToken';
        }
      }
      
      if (authHeader == null) {
        final credentials = base64Encode(
          utf8.encode('${config.username}:${config.password}'),
        );
        authHeader = 'Basic $credentials';
      }

      // Gọi API tra cứu hóa đơn
      // URL: {baseUrl}/tra-cuu hoặc tương tự
      final lookupUrl = config.baseUrl.replaceAll('/api/invoice', '/api/invoice/lookup');
      
      final response = await _dio.get(
        '$lookupUrl/$saleId',
        options: Options(
          headers: {
            'Authorization': authHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic>) {
          final data = responseData['data'] ?? responseData;
          return data['pdfUrl'] ?? data['link'] ?? data['url'] ?? '';
        }
      }

      throw Exception('Không tìm thấy hóa đơn');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting invoice PDF URL: $e');
      }
      rethrow;
    }
  }

  /// Hủy hóa đơn điện tử
  /// Lưu vết biên bản thỏa thuận giữa hai bên
  Future<Map<String, dynamic>> annulInvoice({
    required String invoiceId,
    required String reason,
    required ShopModel shop,
    String? agreementDocument, // Biên bản thỏa thuận (có thể là text hoặc file path)
    String? customerAgreement, // Xác nhận của khách hàng
  }) async {
    if (shop.einvoiceConfig == null) {
      throw Exception('Chưa cấu hình thông tin hóa đơn điện tử');
    }

    final config = shop.einvoiceConfig!;

    try {
      // Lấy access token
      String? accessToken;
      String? authHeader;
      
      if (config.username.isNotEmpty && config.password.isNotEmpty) {
        accessToken = await _getAccessToken(
          username: config.username,
          password: config.password,
          baseUrl: config.baseUrl,
        );
        
        if (accessToken != null) {
          authHeader = 'Bearer $accessToken';
        }
      }
      
      if (authHeader == null) {
        final credentials = base64Encode(
          utf8.encode('${config.username}:${config.password}'),
        );
        authHeader = 'Basic $credentials';
      }

      // Chuẩn bị payload hủy hóa đơn
      final payload = {
        'invoiceId': invoiceId,
        'reason': reason,
        'agreementDocument': agreementDocument ?? '',
        'customerAgreement': customerAgreement ?? '',
        'annulDate': DateTime.now().toIso8601String(),
      };

      // Gọi API hủy hóa đơn
      final annulUrl = config.baseUrl.replaceAll('/api/invoice', '/api/invoice/annul');
      
      final response = await _dio.post(
        annulUrl,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': authHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        return {
          'success': true,
          'data': responseData,
          'agreementDocument': agreementDocument,
          'customerAgreement': customerAgreement,
        };
      }

      throw Exception('Không thể hủy hóa đơn');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error annulling invoice: $e');
      }
      rethrow;
    }
  }

  /// Phát hành hóa đơn thay thế
  /// Lưu vết biên bản thỏa thuận giữa hai bên
  Future<Map<String, String>> issueReplacementInvoice({
    required SaleModel originalSale,
    required SaleModel replacementSale,
    required ShopModel shop,
    required String reason,
    SalesService? salesService,
    String? agreementDocument, // Biên bản thỏa thuận
    String? customerAgreement, // Xác nhận của khách hàng
  }) async {
    if (shop.einvoiceConfig == null) {
      throw Exception('Chưa cấu hình thông tin hóa đơn điện tử');
    }

    final config = shop.einvoiceConfig!;

    try {
      // Chuẩn bị payload hóa đơn thay thế
      final payload = EinvoiceDataService.prepareFptPayload(
        sale: replacementSale,
        shop: shop,
      );

      // Thêm thông tin hóa đơn gốc và lý do thay thế
      payload['originalInvoiceId'] = originalSale.invoiceNo ?? originalSale.id;
      payload['replacementReason'] = reason;
      payload['agreementDocument'] = agreementDocument ?? '';
      payload['customerAgreement'] = customerAgreement ?? '';

      if (kDebugMode) {
        debugPrint('📋 FPT Replacement Invoice Payload: ${jsonEncode(payload)}');
      }

      // Lấy access token
      String? accessToken;
      String? authHeader;
      
      if (config.username.isNotEmpty && config.password.isNotEmpty) {
        accessToken = await _getAccessToken(
          username: config.username,
          password: config.password,
          baseUrl: config.baseUrl,
        );
        
        if (accessToken != null) {
          authHeader = 'Bearer $accessToken';
        }
      }
      
      if (authHeader == null) {
        final credentials = base64Encode(
          utf8.encode('${config.username}:${config.password}'),
        );
        authHeader = 'Basic $credentials';
      }

      // Gọi API phát hành hóa đơn thay thế
      final replacementUrl = config.baseUrl.replaceAll('/api/invoice', '/api/invoice/replacement');
      
      final response = await _dio.post(
        replacementUrl,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': authHeader,
          },
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic>) {
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
          
          // Cập nhật SaleModel thay thế với thông tin hóa đơn
          if (salesService != null && invoiceNo.isNotEmpty) {
            try {
              final updatedSale = replacementSale.copyWith(
                invoiceNo: invoiceNo,
                templateCode: templateCode,
                invoiceSerial: invoiceSerial,
                einvoiceUrl: link,
              );
              await salesService.updateSale(updatedSale);
              
              if (kDebugMode) {
                debugPrint('✅ Replacement SaleModel updated with invoice info: ${updatedSale.id}');
              }
            } catch (e) {
              if (kDebugMode) {
                debugPrint('⚠️ Error updating replacement SaleModel: $e');
              }
            }
          }
          
          return invoiceInfo;
        }
      }

      throw Exception('Không thể phát hành hóa đơn thay thế');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error issuing replacement invoice: $e');
      }
      rethrow;
    }
  }

  /// Phát hành hàng loạt hóa đơn điện tử
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
