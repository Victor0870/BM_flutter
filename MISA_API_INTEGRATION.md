# Tích hợp API Hóa đơn điện tử MISA meInvoice

Tài liệu này mô tả cách gọi API MISA meInvoice để xuất hóa đơn tương tự Viettel và FPT, và cách app Bizmate đã tích hợp.

## Tài liệu tham khảo MISA

- **Tổng quan Open API**: https://www.misa.vn/154127/tong-quan-open-api-hoa-don-dien-tu-misa-meinvoice/
- **Lấy Token**: https://doc.meinvoice.vn/itg/Doc/GetToken.html
- **Tạo, ký và phát hành hóa đơn**: https://doc.meinvoice.vn/api/Document/InvoicePublishing.html
- **Tài liệu Đầu vào/Đầu ra**: https://www.misa.vn/154997/ (Đầu vào), https://www.misa.vn/154989/ (Đầu ra)

## So sánh nhanh: MISA vs Viettel vs FPT

| Khía cạnh | FPT | Viettel | MISA |
|-----------|-----|---------|------|
| **Xác thực** | POST `/c_signin` → Bearer token (hoặc Basic) | POST `.../auth/login` → Cookie `access_token` | POST `.../api/integration/auth/token` với **AppID**, taxcode, username, password → Bearer token |
| **Tạo HĐ** | 1 bước: POST create-icr với payload 01/MTT | 1 bước: POST createInvoice với generalInvoiceInfo, itemInfo... | **3 bước**: (1) Create raw → (2) Ký XML → (3) Publish |
| **Payload** | inv, items, sum, vat, total, tradeamount... | generalInvoiceInfo, sellerInfo, buyerInfo, itemInfo, summarizeInfo, taxBreakdowns | OriginalInvoiceData: RefID, InvSeries, InvDate, Buyer*, OriginalInvoiceDetail[], TaxRateInfo[], OptionUserDefined |
| **Trường đặc thù** | serial, stax, form, type 01/MTT | templateCode, invoiceSeries, transactionUuid | **AppID** (bắt buộc), CompanyTaxCode header |
| **URL Test** | api-uat.einvoice.fpt.com.vn | api-vinvoice.viettel.vn | testapi.meinvoice.vn |
| **URL Live** | api.einvoice.fpt.com.vn | (cùng domain) | api.meinvoice.vn |

## Luồng MISA (3 bước)

### Bước 1: Lấy Token

- **Method**: POST  
- **URL Test**: `https://testapi.meinvoice.vn/api/integration/auth/token`  
- **URL Live**: `https://api.meinvoice.vn/api/integration/auth/token`  
- **Body (JSON)**:
  ```json
  {
    "appid": "chuỗi AppID do MISA cung cấp",
    "taxcode": "Mã số thuế",
    "username": "tài khoản đăng nhập MISA",
    "password": "Mật khẩu"
  }
  ```
- **Response**: `{ "Success": true, "Data": "<JWT token>" }`  
- Mọi request sau phải gửi header: `Authorization: Bearer <token>`, `CompanyTaxCode: <MST>`.

### Bước 2: Tạo hóa đơn (Create – dữ liệu thô)

- **Method**: POST  
- **URL**: `{baseUrl}/api/v3/itg/invoicepublishing/createinvoice`  
  - Test: baseUrl = `https://testapi.meinvoice.vn`  
  - Live: baseUrl = `https://api.meinvoice.vn`  
- **Headers**: `Content-Type: application/json`, `Authorization: Bearer <token>`, `CompanyTaxCode: <MST>`  
- **Body**: Mảng một phần tử `[OriginalInvoiceData]`:
  - RefID, InvSeries, InvoiceName, InvDate, CurrencyCode, ExchangeRate, PaymentMethodName  
  - BuyerLegalName, BuyerTaxCode, BuyerAddress, BuyerEmail, ...  
  - OriginalInvoiceDetail[] (ItemType, LineNumber, ItemCode, ItemName, UnitName, Quantity, UnitPrice, VATRateName, VATAmountOC, VATAmount, ...)  
  - TaxRateInfo[] (VATRateName, AmountWithoutVATOC, VATAmountOC)  
  - OptionUserDefined (MainCurrency, AmountDecimalDigits, ...)  
  - Tổng: TotalSaleAmountOC, TotalAmountWithoutVATOC, TotalVATAmountOC, TotalDiscountAmountOC, TotalAmountOC, TotalAmountInWords  

