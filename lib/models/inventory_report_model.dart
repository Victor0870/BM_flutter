import '../models/product_model.dart';

/// Model đại diện cho một dòng trong báo cáo Xuất - Nhập - Tồn
class InventoryReportItem {
  final ProductModel product;
  final String branchId;
  final double openingStock;    // Tồn đầu kỳ (tại startDate)
  final double incomingStock;   // Nhập trong kỳ (từ startDate đến endDate)
  final double outgoingStock;   // Xuất trong kỳ (từ startDate đến endDate)
  final double closingStock;    // Tồn cuối kỳ (tại endDate)

  InventoryReportItem({
    required this.product,
    required this.branchId,
    required this.openingStock,
    required this.incomingStock,
    required this.outgoingStock,
    required this.closingStock,
  });

  /// Tính toán tồn cuối kỳ dựa trên công thức: Tồn đầu kỳ + Nhập - Xuất
  /// (Hàm này chỉ để verify, vì closingStock được tính từ StockHistory)
  double get calculatedClosingStock => openingStock + incomingStock - outgoingStock;

  /// Chuyển đổi sang Map để hiển thị trong bảng
  Map<String, dynamic> toMap() {
    return {
      'productId': product.id,
      'productName': product.name,
      'branchId': branchId,
      'openingStock': openingStock,
      'incomingStock': incomingStock,
      'outgoingStock': outgoingStock,
      'closingStock': closingStock,
    };
  }
}

/// Model đại diện cho toàn bộ báo cáo Xuất - Nhập - Tồn
class InventoryReport {
  final DateTime startDate;
  final DateTime endDate;
  final String? branchId;
  final List<InventoryReportItem> items;

  InventoryReport({
    required this.startDate,
    required this.endDate,
    this.branchId,
    required this.items,
  });

  /// Tổng tồn đầu kỳ (tất cả sản phẩm)
  double get totalOpeningStock {
    return items.fold(0.0, (sum, item) => sum + item.openingStock);
  }

  /// Tổng nhập trong kỳ
  double get totalIncomingStock {
    return items.fold(0.0, (sum, item) => sum + item.incomingStock);
  }

  /// Tổng xuất trong kỳ
  double get totalOutgoingStock {
    return items.fold(0.0, (sum, item) => sum + item.outgoingStock);
  }

  /// Tổng tồn cuối kỳ
  double get totalClosingStock {
    return items.fold(0.0, (sum, item) => sum + item.closingStock);
  }
}
