import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import '../models/shop_model.dart';
import '../core/utils/vietqr_generator.dart';
import 'dart:math';

  /// Service để xử lý thanh toán qua PayOS hoặc Casso
class PaymentService {
  final PaymentConfig config;

  PaymentService({required this.config});

  /// Tạo đơn hàng PayOS và nhận paymentLinkId
  /// Trả về paymentLinkId nếu thành công, null nếu thất bại
  Future<String?> createPayOSOrder({
    required double amount,
    required String orderId,
    String? description,
  }) async {
    if (config.provider != PaymentProvider.payos || !config.isConfigured) {
      if (kDebugMode) {
        debugPrint('❌ PayOS not configured');
      }
      return null;
    }

    if (config.payosClientId == null || 
        config.payosApiKey == null || 
        config.payosChecksumKey == null) {
      if (kDebugMode) {
        debugPrint('❌ PayOS credentials missing');
      }
      return null;
    }

    try {
      final dio = Dio();
      final orderCode = _generateOrderCode();

      // Tạo payment data theo PayOS API
      final paymentData = {
        'orderCode': orderCode,
        'amount': amount.toInt(),
        'description': description ?? 'Thanh toan don hang $orderId',
        'cancelUrl': 'https://bizmate.vn/cancel',
        'returnUrl': 'https://bizmate.vn/return',
      };

      // Tính checksum (PayOS yêu cầu sắp xếp key theo alphabet)
      final sortedKeys = paymentData.keys.toList()..sort();
      final sortedData = <String, dynamic>{};
      for (var key in sortedKeys) {
        sortedData[key] = paymentData[key];
      }
      final dataString = jsonEncode(sortedData);
      final checksum = _calculatePayOSChecksum(dataString, config.payosChecksumKey!);

      final response = await dio.post(
        'https://api.payos.vn/v2/payment-requests',
        data: {
          ...sortedData,
        },
        options: Options(
          headers: {
            'x-client-id': config.payosClientId!,
            'x-api-key': config.payosApiKey!,
            'x-checksum': checksum,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == '00') {
          final paymentLinkId = data['data']['id']?.toString();
          if (kDebugMode) {
            debugPrint('✅ PayOS order created, paymentLinkId: $paymentLinkId');
          }
          return paymentLinkId;
        } else {
          if (kDebugMode) {
            debugPrint('❌ PayOS API error: ${data['desc']}');
          }
          return null;
        }
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PayOS createOrder error: $e');
      }
      return null;
    }
  }

  /// Tạo mã QR VietQR theo chuẩn Vietnam QR Code
  /// Format EMVCo hoặc PayOS API
  /// Trả về QR code data string
  Future<String?> createPaymentQR({
    required double amount,
    required String orderId,
    String? description,
  }) async {
    try {
      // Ưu tiên PayOS nếu đã cấu hình đầy đủ
      if (config.provider == PaymentProvider.payos && config.isConfigured) {
        return await _createPayOSPayment(amount: amount, orderId: orderId, description: description);
      } 
      
      // Nếu có Casso config
      if (config.provider == PaymentProvider.casso && config.isConfigured) {
        return await _createCassoPayment(amount: amount, orderId: orderId, description: description);
      }
      
      // Tạo VietQR đơn giản từ thông tin ngân hàng (nếu có)
      // Không cần isConfigured, chỉ cần có bankBin và bankAccountNumber
      if (config.bankBin != null && 
          config.bankBin!.isNotEmpty &&
          config.bankAccountNumber != null && 
          config.bankAccountNumber!.isNotEmpty) {
        return _createVietQR(amount: amount, content: description ?? orderId);
      }
      
      // Không có thông tin nào
      if (kDebugMode) {
        debugPrint('❌ Payment config not configured - missing bank info or PayOS config');
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error creating payment QR: $e');
      }
      return null;
    }
  }

  /// Tạo VietQR đơn giản (không qua PayOS/Casso API) - Sử dụng chuẩn EMVCo
  String _createVietQR({
    required double amount,
    required String content,
  }) {
    if (config.bankBin == null || 
        config.bankAccountNumber == null || 
        config.bankAccountNumber!.isEmpty) {
      return '';
    }

    // Sử dụng VietQRGenerator để tạo chuỗi EMVCo chuẩn
    final qrString = VietQRGenerator.generate(
      bankBin: config.bankBin!,
      accountNumber: config.bankAccountNumber!,
      amount: amount,
      description: content,
    );

    if (kDebugMode) {
      debugPrint('✅ Generated VietQR string (EMVCo format): $qrString');
    }

    return qrString;
  }

  /// Tạo payment link qua PayOS API
  Future<String?> _createPayOSPayment({
    required double amount,
    required String orderId,
    String? description,
  }) async {
    if (config.payosClientId == null || 
        config.payosApiKey == null || 
        config.payosChecksumKey == null) {
      return null;
    }

    try {
      final dio = Dio();
      final orderCode = _generateOrderCode();

      // Tạo payment data theo PayOS API
      final paymentData = {
        'orderCode': orderCode,
        'amount': amount.toInt(),
        'description': description ?? 'Thanh toan don hang $orderId',
        'cancelUrl': 'https://bizmate.vn/cancel',
        'returnUrl': 'https://bizmate.vn/return',
      };

      // Tính checksum
      final dataString = jsonEncode(paymentData);
      final checksum = _calculatePayOSChecksum(dataString, config.payosChecksumKey!);

      final response = await dio.post(
        'https://api.payos.vn/v2/payment-requests',
        data: {
          ...paymentData,
          'signature': checksum,
        },
        options: Options(
          headers: {
            'x-client-id': config.payosClientId!,
            'x-api-key': config.payosApiKey!,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == '00') {
          final responseData = data['data'];
          // PayOS có thể trả về qrCode (string) hoặc checkoutUrl
          final qrCode = responseData['qrCode'] ?? responseData['checkoutUrl'];
          if (qrCode != null && qrCode is String) {
            if (kDebugMode) {
              debugPrint('✅ PayOS QR code received');
            }
            return qrCode;
          }
        }
      }

      // Nếu PayOS không trả về QR code, fallback về VietQR
      if (kDebugMode) {
        debugPrint('⚠️ PayOS không trả về QR code, fallback về VietQR');
      }
      return _createVietQR(amount: amount, content: description ?? orderId);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PayOS API error: $e');
      }
      // Fallback về VietQR đơn giản
      return _createVietQR(amount: amount, content: description ?? orderId);
    }
  }

  /// Tạo payment qua Casso API (nếu cần)
  Future<String?> _createCassoPayment({
    required double amount,
    required String orderId,
    String? description,
  }) async {
    // Casso thường sử dụng webhook để xác nhận, không tạo QR trực tiếp
    // Tạo VietQR đơn giản với thông tin ngân hàng
    return _createVietQR(amount: amount, content: description ?? orderId);
  }

  /// Kiểm tra trạng thái thanh toán (polling)
  /// PayOS: Kiểm tra qua API
  /// Casso: Kiểm tra qua webhook (sẽ được handle riêng)
  Future<bool> checkPaymentStatus(String orderId) async {
    if (!config.isConfigured || config.provider == PaymentProvider.none) {
      return false;
    }

    try {
      if (config.provider == PaymentProvider.payos) {
        return await _checkPayOSStatus(orderId);
      }
      // Casso thường dùng webhook, không polling
      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error checking payment status: $e');
      }
      return false;
    }
  }

