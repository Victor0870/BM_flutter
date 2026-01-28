# Hướng dẫn Test trên Mobile và Desktop

## 1. Kiểm tra thiết bị có sẵn

```powershell
flutter devices
```

Lệnh này sẽ liệt kê tất cả thiết bị có sẵn (Android, iOS, Windows, macOS, Linux, Web).

## 2. Test trên Android

### Yêu cầu:
- Android Studio đã cài đặt
- Android SDK đã được cấu hình
- Thiết bị Android hoặc Emulator

### Các bước:

#### Option A: Sử dụng Android Emulator
```powershell
# 1. Mở Android Studio
# 2. Vào Tools → Device Manager
# 3. Tạo hoặc khởi động một Android Emulator
# 4. Chạy app:
flutter run
# Hoặc chỉ định device:
flutter run -d android
```

#### Option B: Sử dụng thiết bị thật
```powershell
# 1. Bật USB Debugging trên điện thoại:
#    Settings → About Phone → Tap "Build Number" 7 lần
#    Settings → Developer Options → Enable "USB Debugging"
# 2. Kết nối điện thoại qua USB
# 3. Chấp nhận "Allow USB Debugging" trên điện thoại
# 4. Chạy:
flutter devices  # Kiểm tra thiết bị đã kết nối
flutter run -d <device-id>
```

## 3. Test trên iOS (chỉ macOS)

### Yêu cầu:
- macOS
- Xcode đã cài đặt
- iOS Simulator hoặc thiết bị iOS

```bash
# 1. Mở Xcode
# 2. Vào Xcode → Open Developer Tool → Simulator
# 3. Chọn một iOS Simulator
# 4. Chạy app:
flutter run -d ios
```

## 4. Test trên Windows Desktop

```powershell
# Chạy trực tiếp:
flutter run -d windows

# Hoặc build file .exe:
flutter build windows
# File sẽ ở: build\windows\x64\runner\Release\bizmate_app.exe
```

## 5. Test trên macOS Desktop

```bash
flutter run -d macos
```

## 6. Test trên Linux Desktop

```bash
flutter run -d linux
```

## 7. Chọn thiết bị cụ thể

Nếu có nhiều thiết bị, chọn device ID:

```powershell
# Xem danh sách:
flutter devices

# Output sẽ như:
# • Windows (desktop) • windows • windows-x64 • Microsoft Windows [Version 10.0.19045.0]
# • Chrome (web)      • chrome  • web-javascript • Google Chrome 120.0.6099.109
# • sdk gphone64 arm64 (mobile) • emulator-5554 • android-arm64 • Android 14 (API 34)

# Chạy trên device cụ thể:
flutter run -d windows
flutter run -d chrome
flutter run -d emulator-5554
```

## 8. Debug Mode

Để debug với hot reload:

```powershell
flutter run -d <device-id>
```

Trong khi app đang chạy:
- Nhấn `r` để hot reload
- Nhấn `R` để hot restart
- Nhấn `q` để quit

## 9. Release Mode (Test performance)

```powershell
# Android:
flutter run --release -d android

# Windows:
flutter run --release -d windows

# iOS:
flutter run --release -d ios
```

## 10. Troubleshooting

### Android: "No devices found"
```powershell
# Kiểm tra ADB:
adb devices

# Nếu không thấy device:
# 1. Kiểm tra USB Debugging đã bật
# 2. Thử cài lại USB drivers
# 3. Thử dùng emulator thay vì thiết bị thật
```

### iOS: "No devices found"
```bash
# 1. Đảm bảo Xcode đã cài đặt
# 2. Chạy: sudo xcode-select --switch /Applications/Xcode.app
# 3. Chạy: open -a Simulator
```

### Windows: Build errors
```powershell
# 1. Đảm bảo Visual Studio đã cài với C++ workload
# 2. Chạy: flutter doctor
# 3. Sửa các issues được báo
```

## 11. Test Firebase trên Mobile/Desktop

Sau khi chạy app trên mobile/desktop:
1. Đăng ký tài khoản mới
2. Kiểm tra Firebase Console → Firestore → collection `shops`
3. Kiểm tra Firebase Console → Authentication
4. SQLite sẽ hoạt động bình thường (không như web)

## 12. Kiểm tra Logs

### Android:
```powershell
# Xem logs:
flutter logs
# Hoặc:
adb logcat | grep flutter
```

### iOS:
```bash
# Xem logs trong Xcode Console
# Hoặc:
flutter logs
```

### Windows:
```powershell
# Logs sẽ hiển thị trong terminal
# Hoặc mở app và xem console output
```

## Tips

1. **Nên test trên mobile thật** để có trải nghiệm tốt nhất
2. **Emulator chậm hơn** thiết bị thật nhưng tiện cho development
3. **Desktop (Windows/macOS)** tốt cho testing UI và performance
4. **Web** chỉ dùng để test UI, không có SQLite

