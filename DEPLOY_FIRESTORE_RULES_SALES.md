# Deploy Firestore Rules cho Sales

## Vấn đề

Lỗi `permission-denied` khi lưu sale vì Firestore rules chưa có rules cho collection `sales`.

## Giải pháp

Đã cập nhật file `firestore.rules` để thêm rules cho subcollection `sales`.

## Deploy Rules

```powershell
firebase deploy --only firestore:rules
```

Hoặc deploy qua Firebase Console:
1. Vào https://console.firebase.google.com/
2. Chọn project → Firestore Database → Rules
3. Copy nội dung từ file `firestore.rules`
4. Paste và nhấn **Publish**

## Kiểm tra

Sau khi deploy rules:
1. Refresh app
2. Thử thanh toán lại
3. Kiểm tra Firestore → `shops/{userId}/sales/` có data không

