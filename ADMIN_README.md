# BizMate Admin (Web)

Trang quản trị dùng **Cách 2**: Flutter Web đọc/ghi trực tiếp Firestore, entry point tách riêng để code admin không nằm trong bản APK/desktop.

## Build bản Web Admin

```bash
flutter build web -t lib/main_admin.dart
```

Kết quả nằm trong `build/web`. Deploy thư mục này lên Firebase Hosting (hoặc host tĩnh khác) và truy cập bằng URL riêng (ví dụ subdomain hoặc path `/admin`).

- **App shop** (APK, desktop): build như bình thường với `main.dart` — không chứa code admin.

## Tạo tài khoản Admin đầu tiên

1. Đăng ký/đăng nhập một tài khoản Firebase Auth (email/password) mà bạn sẽ dùng làm admin.
2. Vào **Firebase Console** → **Firestore Database**.
3. Tạo collection tên **`admins`** (nếu chưa có).
4. Thêm document:
   - **Document ID**: UID của tài khoản admin (lấy từ Authentication → Users → copy UID của user đó).
   - **Field**: `admin` (kiểu boolean) = **`true`**.

Sau đó đăng nhập trang Admin Web bằng email/mật khẩu tài khoản đó — bạn sẽ vào được dashboard.

## Chức năng Dashboard

- Xem danh sách tất cả shop: ID, tên, gói (BASIC/PRO), ngày tạo, hết hạn, số user.
- Tìm theo ID shop (trùng nội dung chuyển khoản).
- Nút **Nâng cấp lên PRO**: cập nhật shop lên gói PRO (xóa/không set hạn).

## Bảo mật

- Chỉ user có document `admins/{uid}` với `admin: true` mới đọc được toàn bộ `shops` và `users`, và mới cập nhật được `shops`. Rules Firestore đã cấu hình trong `firestore.rules`.
- Collection `admins` không cho client ghi — chỉ thêm/sửa qua Firebase Console hoặc Admin SDK.
