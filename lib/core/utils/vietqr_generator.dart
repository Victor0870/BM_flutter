import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

/// Utility class để tạo chuỗi VietQR chuẩn EMVCo
/// Format theo chuẩn VietQR/Napas
class VietQRGenerator {
  /// Tạo chuỗi VietQR chuẩn EMVCo
  /// 
  /// [bankBin] - Mã BIN ngân hàng (6 chữ số, ví dụ: 970436)
  /// [accountNumber] - Số tài khoản ngân hàng
  /// [amount] - Số tiền cần chuyển (phải > 0)
  /// [description] - Nội dung chuyển khoản (thường là mã đơn hàng)
  static String generate({
    required String bankBin,
    required String accountNumber,
    required double amount,
    String? description,
  }) {
    return generateVietQR(
      bankBin: bankBin,
      accountNumber: accountNumber,
      amount: amount,
      description: description ?? '',
    );
  }

  /// Tạo chuỗi VietQR theo chuẩn Napas
  static String generateVietQR({
    required String bankBin, // Ví dụ: 970436 (Vietcombank)
    required String accountNumber,
    required double amount,
    required String description,
  }) {
    // Bước A: Tạo nội dung cho Tag 01 của Tag 38 trước
    // Tag 01 chứa thông tin tài khoản (bankBin + accountNumber)
    final normalizedBankBin = bankBin.padLeft(6, '0');
    String accountInfo = _formatTag("00", normalizedBankBin) + _formatTag("01", accountNumber);

    // Bước B: Tạo nội dung cho toàn bộ Tag 38
    // Tag 38 (Consumer Account Information):
    //   - Tag 00: A000000727 (GUID - Napas)
    //   - Tag 01: accountInfo (chứa bankBin và accountNumber)
    //   - Tag 02: QRIBFTTA (Service Code)
    String tag38Content = _formatTag("00", "A000000727") + 
                          _formatTag("01", accountInfo) + 
                          _formatTag("02", "QRIBFTTA");

    // Bước C: Tạo QR content với Tag 38 đã được format đúng
    String qrContent = "";
    qrContent += _formatTag("00", "01"); // Payload Format Indicator
    qrContent += _formatTag("01", "12"); // 11: Tĩnh, 12: Động (có số tiền)
    qrContent += _formatTag("38", tag38Content); // Consumer Account Information
    qrContent += _formatTag("53", "704"); // Transaction Currency (VND)
    
    // Đảm bảo amount là số nguyên
    final amountInt = amount.toInt();
    qrContent += _formatTag("54", amountInt.toString()); // Transaction Amount
    
    qrContent += _formatTag("58", "VN"); // Country Code
    
    // Tag 62: Additional Data Field Template
    if (description.isNotEmpty) {
      // Lọc bỏ dấu tiếng Việt và ký tự đặc biệt
      final sanitizedDescription = _sanitizeDescription(description);
      if (sanitizedDescription.isNotEmpty) {
        qrContent += _formatTag("62", _formatTag("08", sanitizedDescription)); // Lời nhắn
      }
    }

    // Bước D: Thêm Tag 63 (CRC) - Phải là tag cuối cùng
    qrContent += "6304"; 
    String crc = _generateCRC(qrContent);
    
    final finalQRString = qrContent + crc;
    
    if (kDebugMode) {
      debugPrint('🔍 VietQR Generation Debug:');
      debugPrint('  - Bank BIN: $bankBin (normalized: $normalizedBankBin)');
      debugPrint('  - Account: $accountNumber');
      debugPrint('  - Amount: $amount (int: $amountInt)');
      debugPrint('  - Description (original): $description');
      debugPrint('  - Description (sanitized): ${_sanitizeDescription(description)}');
      debugPrint('  - Account Info: $accountInfo');
      debugPrint('  - Tag 38 Content: $tag38Content');
      debugPrint('  - QR Content (before CRC): $qrContent');
      debugPrint('  - CRC: $crc');
      debugPrint('  - Final QR String: $finalQRString');
      debugPrint('  - QR String Length: ${finalQRString.length}');
    }
    
    return finalQRString;
  }

