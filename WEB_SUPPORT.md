# Hỗ trợ Web Platform

## Vấn đề hiện tại

Ứng dụng này sử dụng `sqflite` và `path_provider` để lưu trữ dữ liệu cục bộ, nhưng các plugin này **KHÔNG hoạt động trên web**.

## Giải pháp

### Option 1: Chỉ test trên Mobile/Desktop (Khuyến nghị)
- Test trên Android/iOS/Windows/macOS/Linux
- Web không được hỗ trợ đầy đủ

### Option 2: Sử dụng Web Storage thay thế
Nếu muốn hỗ trợ web, cần:
- Thay `sqflite` bằng `shared_preferences` hoặc `hive` (hỗ trợ web)
- Hoặc chỉ dùng Firestore trên web (không có offline storage)

## Kiểm tra Firebase Data

Nếu đã đăng ký nhưng không thấy data trong Firestore:

1. **Kiểm tra Firestore Rules:**
   - Vào Firebase Console → Firestore Database → Rules
   - Đảm bảo rules cho phép user tạo shop của chính họ

2. **Kiểm tra Console Logs:**
   - Mở DevTools (F12) → Console
   - Tìm các log: "Shop created successfully" hoặc "Error creating shop"

3. **Kiểm tra Firestore:**
   - Vào Firebase Console → Firestore Database
   - Tìm collection `shops` với document ID = user.uid

4. **Kiểm tra Authentication:**
   - Vào Firebase Console → Authentication
   - Xác nhận user đã được tạo thành công

## Debug Steps

1. Mở DevTools (F12) trong Chrome
2. Vào tab Console
3. Đăng ký tài khoản mới
4. Xem logs để biết có lỗi gì không
5. Kiểm tra Network tab để xem Firestore requests

