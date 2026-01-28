# Hướng dẫn cài đặt và cấu hình Firebase cho Flutter

## Bước 1: Cài đặt Firebase CLI

### Trên Windows (PowerShell):
```powershell
# Cài đặt Node.js trước (nếu chưa có)
# Tải từ: https://nodejs.org/

# Cài đặt Firebase CLI toàn cục
npm install -g firebase-tools

# Kiểm tra cài đặt
firebase --version
```

### Trên macOS/Linux:
```bash
# Cài đặt Node.js trước (nếu chưa có)
# macOS: brew install node
# Linux: sudo apt-get install nodejs npm

# Cài đặt Firebase CLI toàn cục
npm install -g firebase-tools

# Kiểm tra cài đặt
firebase --version
```

## Bước 2: Đăng nhập vào Firebase

```bash
firebase login
```

Lệnh này sẽ mở trình duyệt để bạn đăng nhập vào tài khoản Google của mình.

## Bước 3: Cài đặt FlutterFire CLI

```bash
# Cài đặt FlutterFire CLI
dart pub global activate flutterfire_cli

# Đảm bảo PATH có chứa đường dẫn đến pub cache
# Windows: %LOCALAPPDATA%\Pub\Cache\bin
# macOS/Linux: ~/.pub-cache/bin
```

## Bước 4: Cấu hình Firebase cho dự án Flutter

```bash
# Chạy lệnh cấu hình (từ thư mục gốc của dự án Flutter)
flutterfire configure
```

Lệnh này sẽ:
1. Yêu cầu bạn chọn Firebase project
2. Chọn các platforms cần cấu hình (Android, iOS, Web, macOS, Windows, Linux)
3. Tự động tạo file `lib/firebase_options.dart` với cấu hình cho tất cả platforms

### Lưu ý:
- Nếu bạn chưa có Firebase project, hãy tạo một project mới tại https://console.firebase.google.com/
- Đảm bảo bạn đã thêm các platforms (Android, iOS, Web) vào Firebase project trước khi chạy `flutterfire configure`

## Bước 5: Kiểm tra file firebase_options.dart

Sau khi chạy `flutterfire configure`, bạn sẽ thấy file `lib/firebase_options.dart` được tạo ra. File này chứa cấu hình Firebase cho tất cả các platforms.

## Bước 6: Cập nhật main.dart

File `main.dart` đã được cập nhật để:
- Khởi tạo Firebase với `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)`
- Đợi Firebase khởi tạo xong trước khi chạy app
- Xử lý lỗi nếu Firebase khởi tạo thất bại

## Bước 7: Cập nhật AuthProvider

`AuthProvider` đã được cập nhật để:
- Kiểm tra Firebase đã sẵn sàng trước khi sử dụng
- Có biến `isFirebaseReady` để UI có thể kiểm tra trạng thái

## Troubleshooting

### Lỗi: "firebase: command not found"
- Đảm bảo đã cài đặt Node.js và npm
- Thử cài đặt lại: `npm install -g firebase-tools`

### Lỗi: "flutterfire: command not found"
- Chạy: `dart pub global activate flutterfire_cli`
- Thêm đường dẫn pub cache vào PATH

### Lỗi khi chạy flutterfire configure
- Đảm bảo đã đăng nhập: `firebase login`
- Kiểm tra bạn có quyền truy cập Firebase project
- Đảm bảo đã thêm platforms vào Firebase project

### Lỗi Firebase initialization
- Kiểm tra file `firebase_options.dart` đã được tạo
- Đảm bảo đã thêm Google Services files (google-services.json cho Android, GoogleService-Info.plist cho iOS)