  /// Lọc bỏ dấu tiếng Việt và ký tự đặc biệt khỏi description
  /// Chỉ giữ lại chữ cái, số, khoảng trắng và một số ký tự cơ bản
  static String _sanitizeDescription(String description) {
    if (description.isEmpty) return '';
    
    // Bỏ dấu tiếng Việt
    String result = description
        .replaceAll('à', 'a')
        .replaceAll('á', 'a')
        .replaceAll('ạ', 'a')
        .replaceAll('ả', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ầ', 'a')
        .replaceAll('ấ', 'a')
        .replaceAll('ậ', 'a')
        .replaceAll('ẩ', 'a')
        .replaceAll('ẫ', 'a')
        .replaceAll('ă', 'a')
        .replaceAll('ằ', 'a')
        .replaceAll('ắ', 'a')
        .replaceAll('ặ', 'a')
        .replaceAll('ẳ', 'a')
        .replaceAll('ẵ', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ẹ', 'e')
        .replaceAll('ẻ', 'e')
        .replaceAll('ẽ', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ề', 'e')
        .replaceAll('ế', 'e')
        .replaceAll('ệ', 'e')
        .replaceAll('ể', 'e')
        .replaceAll('ễ', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('í', 'i')
        .replaceAll('ị', 'i')
        .replaceAll('ỉ', 'i')
        .replaceAll('ĩ', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ọ', 'o')
        .replaceAll('ỏ', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('ồ', 'o')
        .replaceAll('ố', 'o')
        .replaceAll('ộ', 'o')
        .replaceAll('ổ', 'o')
        .replaceAll('ỗ', 'o')
        .replaceAll('ơ', 'o')
        .replaceAll('ờ', 'o')
        .replaceAll('ớ', 'o')
        .replaceAll('ợ', 'o')
        .replaceAll('ở', 'o')
        .replaceAll('ỡ', 'o')
        .replaceAll('ù', 'u')
        .replaceAll('ú', 'u')
        .replaceAll('ụ', 'u')
        .replaceAll('ủ', 'u')
        .replaceAll('ũ', 'u')
        .replaceAll('ư', 'u')
        .replaceAll('ừ', 'u')
        .replaceAll('ứ', 'u')
        .replaceAll('ự', 'u')
        .replaceAll('ử', 'u')
        .replaceAll('ữ', 'u')
        .replaceAll('ỳ', 'y')
        .replaceAll('ý', 'y')
        .replaceAll('ỵ', 'y')
        .replaceAll('ỷ', 'y')
        .replaceAll('ỹ', 'y')
        .replaceAll('đ', 'd')
        .replaceAll('À', 'A')
        .replaceAll('Á', 'A')
        .replaceAll('Ạ', 'A')
        .replaceAll('Ả', 'A')
        .replaceAll('Ã', 'A')
        .replaceAll('Â', 'A')
        .replaceAll('Ầ', 'A')
        .replaceAll('Ấ', 'A')
        .replaceAll('Ậ', 'A')
        .replaceAll('Ẩ', 'A')
        .replaceAll('Ẫ', 'A')
        .replaceAll('Ă', 'A')
        .replaceAll('Ằ', 'A')
        .replaceAll('Ắ', 'A')
        .replaceAll('Ặ', 'A')
        .replaceAll('Ẳ', 'A')
        .replaceAll('Ẵ', 'A')
        .replaceAll('È', 'E')
        .replaceAll('É', 'E')
        .replaceAll('Ẹ', 'E')
        .replaceAll('Ẻ', 'E')
        .replaceAll('Ẽ', 'E')
        .replaceAll('Ê', 'E')
        .replaceAll('Ề', 'E')
        .replaceAll('Ế', 'E')
        .replaceAll('Ệ', 'E')
        .replaceAll('Ể', 'E')
        .replaceAll('Ễ', 'E')
        .replaceAll('Ì', 'I')
        .replaceAll('Í', 'I')
        .replaceAll('Ị', 'I')
        .replaceAll('Ỉ', 'I')
        .replaceAll('Ĩ', 'I')
        .replaceAll('Ò', 'O')
        .replaceAll('Ó', 'O')
        .replaceAll('Ọ', 'O')
        .replaceAll('Ỏ', 'O')
        .replaceAll('Õ', 'O')
        .replaceAll('Ô', 'O')
        .replaceAll('Ồ', 'O')
        .replaceAll('Ố', 'O')
        .replaceAll('Ộ', 'O')
        .replaceAll('Ổ', 'O')
        .replaceAll('Ỗ', 'O')
        .replaceAll('Ơ', 'O')
        .replaceAll('Ờ', 'O')
        .replaceAll('Ớ', 'O')
        .replaceAll('Ợ', 'O')
        .replaceAll('Ở', 'O')
        .replaceAll('Ỡ', 'O')
        .replaceAll('Ù', 'U')
        .replaceAll('Ú', 'U')
        .replaceAll('Ụ', 'U')
        .replaceAll('Ủ', 'U')
        .replaceAll('Ũ', 'U')
        .replaceAll('Ư', 'U')
        .replaceAll('Ừ', 'U')
        .replaceAll('Ứ', 'U')
        .replaceAll('Ự', 'U')
        .replaceAll('Ử', 'U')
        .replaceAll('Ữ', 'U')
        .replaceAll('Ỳ', 'Y')
        .replaceAll('Ý', 'Y')
        .replaceAll('Ỵ', 'Y')
        .replaceAll('Ỷ', 'Y')
        .replaceAll('Ỹ', 'Y')
        .replaceAll('Đ', 'D');
    
    // Chỉ giữ lại chữ cái, số, khoảng trắng, và một số ký tự cơ bản
    result = result.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-_/]'), '');
    
    // Loại bỏ khoảng trắng thừa
    result = result.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    // Giới hạn độ dài tối đa (QR code có giới hạn)
    if (result.length > 25) {
      result = result.substring(0, 25);
    }
    
    return result;
  }

  /// Hàm tính toán mã CRC16 chuẩn EMVCo
  static String _generateCRC(String data) {
    int crc = 0xFFFF;
    for (int i = 0; i < data.length; i++) {
      crc ^= (data.codeUnitAt(i) << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = (crc << 1) ^ 0x1021;
        } else {
          crc <<= 1;
        }
      }
    }
    return (crc & 0xFFFF).toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  /// Hàm định dạng Tag theo quy tắc: ID(2) + Length(2) + Value
  static String _formatTag(String id, String value) {
    return id.padLeft(2, '0') + value.length.toString().padLeft(2, '0') + value;
  }
}