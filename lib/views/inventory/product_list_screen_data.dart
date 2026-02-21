import '../../models/product_model.dart';
import '../../models/category_model.dart';

/// Định nghĩa cột có thể hiển thị trong bảng sản phẩm.
class ProductColumnDef {
  final String id;
  final String label;
  final bool hasTotal;
  const ProductColumnDef(this.id, this.label, this.hasTotal);
}

/// Danh sách cột chuẩn cho bảng sản phẩm.
const List<ProductColumnDef> productColumnDefs = [
  ProductColumnDef('code', 'Mã hàng', false),
  ProductColumnDef('name', 'Tên hàng', false),
  ProductColumnDef('category', 'Nhóm hàng', false),
  ProductColumnDef('price', 'Giá bán', false),
  ProductColumnDef('cost', 'Giá vốn', false),
  ProductColumnDef('stock', 'Tồn kho', true),
  ProductColumnDef('customerOrder', 'Khách đặt', true),
  ProductColumnDef('createdAt', 'Thời gian tạo', false),
  ProductColumnDef('expiry', 'Dự kiến hết hàng', false),
  ProductColumnDef('isSellable', 'Đang bán', false),
];

/// Snapshot dữ liệu cho màn hình Danh sách sản phẩm (dùng chung Mobile/Desktop).
class ProductListSnapshot {
  const ProductListSnapshot({
    required this.filteredProducts,
    required this.selectedCategoryId,
    this.selectedProduct,
    required this.selectedStatus,
    required this.visibleColumns,
    required this.categories,
    required this.isLoading,
    this.errorMessage,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<ProductModel> filteredProducts;
  final String? selectedCategoryId;
  final ProductModel? selectedProduct;
  final String? selectedStatus;
  final Map<String, bool> visibleColumns;
  final List<CategoryModel> categories;
  final bool isLoading;
  final String? errorMessage;
  final bool hasMore;
  final bool isLoadingMore;
}
