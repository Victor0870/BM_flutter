# Cấu trúc Firebase cho nội dung Excel "Data base danganh.xlsx" (KiotViet)

**Mục đích:** Lưu **nội dung** file Excel (sheets, cột, dòng) lên Firestore bằng WriteBatch, không lưu file lên Storage.

---

## 1. Firestore – Cấu trúc đã triển khai

### 1.1. Meta (thông tin lần lưu)

- **Đường dẫn:** `shops/{shopId}/kiotVietData/meta`
- **Quyền:** Chỉ owner của shop (trong `firestore.rules`).

| Field         | Type     | Mô tả |
|---------------|----------|--------|
| `uploadedAt`  | Timestamp| Thời điểm lưu / cập nhật nội dung |
| `sheetNames`  | array    | `["Sheet1", "Tên sheet 2", ...]` – tên các sheet theo thứ tự |
| `fileName`    | string   | `"Data base danganh.xlsx"` |

### 1.2. Từng sheet (document theo chỉ số)

- **Đường dẫn:** `shops/{shopId}/kiotVietData/{sheetIndex}`
- **sheetIndex:** `"0"`, `"1"`, ... (string, theo thứ tự sheet trong file).

| Field          | Type   | Mô tả |
|----------------|--------|--------|
| `sheetName`    | string | Tên sheet gốc trong Excel |
| `columnNames`  | array  | `["Mã", "Tên", "Đơn vị", ...]` – dòng 1 = header |
| `rowCount`     | number | Số dòng dữ liệu (không tính dòng header) |

### 1.3. Từng dòng (subcollection của sheet)

- **Đường dẫn:** `shops/{shopId}/kiotVietData/{sheetIndex}/rows/{rowIndex}`
- **rowIndex:** `"0"`, `"1"`, ... (string, chỉ số dòng dữ liệu).

| Field   | Type  | Mô tả |
|---------|-------|--------|
| `index` | number| Chỉ số dòng (0-based) |
| `cells` | map   | `{ "Tên cột 1": "giá trị", "Tên cột 2": "..." }`. Tên cột có dấu chấm được thay bằng `_` trong key. |

---

## 2. Luồng xử lý

1. User chọn file Excel (chỉ desktop, khi `syncWithKiotViet == true`).
2. App parse file bằng package `excel`: đọc từng sheet, dòng đầu = header (tên cột), các dòng sau = dữ liệu.
3. Ghi lên Firestore bằng **WriteBatch** (tối đa 500 thao tác mỗi batch):
   - Set `meta` (uploadedAt, sheetNames, fileName).
   - Với mỗi sheet: set document `{sheetIndex}` (sheetName, columnNames, rowCount).
   - Với mỗi dòng: set document `rows/{rowIndex}` (index, cells).
4. Lần chọn file sau sẽ **ghi đè** nội dung (cùng đường dẫn document).

---

## 3. Tóm tắt đường dẫn

| Thành phần   | Đường dẫn Firestore |
|--------------|----------------------|
| Meta         | `shops/{shopId}/kiotVietData/meta` |
| Một sheet    | `shops/{shopId}/kiotVietData/{sheetIndex}` |
| Một dòng     | `shops/{shopId}/kiotVietData/{sheetIndex}/rows/{rowIndex}` |

Rule: `match /kiotVietData/{docId}` và `match /rows/{rowId}` — chỉ owner shop đọc/ghi.

---

## 4. Hiển thị bảng và tìm kiếm

- **Hiển thị:** Đọc `meta` → doc sheet `0` (columnNames, rowCount) → subcollection `rows` có `index` và `cells`. Dùng `orderBy('index')` + `limit` để phân trang.
- **Tìm kiếm:** Firestore không hỗ trợ full-text. Cách dùng: load toàn bộ rows (theo lô 500), cache trong app, lọc client-side theo chuỗi tìm kiếm (bất kỳ ô nào chứa chuỗi). Cấu trúc document hiện tại (index + cells) phù hợp cho cách này.
