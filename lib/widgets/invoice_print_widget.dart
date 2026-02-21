import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../core/utils/vietqr_generator.dart';
import '../models/sale_model.dart';
import '../models/shop_model.dart';

/// Chiều rộng khổ in nhiệt (px): 80mm ~ 302, 58mm ~ 219 (96 DPI).
const double kThermalWidth80mm = 302;
const double kThermalWidth58mm = 219;

/// Widget/Service mẫu hóa đơn bán hàng cho máy in nhiệt (80mm/58mm), kiểu KiotViet.
/// Dùng để xem trước hoặc xuất ra in (flutter_print, esc_pos_utils, ...).
class InvoicePrintWidget extends StatelessWidget {
  final SaleModel sale;
  final ShopModel? shop;
  /// 80 hoặc 58 (mm)
  final int paperWidthMm;
  final bool showBorder;

  const InvoicePrintWidget({
    super.key,
    required this.sale,
    this.shop,
    this.paperWidthMm = 80,
    this.showBorder = true,
  });

  double get _paperWidthPx =>
      paperWidthMm == 58 ? kThermalWidth58mm : kThermalWidth80mm;

  @override
  Widget build(BuildContext context) {
    final width = _paperWidthPx;
    final f = NumberFormat('#,###', 'vi_VN');
    final paymentLabel = PaymentMethodType.fromString(sale.paymentMethod).displayName;
    final statusLabel = orderStatusDisplayName(sale.statusValue);
    final paid = sale.totalPayment ?? sale.totalAmount;

    return Container(
      width: width,
      decoration: showBorder
          ? BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (shop?.logoUrl != null && shop!.logoUrl!.isNotEmpty) ...[
            Center(
              child: Image.network(
                shop!.logoUrl!,
                width: width * 0.5,
                height: width * 0.25,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 4),
          ],
          _line(shop?.name ?? 'CỬA HÀNG', bold: true, center: true),
          if (shop?.address != null) _line(shop!.address!, center: true, small: true),
          if (shop?.phone != null) _line('ĐT: ${shop!.phone}', center: true, small: true),
          if (shop?.website != null && shop!.website!.isNotEmpty)
            _line(shop!.website!, center: true, small: true),
          _line('─' * (paperWidthMm == 58 ? 26 : 36)),
          _line('HÓA ĐƠN BÁN HÀNG', bold: true, center: true),
          _line('Mã đơn: #${sale.id.length >= 8 ? sale.id.substring(0, 8).toUpperCase() : sale.id.toUpperCase()}'),
          _line('Ngày: ${DateFormat('dd/MM/yyyy HH:mm').format(sale.timestamp)}'),
          if (sale.customerName != null && sale.customerName!.isNotEmpty)
            _line('Khách: ${sale.customerName!}'),
          if (sale.sellerName != null && sale.sellerName!.isNotEmpty)
            _line('NV: ${sale.sellerName!}'),
          _line('Trạng thái: $statusLabel'),
          _line('─' * (paperWidthMm == 58 ? 26 : 36)),
          _line('Tên hàng', bold: true),
          ...sale.items.map((item) {
            final sub = f.format(item.subtotal.toInt());
            final discountText = (item.discount != null && item.discount! > 0)
                ? ' (-${item.isDiscountPercentage == true ? '${item.discount!.toInt()}%' : f.format(item.discount!.toInt())}đ)'
                : '';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _line(item.productName, wrap: true),
                _line('  ${item.quantity.toStringAsFixed(0)} x ${f.format(item.price.toInt())}đ$discountText = $subđ', small: true),
                if (item.notes != null && item.notes!.isNotEmpty)
                  _line('  Ghi chú: ${item.notes!}', small: true),
              ],
            );
          }),
          _line('─' * (paperWidthMm == 58 ? 26 : 36)),
          if (sale.totalBeforeDiscount != null && (sale.totalDiscountAmount ?? 0) > 0) ...[
            _line('Tiền hàng: ${f.format(sale.totalBeforeDiscount!.toInt())}đ'),
            _line('Giảm giá: -${f.format((sale.totalDiscountAmount ?? 0).toInt())}đ'),
          ],
          if (sale.taxAmount != null && sale.taxAmount! > 0)
            _line('Thuế: ${f.format(sale.taxAmount!.toInt())}đ'),
          _line('TỔNG CỘNG: ${f.format(sale.totalAmount.toInt())}đ', bold: true),
          _line('Khách thanh toán: ${f.format(paid.toInt())}đ'),
          _line('Thanh toán: $paymentLabel'),
          if (sale.notes != null && sale.notes!.isNotEmpty) ...[
            _line('─' * (paperWidthMm == 58 ? 26 : 36)),
            _line('Ghi chú: ${sale.notes!}', wrap: true, small: true),
          ],
          _line('─' * (paperWidthMm == 58 ? 26 : 36)),
          _line(
            shop?.invoiceThankYouMessage?.trim().isNotEmpty == true
                ? shop!.invoiceThankYouMessage!
                : 'Cảm ơn quý khách!',
            center: true,
            bold: true,
          ),
          if (shop?.invoiceReturnPolicy != null && shop!.invoiceReturnPolicy!.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            _line(shop!.invoiceReturnPolicy!, center: true, small: true, wrap: true),
          ],
          if (_hasVietQR(shop)) ...[
            const SizedBox(height: 6),
            _line('─' * (paperWidthMm == 58 ? 26 : 36)),
            _buildVietQRBlock(shop!, width),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  bool _hasVietQR(ShopModel? s) {
    if (s == null) return false;
    final bin = s.vietqrBankBin?.trim() ?? '';
    final acc = s.vietqrAccountNumber?.trim() ?? '';
    return bin.length >= 6 && acc.isNotEmpty;
  }

  Widget _buildVietQRBlock(ShopModel shop, double width) {
    final raw = shop.vietqrBankBin!.trim();
    final bin = raw.length >= 6 ? raw.substring(0, 6) : raw.padLeft(6, '0');
    final acc = shop.vietqrAccountNumber!.trim();
    final qrString = VietQRGenerator.generate(
      bankBin: bin,
      accountNumber: acc,
      amount: sale.totalAmount,
      description: sale.id,
    );
    final qrSize = width * 0.35;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _line('Chuyển khoản VietQR', center: true, small: true),
        const SizedBox(height: 4),
        Center(
          child: QrImageView(
            data: qrString,
            version: QrVersions.auto,
            size: qrSize,
            backgroundColor: Colors.white,
            errorCorrectionLevel: QrErrorCorrectLevel.M,
          ),
        ),
        if (shop.vietqrAccountName != null && shop.vietqrAccountName!.isNotEmpty)
          _line(shop.vietqrAccountName!, center: true, small: true),
        if (shop.vietqrAccountNumber != null)
          _line('STK: ${shop.vietqrAccountNumber}', center: true, small: true),
        if (shop.vietqrBankName != null && shop.vietqrBankName!.isNotEmpty)
          _line(shop.vietqrBankName!, center: true, small: true),
      ],
    );
  }

  Widget _line(
    String text, {
    bool bold = false,
    bool center = false,
    bool small = false,
    bool wrap = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: wrap
          ? Text(
              text,
              style: TextStyle(
                fontSize: small ? 10 : 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: center ? TextAlign.center : TextAlign.left,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            )
          : Text(
              text,
              style: TextStyle(
                fontSize: small ? 10 : 12,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: center ? TextAlign.center : TextAlign.left,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}
