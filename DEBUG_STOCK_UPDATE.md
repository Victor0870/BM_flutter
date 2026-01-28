# Hướng dẫn Debug: Stock không được cập nhật

## Kiểm tra Logs

Sau khi thanh toán, mở **DevTools (F12)** → **Console** và tìm các logs sau:

### ✅ Logs thành công:
```
💼 Starting saveSale with X items, total: Y
📦 Step 1: Updating product stocks...
🔄 Updating stock for product: [productId], quantity: [quantity]
📦 Current stock for [productName]: [currentStock]
💾 New stock for [productName]: [newStock]
☁️ Updating product in Firestore: [productId], new stock: [newStock]
✅ Product updated in Firestore successfully
✅ Stock updated successfully for [productName]
✅ Step 1 completed: All stocks updated
💾 Step 2: Saving sale to storage...
🌐 Web mode: Saving to Firestore only
✅ Sale saved successfully: [saleId]
```

### ❌ Nếu có lỗi:
- `❌ Error updating stock for product [id]: [error]` → Xem lỗi cụ thể
- `❌ Error updating product in Firestore: [error]` → Có thể là permission

## Các bước Debug

### 1. Kiểm tra Firestore Rules
Đảm bảo rules cho phép update products:
- Vào Firebase Console → Firestore Database → Rules
- Kiểm tra rules cho `shops/{userId}/products/{productId}` có `allow update: if isOwner(userId)`

### 2. Kiểm tra Product có tồn tại
- Logs sẽ hiển thị: `Product [id] not found` nếu không tìm thấy
- Đảm bảo product ID trong cart khớp với product ID trong Firestore

### 3. Kiểm tra Stock trong Firestore
- Vào Firebase Console → Firestore Database
- Tìm: `shops/{userId}/products/{productId}`
- Xem field `stock` có được cập nhật không

### 4. Kiểm tra Permission
- Đảm bảo user đã đăng nhập
- Kiểm tra `request.auth.uid` khớp với `userId` trong path

## Test Steps

1. **Thêm sản phẩm vào giỏ hàng**
2. **Mở Console (F12)** để xem logs
3. **Thanh toán**
4. **Xem logs** để biết có lỗi gì không
5. **Kiểm tra Firestore** để xem stock có được update không
6. **Refresh màn hình Kho** để xem stock mới

## Common Issues

### Issue 1: Permission Denied
→ **Giải pháp**: Deploy lại Firestore rules

### Issue 2: Product not found
→ **Giải pháp**: Đảm bảo product ID đúng

### Issue 3: Stock không thay đổi trong UI
→ **Giải pháp**: Đã thêm reload products sau checkout. Nếu vẫn không thấy, thử:
- Pull to refresh trong ProductListScreen
- Hoặc navigate ra và vào lại màn hình Kho

