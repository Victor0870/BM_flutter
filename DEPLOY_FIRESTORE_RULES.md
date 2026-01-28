# Hướng dẫn Deploy Firestore Security Rules

## Cách deploy rules lên Firebase

### 1. Sử dụng Firebase CLI

```powershell
# Đảm bảo đã đăng nhập
firebase login

# Deploy rules
firebase deploy --only firestore:rules
```

### 2. Hoặc deploy qua Firebase Console

1. Truy cập https://console.firebase.google.com/
2. Chọn project của bạn
3. Vào **Firestore Database** → **Rules**
4. Copy nội dung từ file `firestore.rules`
5. Paste vào editor và nhấn **Publish**

## Kiểm tra rules

Sau khi deploy, bạn có thể test rules trong Firebase Console:
1. Vào **Firestore Database** → **Rules**
2. Nhấn **Rules Playground** để test các scenarios

## Lưu ý

- Rules sẽ có hiệu lực ngay sau khi deploy
- Đảm bảo rules phù hợp với cấu trúc dữ liệu của bạn
- Test kỹ trước khi deploy lên production

