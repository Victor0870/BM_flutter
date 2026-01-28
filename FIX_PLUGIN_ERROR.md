# Hướng dẫn sửa lỗi MissingPluginException

Lỗi `MissingPluginException` với `path_provider` thường xảy ra khi plugin chưa được đăng ký đúng cách.

## Cách sửa:

### 1. Dừng app hoàn toàn
- Dừng app đang chạy (không chỉ hot reload)
- Đóng tất cả instances của app

### 2. Clean và rebuild
```powershell
# Đã chạy rồi:
flutter clean
flutter pub get

# Bây giờ rebuild app:
flutter run
```

### 3. Nếu vẫn lỗi, thử các bước sau:

#### Trên Android:
```powershell
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run
```

#### Trên iOS:
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
flutter run
```

#### Trên Windows (nếu bạn đang test trên Windows):
- Đảm bảo Developer Mode đã bật trong Windows Settings
- Chạy: `start ms-settings:developers`
- Bật Developer Mode

### 4. Nếu vẫn lỗi, kiểm tra:
- Đảm bảo đã chạy `flutter pub get` sau khi thêm dependencies
- Đảm bảo không có conflicts trong pubspec.yaml
- Thử restart IDE (VS Code/Android Studio)

## Lưu ý quan trọng:
- **KHÔNG** dùng hot reload (r) khi thêm plugin mới
- **PHẢI** rebuild lại app (R) hoặc stop và run lại
- Plugin native (như path_provider, sqflite) cần rebuild để register

