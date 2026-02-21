# Cấu trúc dự án Flutter POS (Point of Sale)

Dự án này sử dụng Clean Architecture với Provider pattern để quản lý state.

## Cấu trúc thư mục

```
lib/
├── core/           # Core functionality (constants, themes, routes, etc.)
├── models/         # Data models (entities)
├── services/       # Services layer (Firebase, API, local storage)
├── controllers/    # State management (Providers/Controllers)
├── views/          # UI Screens/Pages
├── widgets/        # Reusable UI components
├── utils/          # Utility functions (helpers, validators, etc.)
└── main.dart       # Entry point của ứng dụng
```

## Mô tả các thư mục

### `models/`
Chứa các data models/entities của ứng dụng. Ví dụ:
- `product_model.dart` - Model cho sản phẩm
- `invoice_model.dart` - Model cho hóa đơn
- `customer_model.dart` - Model cho khách hàng
- `order_model.dart` - Model cho đơn hàng

### `services/`
Chứa các service classes để tương tác với:
- Firebase (Authentication, Firestore)
- API endpoints
- Local storage (SharedPreferences, Hive, etc.)
- External services

Ví dụ:
- `firebase_service.dart` - Xử lý Firebase operations
- `auth_service.dart` - Xử lý authentication
- `product_service.dart` - CRUD operations cho products

### `controllers/`
Chứa các Provider classes hoặc Controllers để quản lý state và business logic.
Sử dụng Provider package để quản lý state.

Ví dụ:
- `auth_controller.dart` - Quản lý authentication state
- `product_controller.dart` - Quản lý product state
- `cart_controller.dart` - Quản lý giỏ hàng

### `views/`
Chứa các screen/page widgets của ứng dụng.

#### Quy tắc 3 tệp cho màn hình phức tạp (responsive)
Mọi màn hình phức tạp (có layout khác biệt rõ ràng giữa điện thoại và màn hình rộng) **bắt buộc** tách thành 3 tệp:

1. **`xxx_screen.dart`** — Tệp điều phối chính (Router / Responsive switch)
   - Chỉ chứa logic chung (state, load data, callbacks) và `build()` chọn hiển thị Mobile hoặc Desktop theo platform.
   - Sử dụng `lib/utils/platform_utils.dart` (`isMobilePlatform` / `isDesktopPlatform`) để quyết định, không viết `if/else` thủ công phân nhánh UI trong file này.

2. **`xxx_screen_mobile.dart`** — Giao diện tối ưu cho điện thoại
   - Thường dùng ListView, Card, bottom sheet, tab dưới.
   - Chỉ chứa UI và logic hiển thị cho mobile; không ảnh hưởng layout desktop.

3. **`xxx_screen_desktop.dart`** — Giao diện tối ưu cho màn hình rộng
   - Thường dùng DataTable, Sidebar, layout 2 cột.
   - Chỉ chứa UI và logic hiển thị cho desktop; không ảnh hưởng layout mobile.

**Điều hướng:** Luôn dùng `platform_utils.dart` để kiểm tra nền tảng thay vì viết `if (Platform.isAndroid || ...)` trong tệp UI.

**Tính độc lập:** Tuyệt đối không sửa logic UI trong tệp Mobile mà làm ảnh hưởng layout Desktop và ngược lại.

Ví dụ đã áp dụng: `home_screen.dart` + `home_screen_mobile.dart` + `home_screen_desktop.dart`, `auth_screen.dart` + `auth_screen_mobile.dart` + `auth_screen_desktop.dart`, `splash_screen.dart` + `splash_screen_mobile.dart` + `splash_screen_desktop.dart`.

Ví dụ chung:
- `login_screen.dart`
- `home_screen.dart` (router) + `home_screen_mobile.dart` + `home_screen_desktop.dart`
- `products_screen.dart` / `pos_screen.dart` - Màn hình bán hàng (POS)
- `inventory_screen.dart` - Màn hình quản lý kho

### `widgets/`
Chứa các reusable widgets được sử dụng trong nhiều màn hình.

Ví dụ:
- `custom_button.dart`
- `product_card.dart`
- `loading_indicator.dart`

### `core/`
Chứa các file core của ứng dụng:
- `constants.dart` - Constants
- `theme.dart` - Theme configuration
- `routes.dart` - Route definitions
- `app_config.dart` - App configuration

### `utils/`
Chứa các utility functions và helpers:
- `validators.dart` - Input validators
- `formatters.dart` - Data formatters
- `helpers.dart` - Helper functions

## Dependencies chính

- **firebase_core**: Firebase initialization
- **firebase_auth**: Firebase Authentication
- **cloud_firestore**: Cloud Firestore database
- **provider**: State management
- **intl**: Internationalization và formatting
- **google_fonts**: Google Fonts

