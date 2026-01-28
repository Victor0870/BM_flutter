# Tóm tắt tích hợp Thanh toán VietQR

## Đã hoàn thành

1. ✅ **Models:**
   - `ShopModel`: Thêm `PaymentConfig` với các trường PayOS/Casso và thông tin ngân hàng
   - `SaleModel`: Thêm `paymentStatus` (PENDING, COMPLETED) và enum `PaymentMethodType` (CASH, TRANSFER)
   - Database schema: Cập nhật version 4, thêm migration cho `paymentStatus`, `customerTaxCode`, `customerAddress`

2. ✅ **PaymentService:**
   - Tạo `lib/services/payment_service.dart`
   - Hỗ trợ PayOS API và VietQR đơn giản
   - Functions: `createPaymentQR()`, `checkPaymentStatus()`

3. ✅ **ShopSettingsScreen:**
   - Form cấu hình Payment Provider (None, PayOS, Casso)
   - Input fields cho PayOS (ClientId, ApiKey, ChecksumKey)
   - Input fields cho thông tin ngân hàng (BankBin, AccountNumber, AccountName)

## Cần hoàn thiện

### 1. Cập nhật SalesProvider
- Thêm method `checkoutWithTransfer()` để xử lý thanh toán chuyển khoản
- Thêm polling logic để kiểm tra trạng thái thanh toán
- Lưu sale với `paymentStatus = 'PENDING'` khi thanh toán QR

### 2. Cập nhật SalesScreen
- Dialog chọn phương thức thanh toán (Tiền mặt / Chuyển khoản QR)
- Màn hình hiển thị QR code với:
  - QR code từ `PaymentService.createPaymentQR()`
  - Loading indicator
  - Nút "Hủy/Quay lại"
  - Tự động polling và hoàn tất khi nhận được thanh toán

### 3. QR Code Display Widget
Tạo widget riêng `PaymentQRDialog` để:
- Hiển thị QR code bằng `qr_flutter`
- Polling status mỗi 3-5 giây
- Auto-close khi thanh toán thành công
- Callback để hoàn tất sale

### 4. SalesService
- Cập nhật `saveSale()` để hỗ trợ `paymentStatus = 'PENDING'`
- Method `updateSalePaymentStatus()` để cập nhật từ PENDING → COMPLETED

## Code mẫu cho phần còn lại

### PaymentQRDialog Widget
```dart
class PaymentQRDialog extends StatefulWidget {
  final String orderId;
  final double amount;
  final PaymentService paymentService;
  final Function(String orderId) onPaymentSuccess;
  
  // Implementation với Timer polling
}
```

### SalesProvider.checkoutWithTransfer()
```dart
Future<String?> checkoutWithTransfer() async {
  // 1. Tạo order ID
  // 2. Gọi PaymentService.createPaymentQR()
  // 3. Lưu sale với paymentStatus = 'PENDING'
  // 4. Trả về orderId để hiển thị QR
}
```

### SalesScreen - Dialog chọn phương thức
```dart
void _showPaymentMethodDialog() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Chọn phương thức thanh toán'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.money),
            title: Text('Tiền mặt'),
            onTap: () {
              Navigator.pop(context);
              _handleCheckout(PaymentMethodType.cash);
            },
          ),
          ListTile(
            leading: Icon(Icons.qr_code),
            title: Text('Chuyển khoản QR'),
            onTap: () {
              Navigator.pop(context);
              _handleCheckout(PaymentMethodType.transfer);
            },
          ),
        ],
      ),
    ),
  );
}
```

## Dependencies đã thêm
- `qr_flutter: ^4.1.0` - Generate QR codes
- `crypto: ^3.0.7` - HMAC SHA256 cho PayOS checksum

## Lưu ý
- PayOS API cần test với credentials thực tế
- Polling interval nên configurable (3-5 giây)
- Timeout cho payment: 15-30 phút
- Webhook support cho Casso cần implement riêng

