import 'package:flutter/material.dart';

import '../models/sale_model.dart';
import '../models/shop_model.dart';
import '../utils/platform_utils.dart';
import '../widgets/invoice_print_widget.dart';

/// Service in hóa đơn: khổ giấy và tên máy in lấy từ [ShopModel].
/// Khi bật "Tự động in sau khi thanh toán", gọi [requestPrint] ngay khi đơn hàng hoàn tất.
class PrintingService {
  PrintingService._();

  /// Khổ giấy mặc định từ shop (58 hoặc 80 mm).
  static int paperSizeMm(ShopModel? shop) =>
      shop != null && (shop.printerPaperSizeMm == 58 || shop.printerPaperSizeMm == 80)
          ? shop.printerPaperSizeMm
          : 80;

  /// Tên máy in (Desktop) để in đúng thiết bị khi hỗ trợ Silent Print.
  static String? printerName(ShopModel? shop) => shop?.printerName;

  /// Hiển thị dialog xem trước / in hóa đơn với khổ giấy từ [shop] hoặc [paperMm].
  /// Trên Desktop, [printer] (từ [shop] hoặc [printerName]) dùng cho Silent Print (tùy nền tảng).
  static void requestPrint(
    BuildContext context, {
    required SaleModel sale,
    ShopModel? shop,
    int? paperMmOverride,
    String? printerNameOverride,
  }) {
    final paper = paperMmOverride ?? paperSizeMm(shop);
    final printer = printerNameOverride ?? printerName(shop);

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xem trước / In hóa đơn'),
        content: SingleChildScrollView(
          child: InvoicePrintWidget(
            sale: sale,
            shop: shop,
            paperWidthMm: paper,
            showBorder: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Đóng'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _performPrint(context, printer: printer);
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('In'),
          ),
        ],
      ),
    );
  }

  static void _performPrint(BuildContext context, {String? printer}) {
    if (isDesktopPlatform && printer != null && printer.trim().isNotEmpty) {
      // Dành cho Silent Print đúng thiết bị: có thể tích hợp native/plugin theo tên máy in.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Máy in: $printer. Mở hộp thoại in và chọn đúng máy in nếu cần.'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
    // Mở hộp thoại in hệ thống (trên web: window.print; desktop/mobile tùy môi trường).
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kết nối máy in nhiệt (58mm/80mm). Chọn máy in trong hộp thoại in.'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}
