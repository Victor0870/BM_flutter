import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/product_model.dart';
import '../models/sale_model.dart';
import '../views/common/feature_coming_soon_screen.dart';
import '../views/customers/customer_group_management_screen.dart';
import '../views/customers/customer_management_screen.dart';
import '../views/home_screen.dart';
import '../views/inventory/branch_management_screen.dart';
import '../views/inventory/product_form_screen.dart';
import '../views/inventory/product_list_screen.dart';
import '../views/inventory/purchase_history_screen.dart';
import '../views/inventory/purchase_screen.dart';
import '../views/inventory/stock_overview_screen.dart';
import '../views/inventory/inventory_report_screen.dart';
import '../views/sales/sale_detail_screen.dart';
import '../views/sales/sales_history_screen.dart';
import '../views/sales/sales_screen.dart';
import '../views/sales/sales_return_form_screen.dart';
import '../views/sales/einvoice_management_screen.dart';
import '../views/reports/sales_return_report_screen.dart';
import '../views/settings/shop_settings_screen.dart';
import '../views/employees/employee_management_screen.dart';
import '../widgets/app_sidebar.dart';

/// Định nghĩa routes cho ứng dụng
class AppRoutes {
  static const String home = '/';
  static const String inventory = '/inventory';
  static const String productForm = '/product-form';
  static const String sales = '/sales';
  static const String salesHistory = '/sales-history';
  static const String shopSettings = '/shop-settings';
  static const String purchase = '/purchase';
  static const String stockOverview = '/stock-overview';
  static const String inventoryReport = '/inventory-report';
  static const String purchaseHistory = '/purchase-history';
  static const String branchManagement = '/branch-management';
  static const String customerManagement = '/customer-management';
  static const String customerGroupManagement = '/customer-group-management';
  static const String saleDetail = '/sale-detail';
  // Placeholder / coming soon feature routes (used chủ yếu cho Sidebar trên desktop)
  static const String reports = '/reports';
  static const String returnInvoice = '/return-invoice';
  static const String cancelInvoice = '/cancel-invoice';
  static const String electronicInvoice = '/electronic-invoice';
  static const String productGroup = '/product-group';
  static const String serviceList = '/service-list';
  static const String serviceGroup = '/service-group';
  static const String transferStock = '/transfer-stock';
  static const String adjustStock = '/adjust-stock';
  // Settings-related placeholder routes
  static const String advancedSettings = '/settings-advanced';
  static const String appAccountSettings = '/settings-app-account';
  // Employee management placeholder routes
  static const String employeeManagement = '/employee-management';
  static const String employeeGroupManagement = '/employee-group-management';
  // Reports placeholder routes
  static const String salesReport = '/report-sales';
  static const String profitReport = '/report-profit';
    static const String stockMovementReport = '/report-stock-movement';
    static const String debtReport = '/report-debt';
    static const String salesReturnReport = '/report-sales-return';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    final bool isDesktop =
        !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

    Widget buildContent() {
      switch (settings.name) {
        case home:
          return const HomeScreen();
        case inventory:
          return const ProductListScreen();
        case productForm:
          final product = settings.arguments as ProductModel?;
          return ProductFormScreen(product: product);
        case sales:
          return const SalesScreen();
        case salesHistory:
          return const SalesHistoryScreen();
        case shopSettings:
          return const ShopSettingsScreen();
        case purchase:
          return const PurchaseScreen();
        case stockOverview:
          return const StockOverviewScreen();
        case inventoryReport:
          return const InventoryReportScreen();
        case purchaseHistory:
          return const PurchaseHistoryScreen();
        case branchManagement:
          return const BranchManagementScreen();
        case customerManagement:
          return const CustomerManagementScreen();
        case customerGroupManagement:
          return const CustomerGroupManagementScreen();
        case saleDetail:
          final sale = settings.arguments as SaleModel;
          return SaleDetailScreen(sale: sale);
        // Các route placeholder hiển thị màn hình \"Tính năng đang phát triển\"
        case reports:
          return const FeatureComingSoonScreen(title: 'Báo cáo tổng quan');
        case returnInvoice:
          return const SalesReturnFormScreen();
        case cancelInvoice:
          return const FeatureComingSoonScreen(title: 'Hóa đơn hủy');
        case electronicInvoice:
          return const EinvoiceManagementScreen();
        case productGroup:
          return const FeatureComingSoonScreen(title: 'Nhóm sản phẩm');
        case serviceList:
          return const FeatureComingSoonScreen(title: 'Danh sách dịch vụ');
        case serviceGroup:
          return const FeatureComingSoonScreen(title: 'Nhóm dịch vụ');
        case transferStock:
          return const FeatureComingSoonScreen(title: 'Chuyển kho');
        case adjustStock:
          return const FeatureComingSoonScreen(title: 'Điều chỉnh kho');
        case advancedSettings:
          return const FeatureComingSoonScreen(title: 'Tính năng nâng cao');
        case appAccountSettings:
          return const FeatureComingSoonScreen(title: 'Tài khoản ứng dụng');
        case employeeManagement:
          return const EmployeeManagementScreen();
        case employeeGroupManagement:
          return const FeatureComingSoonScreen(title: 'Nhóm nhân viên');
        case salesReport:
          return const FeatureComingSoonScreen(title: 'Báo cáo doanh số');
        case profitReport:
          return const FeatureComingSoonScreen(title: 'Báo cáo lợi nhuận');
        case stockMovementReport:
          return const InventoryReportScreen(); // Sử dụng màn hình báo cáo mới
        case debtReport:
          return const FeatureComingSoonScreen(title: 'Báo cáo công nợ');
        case salesReturnReport:
          return const SalesReturnReportScreen();
        default:
          return const Scaffold(
            body: Center(
              child: Text('Page not found'),
            ),
          );
      }
    }

    // Desktop: dùng PageRouteBuilder không animation, và chỉ bọc Sidebar cho
    // các màn hình ngoại trừ màn hình bán hàng (POS) để POS full-screen.
    if (isDesktop) {
      return PageRouteBuilder(
        settings: settings,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) {
          final Widget content = buildContent();

          // Màn bán hàng và các màn detail: không có sidebar, hiển thị full-screen
          if (settings.name == sales || settings.name == saleDetail) {
            return content;
          }

          final String activeRoute = settings.name ?? '';

          return Row(
            children: [
              AppSidebar(
                activeRoute: activeRoute,
                onMenuTap: (route, {String? routeName}) {
                  if (route.isEmpty || route == activeRoute) return;
                  Navigator.pushReplacementNamed(context, route);
                },
              ),
              Expanded(child: content),
            ],
          );
        },
      );
    }

    // Mobile/Web: giữ nguyên MaterialPageRoute với animation mặc định
    return MaterialPageRoute(
      settings: settings,
      builder: (context) => buildContent(),
    );
  }
}

