# Hướng dẫn sửa lỗi SSL Certificate khi build Windows

## Vấn đề
```
HandshakeException: CERTIFICATE_VERIFY_FAILED: unable to get local issuer certificate
```

Lỗi này xảy ra khi package `sqlite3` cố gắng tải native assets từ internet nhưng không thể xác thực SSL certificate.

## Giải pháp

### 1. Cập nhật Windows Root Certificates (Khuyến nghị)

1. Mở **Settings** (Windows + I)
2. Vào **Update & Security** > **Windows Update**
3. Nhấn **Check for updates** và cài đặt tất cả updates
4. Sau khi cập nhật, chạy lại build

### 2. Tải Root Certificates thủ công

1. Mở **Internet Explorer** hoặc **Microsoft Edge Legacy**
2. Vào **Internet Options** > **Content** > **Certificates**
3. Vào tab **Trusted Root Certification Authorities**
4. Nhấn **Import** và làm theo hướng dẫn
5. Hoặc tải từ: https://www.digicert.com/kb/digicert-root-certificates.htm

### 3. Kiểm tra Proxy/Firewall

Nếu bạn đang ở trong mạng corporate hoặc dùng proxy:

1. Kiểm tra Windows Proxy Settings:
   - Settings > Network & Internet > Proxy
   - Tắt proxy nếu không cần thiết
   
2. Kiểm tra Firewall:
   - Windows Security > Firewall & network protection
   - Cho phép Flutter/Dart qua firewall

### 4. Sử dụng mạng khác

Thử build trên một mạng khác (không có proxy/firewall) để xác định vấn đề.

### 5. Tạm thời bỏ qua SSL verification (Không khuyến nghị - Chỉ dùng khi test)

Tạo file `.dart_tool/package_config_subset` hoặc set biến môi trường:

```powershell
# Windows PowerShell
$env:DART_VM_OPTIONS="--no-sound-null-safety"
$env:FLUTTER_BUILD_MODE="debug"
```

**Lưu ý**: Giải pháp này không an toàn và chỉ nên dùng để test.

### 6. Thử build với offline mode (nếu đã có assets cached)

```bash
flutter build windows --release --offline
```

### 7. Xóa cache và thử lại

```bash
flutter clean
flutter pub cache repair
flutter pub get
flutter build windows --debug
```

## Kiểm tra kết quả

Sau khi thực hiện các bước trên, chạy:

```bash
flutter doctor -v
```

Kiểm tra xem phần "Network resources" còn báo lỗi không.

