import '../models/employee_group_model.dart';
import 'routes.dart';

/// Ánh xạ route -> quyền tối thiểu cần có để truy cập.
/// Dùng cho Sidebar (ẩn mục) và Routes (chặn truy cập).
class PermissionRoutes {
  PermissionRoutes._();

  static const String _noPermission = '__none__';

  static final Map<String, String> routeToPermission = {
    AppRoutes.home: _noPermission, // Ai cũng vào được
    AppRoutes.sales: EmployeePermissions.createSale,
    AppRoutes.salesHistory: EmployeePermissions.viewSales,
    AppRoutes.returnInvoice: EmployeePermissions.viewSales,
    AppRoutes.cancelInvoice: EmployeePermissions.viewInvoices,
    AppRoutes.electronicInvoice: EmployeePermissions.viewInvoices,
    AppRoutes.inventory: EmployeePermissions.viewInventory,
    AppRoutes.productForm: EmployeePermissions.manageInventory,
    AppRoutes.productGroup: EmployeePermissions.viewInventory,
    AppRoutes.serviceList: EmployeePermissions.viewInventory,
    AppRoutes.serviceGroup: EmployeePermissions.viewInventory,
    AppRoutes.stockOverview: EmployeePermissions.viewInventory,
    AppRoutes.purchase: EmployeePermissions.manageInventory,
    AppRoutes.suppliers: EmployeePermissions.manageInventory,
    AppRoutes.supplierForm: EmployeePermissions.manageInventory,
    AppRoutes.transferStock: EmployeePermissions.manageInventory,
    AppRoutes.adjustStock: EmployeePermissions.manageInventory,
    AppRoutes.inventoryReport: EmployeePermissions.viewReports,
    AppRoutes.purchaseHistory: EmployeePermissions.viewInventory,
    AppRoutes.branchManagement: EmployeePermissions.manageInventory,
    AppRoutes.customerManagement: EmployeePermissions.viewSales,
    AppRoutes.customerGroupManagement: EmployeePermissions.viewSales,
    AppRoutes.saleDetail: EmployeePermissions.viewSales,
    AppRoutes.reports: EmployeePermissions.viewReports,
    AppRoutes.salesReport: EmployeePermissions.viewReports,
    AppRoutes.profitReport: EmployeePermissions.viewReports,
    AppRoutes.stockMovementReport: EmployeePermissions.viewReports,
    AppRoutes.debtReport: EmployeePermissions.viewReports,
    AppRoutes.salesReturnReport: EmployeePermissions.viewReports,
    AppRoutes.lowStockReport: EmployeePermissions.viewReports,
    AppRoutes.expiryReport: EmployeePermissions.viewReports,
    AppRoutes.shopSettings: EmployeePermissions.shopSettings,
    AppRoutes.advancedSettings: EmployeePermissions.shopSettings,
    AppRoutes.appAccountSettings: EmployeePermissions.shopSettings,
    AppRoutes.employeeManagement: EmployeePermissions.manageEmployees,
    AppRoutes.employeeGroupManagement: EmployeePermissions.manageEmployees,
  };

  /// Kiểm tra route có cần quyền không (false = ai cũng vào được).
  static bool routeRequiresPermission(String? route) {
    if (route == null || route.isEmpty) return false;
    final perm = routeToPermission[route];
    return perm != null && perm != _noPermission;
  }

  /// Quyền cần có để vào route. Null hoặc _noPermission = không yêu cầu.
  static String? requiredPermissionForRoute(String? route) {
    if (route == null || route.isEmpty) return null;
    final perm = routeToPermission[route];
    if (perm == null || perm == _noPermission) return null;
    return perm;
  }
}