  /// Kiểm tra trạng thái thanh toán qua PayOS API
  /// [paymentLinkId] - ID trả về từ createPayOSOrder
  Future<bool> _checkPayOSStatus(String paymentLinkId) async {
    if (config.payosClientId == null || config.payosApiKey == null) {
      return false;
    }

    try {
      final dio = Dio();
      final response = await dio.get(
        'https://api.payos.vn/v2/payment-requests/$paymentLinkId',
        options: Options(
          headers: {
            'x-client-id': config.payosClientId!,
            'x-api-key': config.payosApiKey!,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['code'] == '00') {
          final status = data['data']['status'];
          // PayOS status: PAID, CANCELLED, PENDING
          if (kDebugMode) {
            debugPrint('📊 PayOS payment status: $status');
          }
          return status == 'PAID';
        }
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ PayOS status check error: $e');
      }
      return false;
    }
  }

  /// Tính checksum cho PayOS
  String _calculatePayOSChecksum(String data, String key) {
    // PayOS sử dụng HMAC SHA256
    final hmac = Hmac(sha256, utf8.encode(key));
    final digest = hmac.convert(utf8.encode(data));
    return digest.toString();
  }

  /// Tạo order code ngẫu nhiên cho PayOS
  int _generateOrderCode() {
    final random = Random();
    // PayOS orderCode phải là số 6-8 chữ số
    return 100000 + random.nextInt(900000); // 6 chữ số
  }
}