- **Response**: `Success`, `Data` = JSON string của mảng đối tượng chứa:
  - RefID, TransactionID, InvNo, InvDate, **InvoiceData** (chuỗi XML hóa đơn theo chuẩn CQT).

### Bước 3: Ký điện tử và Phát hành

- **Ký**: XML trong `InvoiceData` phải được ký bằng USB Token / HSM (MISA Sign Service, thường chạy trên máy nội bộ: `http://server:12019/api/SignXML` với PinCode, XmlContent). Ứng dụng Flutter/mobile thường **không** ký trực tiếp; cần backend hoặc dịch vụ ký của MISA.
- **Phát hành**: POST `{baseUrl}/api/v3/code/invoicepublishing` với body là mảng đối tượng chứa RefID, TransactionID, **InvoiceData** (XML đã ký). Response trả về trạng thái phát hành (InvNo, InvSeries, InvDate, ErrorCode...).

## Cách app Bizmate đã tích hợp MISA

- **Enum**: Thêm `EinvoiceProvider.misa` trong `lib/models/shop_model.dart`.  
- **Cấu hình**: `EinvoiceConfig` có thêm trường tùy chọn `appId` (bắt buộc khi chọn MISA). Trong **Cài đặt Shop** → Cấu hình HĐĐT, chọn nhà cung cấp **MISA** và nhập:
  - **AppID** (do MISA cung cấp)
  - Username / Password (đăng nhập MISA)
  - Base URL: Test `https://testapi.meinvoice.vn`, Live `https://api.meinvoice.vn`
  - Mã số thuế, Ký hiệu hóa đơn (dùng chung với FPT/Viettel)
- **Provider**: `lib/services/einvoice/misa_invoice_provider.dart`:
  - Lấy token (AppID + taxcode + username + password).
  - Gọi **bước 1** (Create invoice) và cập nhật sale với InvNo, TransactionID, link tra cứu (nếu MISA cung cấp).
  - Hóa đơn thay thế: dùng cùng API Create với ReferenceType=1 và các trường OrgInvNo, OrgInvDate, ...
  - Hủy hóa đơn: chưa gọi API (ném thông báo hướng dẫn thực hiện trên portal hoặc tích hợp API hủy theo tài liệu MISA).
- **Dữ liệu payload**: `lib/services/einvoice_data_service.dart` có `prepareMisaPayload()` tạo đúng cấu trúc OriginalInvoiceData + OriginalInvoiceDetail + TaxRateInfo + OptionUserDefined.

## Lưu ý khi dùng MISA

1. **AppID**: Phải đăng ký với MISA để nhận AppID; không có AppID thì không lấy được token.  
2. **Quy trình đủ 3 bước**: Ở app hiện tại mới thực hiện **bước 1** (tạo dữ liệu + nhận XML). Để **phát hành chính thức** lên CQT cần thêm:
   - Bước 2: Ký XML (qua backend có MISA Sign Service hoặc USB Token);
   - Bước 3: Gọi API Publish với XML đã ký.  
3. **Hủy / Điều chỉnh**: API hủy và điều chỉnh hóa đơn cần tra cứu thêm trên doc.meinvoice.vn hoặc liên hệ MISA.  
4. **Link tra cứu**: Có thể dùng TransactionID để tra cứu trên portal MISA (ví dụ `https://app.meinvoice.vn/tra-cuu?transactionId=...`).

Kết luận: Cách gọi API MISA đã được tích hợp tương tự Viettel/FPT ở lớp provider và cấu hình (chọn MISA, nhập AppID, baseUrl, username, password). Khác biệt chính là MISA yêu cầu **AppID** và quy trình **3 bước** (Create → Ký → Publish); phần Ký và Publish có thể mở rộng sau khi có backend hoặc dịch vụ ký.
