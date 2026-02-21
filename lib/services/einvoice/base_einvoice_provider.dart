import 'package:dio/dio.dart';
import '../../models/sale_model.dart';
import '../../models/shop_model.dart';
import '../sales_service.dart';

/// Abstract base cho nhà cung cấp hóa đơn điện tử (FPT, Viettel, MISA...).
/// Mỗi provider triển khai logic riêng cho API của nhà cung cấp.
abstract class BaseEinvoiceProvider {
  BaseEinvoiceProvider(this.dio);
  final Dio dio;

  /// Phát hành hóa đơn điện tử.
  /// Trả về Map: invoiceNo, templateCode, invoiceSerial, link.
  Future<Map<String, String>> createInvoice({
    required SaleModel sale,
    required ShopModel shop,
    SalesService? salesService,
  });

  /// Lấy URL/link xem PDF hóa đơn (hoặc link tra cứu).
  Future<String> getInvoicePdfUrl(String saleId, ShopModel shop);

  /// Hủy hóa đơn điện tử.
  /// [invoiceIssueDateMs]: Ngày phát hành hóa đơn gốc (epoch ms). Viettel bắt buộc; FPT không dùng.
  Future<Map<String, dynamic>> annulInvoice({
    required String invoiceId,
    required String reason,
    required ShopModel shop,
    String? agreementDocument,
    String? customerAgreement,
    int? invoiceIssueDateMs,
  });

  /// Phát hành hóa đơn thay thế.
  Future<Map<String, String>> issueReplacementInvoice({
    required SaleModel originalSale,
    required SaleModel replacementSale,
    required ShopModel shop,
    required String reason,
    SalesService? salesService,
    String? agreementDocument,
    String? customerAgreement,
  });

  /// Kiểm tra trạng thái hóa đơn (VD: Viettel chờ CQT cấp mã). Cập nhật invoiceNo vào SaleModel nếu đã có.
  /// Trả về Map thông tin hóa đơn đã cập nhật (invoiceNo, templateCode, invoiceSerial, link) hoặc null nếu không hỗ trợ/không đổi.
  Future<Map<String, String>?> checkInvoiceStatus({
    required SaleModel sale,
    required ShopModel shop,
    SalesService? salesService,
  });

  /// Kiểm tra kết nối: gọi login/token để xác minh thông tin đăng nhập. Ném Exception nếu thất bại.
  Future<void> testConnection(ShopModel shop);
}
