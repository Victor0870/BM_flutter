# Hướng dẫn khắc phục lỗi Build Windows

## Lỗi hiện tại
```
HandshakeException : Handshake error in client
Building native assets failed
```

## Nguyên nhân có thể
1. **Firewall/Proxy chặn kết nối** - Firewall hoặc proxy đang chặn kết nối HTTPS
2. **SSL Certificate issues** - Vấn đề với chứng chỉ SSL
3. **Network timeout** - Mạng không ổn định khi download dependencies
4. **Antivirus interference** - Antivirus đang can thiệp vào quá trình build

## Các giải pháp

### 1. Kiểm tra Firewall
- Tắt Windows Firewall tạm thời khi build
- Hoặc thêm exception cho Flutter/Dart

### 2. Kiểm tra Proxy/VPN
- Tắt VPN nếu đang dùng
- Kiểm tra proxy settings trong Windows
- Thử build khi không có proxy

### 3. Thử build với offline mode
```bash
flutter build windows --release --offline
```

### 4. Kiểm tra Antivirus
- Tắt Antivirus tạm thời
- Hoặc thêm exception cho thư mục project

### 5. Thử build với debug mode
```bash
flutter build windows --debug
```

### 6. Xóa cache và thử lại
```bash
flutter clean
Remove-Item -Path "$env:USERPROFILE\.dartServer" -Recurse -Force -ErrorAction SilentlyContinue
flutter pub cache repair
flutter pub get
flutter build windows
```

### 7. Kiểm tra network connection
Thử ping các domain sau:
- `pub.dev`
- `storage.googleapis.com`
- `github.com`

Nếu không ping được, có thể do firewall/proxy.

### 8. Thử chạy trực tiếp (không build)
```bash
flutter run -d windows
```
Cách này sẽ chạy app ở debug mode mà không cần build full release.

## Lưu ý
- Lỗi này thường do mạng/firewall, không phải lỗi code
- Code đã được sửa đúng (đã có SQLite FFI initialization)
- Nếu vẫn lỗi, có thể thử build trên máy khác hoặc network khác

