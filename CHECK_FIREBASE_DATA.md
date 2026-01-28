# Hướng dẫn kiểm tra và sửa lỗi Firebase không có data

## Bước 1: Deploy Firestore Rules

Firestore rules hiện tại có thể chặn việc tạo shop. Hãy deploy rules:

```powershell
firebase deploy --only firestore:rules
```

Hoặc deploy qua Firebase Console:
1. Vào https://console.firebase.google.com/
2. Chọn project của bạn
3. Vào **Firestore Database** → **Rules**
4. Copy nội dung từ file `firestore.rules`
5. Paste và nhấn **Publish**

## Bước 2: Kiểm tra Console Logs

Sau khi đăng ký, mở DevTools (F12) → Console và tìm:

✅ **Nếu thành công:**
```
✅ Shop created successfully in Firestore for user: [user-id]
License expires on: [date]
```

❌ **Nếu có lỗi:**
```
❌ Error creating shop in Firestore: [error message]
```

## Bước 3: Kiểm tra Firestore Database

1. Vào Firebase Console → **Firestore Database**
2. Tìm collection `shops`
3. Tìm document với ID = user.uid (từ Authentication)
4. Kiểm tra xem có data không

## Bước 4: Kiểm tra Authentication

1. Vào Firebase Console → **Authentication**
2. Xác nhận user đã được tạo
3. Copy User UID
4. Kiểm tra trong Firestore: `shops/{user-uid}`

## Bước 5: Test lại

1. Đăng xuất (nếu đã đăng nhập)
2. Đăng ký tài khoản mới
3. Mở Console (F12) để xem logs
4. Kiểm tra Firestore sau khi đăng ký

## Lỗi thường gặp

### Lỗi: "Missing or insufficient permissions"
→ Firestore rules chưa được deploy hoặc rules sai
→ Giải pháp: Deploy lại rules

### Lỗi: "User not authenticated"
→ User chưa đăng nhập đúng cách
→ Giải pháp: Kiểm tra Firebase Auth

### Không có lỗi nhưng không có data
→ Có thể rules đang ở chế độ test mode
→ Giải pháp: Kiểm tra rules trong Firebase Console

