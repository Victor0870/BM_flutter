# Hướng dẫn tạo Firestore Index

## Vấn đề

Firestore yêu cầu composite index khi query với nhiều điều kiện (where + orderBy).

## Cách 1: Click vào link (Nhanh nhất) ✅

Firebase đã cung cấp link trực tiếp trong error message. Hãy click vào link này:

```
https://console.firebase.google.com/v1/r/project/bizmate-1e317/firestore/indexes?create_composite=...
```

Link sẽ tự động tạo index cần thiết.

## Cách 2: Tạo thủ công trong Firebase Console

1. Vào Firebase Console: https://console.firebase.google.com/
2. Chọn project của bạn
3. Vào **Firestore Database** → **Indexes**
4. Nhấn **Create Index**
5. Điền thông tin:
   - **Collection ID**: `products`
   - **Fields to index**:
     - Field: `isActive`, Order: `Ascending`
     - Field: `name`, Order: `Ascending`
   - **Query scope**: Collection
6. Nhấn **Create**

## Cách 3: Deploy bằng file indexes (Khuyến nghị)

Đã tạo file `firestore.indexes.json` với index cần thiết.

Deploy index:

```powershell
firebase deploy --only firestore:indexes
```

Hoặc deploy cả rules và indexes:

```powershell
firebase deploy --only firestore
```

## Sau khi tạo index

1. Đợi vài phút để index được tạo (Firebase sẽ hiển thị status: "Building" → "Enabled")
2. Refresh app hoặc chạy lại query
3. Lỗi sẽ biến mất

## Kiểm tra index

1. Vào Firebase Console → Firestore Database → Indexes
2. Tìm index với collection `products`
3. Status phải là "Enabled" (màu xanh)

## Lưu ý

- Index cần thời gian để build (thường vài phút)
- Có thể có nhiều index nếu có nhiều query khác nhau
- Firebase sẽ tự động gợi ý index khi query lần đầu

