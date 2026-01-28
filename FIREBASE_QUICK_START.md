# Hướng dẫn nhanh: Kết nối Firebase với Flutter

## Các lệnh cần chạy (theo thứ tự)

### 1. Cài đặt Firebase CLI
```powershell
# Windows (PowerShell)
npm install -g firebase-tools

# Kiểm tra cài đặt
firebase --version
```

### 2. Đăng nhập Firebase
```powershell
firebase login
```

### 3. Cài đặt FlutterFire CLI
```powershell
dart pub global activate flutterfire_cli
```

### 4. Cấu hình Firebase cho dự án
```powershell
# Từ thư mục gốc của dự án (D:\Flutter\bizmate_app)
flutterfire configure
```

Lệnh này sẽ:
- Yêu cầu chọn Firebase project
- Chọn platforms (Android, iOS, Web, etc.)
- Tự động tạo file `lib/firebase_options.dart` với cấu hình đầy đủ

### 5. Chạy ứng dụng
```powershell
flutter run
```

## Lưu ý quan trọng

⚠️ **File `lib/firebase_options.dart` hiện tại là file placeholder**
- File này sẽ được thay thế tự động khi chạy `flutterfire configure`
- Sau khi chạy `flutterfire configure`, file sẽ chứa cấu hình thực tế từ Firebase project của bạn

## Kiểm tra kết nối

Sau khi chạy `flutterfire configure` và khởi động app, bạn sẽ thấy trong console:
```
Firebase initialized successfully
Firebase is ready
```

Nếu thấy các thông báo này, Firebase đã được kết nối thành công!

## Troubleshooting

### Lỗi: "firebase: command not found"
→ Cài đặt Node.js và npm trước, sau đó chạy lại `npm install -g firebase-tools`

### Lỗi: "flutterfire: command not found"
→ Chạy `dart pub global activate flutterfire_cli` và thêm pub cache vào PATH

### Lỗi khi chạy flutterfire configure
→ Đảm bảo đã:
1. Đăng nhập: `firebase login`
2. Có quyền truy cập Firebase project
3. Đã thêm platforms vào Firebase Console

