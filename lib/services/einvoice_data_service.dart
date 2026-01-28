import '../models/sale_model.dart';
import '../models/shop_model.dart';

/// Service để chuẩn bị dữ liệu cho hóa đơn điện tử FPT
class EinvoiceDataService {
  /// Chuẩn bị payload JSON theo đặc tả FPT từ SaleModel và ShopModel
  static Map<String, dynamic> prepareFptPayload({
    required SaleModel sale,
    required ShopModel shop,
  }) {
    // Tính toán tổng tiền và thuế
    double sum = 0.0; // Tổng tiền chưa thuế
    double vat = 0.0; // Tổng tiền thuế

    // Chuyển đổi items
    final List<Map<String, dynamic>> itemsList = sale.items.map((item) {
      // Tính thành tiền chưa thuế
      final amount = item.price * item.quantity;
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

    // Tính total = sum + vat
    final total = sum + vat;

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

    return {
      'inv': invMap,
      'items': itemsList,
      'sum': sum.toStringAsFixed(2),
      'vat': vat.toStringAsFixed(2),
      'total': total.toStringAsFixed(2),
    };
  }
}

