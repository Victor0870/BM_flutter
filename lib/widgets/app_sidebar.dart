import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/routes.dart';
import '../controllers/auth_provider.dart';
import '../widgets/branch_selector_widget.dart';

/// Sidebar widget dùng chung cho desktop
class AppSidebar extends StatefulWidget {
  final String? activeRoute;
  final Function(String route, {String? routeName})? onMenuTap;

  const AppSidebar({
    super.key,
    this.activeRoute,
    this.onMenuTap,
  });

  @override
  State<AppSidebar> createState() => _AppSidebarState();
}

class _AppSidebarState extends State<AppSidebar> {
  bool _isOrdersExpanded = false;
  bool _isProductsExpanded = false;
  bool _isInventoryExpanded = false;
  bool _isSettingsExpanded = false;
  bool _isCustomersExpanded = false;
  bool _isStaffExpanded = false;
  bool _isReportsExpanded = false;
  
  // Track menu nào đang được chọn để highlight ngay khi bấm vào
  String? _selectedMenuGroup;

  @override
  void initState() {
    super.initState();
    _updateExpandedStates();
  }

  @override
  void didUpdateWidget(AppSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeRoute != widget.activeRoute) {
      _updateExpandedStates();
    }
  }

  void _updateExpandedStates() {
    final activeRoute = widget.activeRoute ?? '';

    // Reset tất cả, sau đó set đúng 1 nhóm tương ứng route hiện tại
    _isOrdersExpanded = false;
    _isProductsExpanded = false;
    _isInventoryExpanded = false;
    _isSettingsExpanded = false;
    _isCustomersExpanded = false;
    _isStaffExpanded = false;
    _isReportsExpanded = false;
    
    // Tự động mở menu Orders nếu đang ở route của submenu Orders
    if (activeRoute == AppRoutes.salesHistory ||
        activeRoute == AppRoutes.returnInvoice ||
        activeRoute == AppRoutes.cancelInvoice ||
        activeRoute == AppRoutes.electronicInvoice) {
      _isOrdersExpanded = true;
      _selectedMenuGroup = 'orders';
    }
    
    // Tự động mở menu Products nếu đang ở route của submenu Products
    if (activeRoute == AppRoutes.inventory ||
        activeRoute == AppRoutes.productGroup ||
        activeRoute == AppRoutes.serviceList ||
        activeRoute == AppRoutes.serviceGroup) {
      _isProductsExpanded = true;
      _selectedMenuGroup = 'products';
    }
    
    // Tự động mở menu Inventory nếu đang ở route của submenu Inventory
    if (activeRoute == AppRoutes.stockOverview ||
        activeRoute == AppRoutes.purchase ||
        activeRoute == AppRoutes.transferStock ||
        activeRoute == AppRoutes.adjustStock) {
      _isInventoryExpanded = true;
      _selectedMenuGroup = 'inventory';
    }

    // Tự động mở menu Khách hàng nếu đang ở route tương ứng
    if (activeRoute == AppRoutes.customerManagement ||
        activeRoute == AppRoutes.customerGroupManagement) {
      _isCustomersExpanded = true;
      _selectedMenuGroup = 'customers';
    }

    // Tự động mở menu Nhân viên nếu đang ở route tương ứng
    if (activeRoute == AppRoutes.employeeManagement ||
        activeRoute == AppRoutes.employeeGroupManagement) {
      _isStaffExpanded = true;
      _selectedMenuGroup = 'staff';
    }

    // Tự động mở menu Báo cáo nếu đang ở route tương ứng
    if (activeRoute == AppRoutes.reports ||
        activeRoute == AppRoutes.salesReport ||
        activeRoute == AppRoutes.profitReport ||
        activeRoute == AppRoutes.stockMovementReport ||
        activeRoute == AppRoutes.debtReport ||
        activeRoute == AppRoutes.salesReturnReport) {
      _isReportsExpanded = true;
      _selectedMenuGroup = 'reports';
    }

    // Tự động mở menu Cài đặt nếu đang ở route của submenu Settings
    if (activeRoute == AppRoutes.shopSettings ||
        activeRoute == AppRoutes.branchManagement ||
        activeRoute == AppRoutes.advancedSettings ||
        activeRoute == AppRoutes.appAccountSettings) {
      _isSettingsExpanded = true;
      _selectedMenuGroup = 'settings';
    }
  }

  void _collapseAllExcept(String menu) {
    _isOrdersExpanded = menu == 'orders' ? _isOrdersExpanded : false;
    _isProductsExpanded = menu == 'products' ? _isProductsExpanded : false;
    _isInventoryExpanded = menu == 'inventory' ? _isInventoryExpanded : false;
    _isSettingsExpanded = menu == 'settings' ? _isSettingsExpanded : false;
    _isCustomersExpanded = menu == 'customers' ? _isCustomersExpanded : false;
    _isStaffExpanded = menu == 'staff' ? _isStaffExpanded : false;
    _isReportsExpanded = menu == 'reports' ? _isReportsExpanded : false;
  }

  void _handleMenuTap(String route, {String? routeName}) {
    if (widget.onMenuTap != null) {
      widget.onMenuTap!(route, routeName: routeName);
    } else {
      if (route.isEmpty) return;
      Navigator.pushNamed(context, route);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Container(
        width: 320,
        decoration: const BoxDecoration(
          border: Border(
            right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
        ),
        child: Column(
          children: [
          // Logo và Branch Selector
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.blue.shade600,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'BizMate',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  // Branch Selector cho desktop
                  Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      if (authProvider.user == null) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const BranchSelectorWidget(
                            isCompact: false,
                            showLabel: true,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          // Menu Items
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                    _buildSidebarItem(
                      context,
                      icon: Icons.dashboard,
                      label: 'Tổng quan',
                      isActive: widget.activeRoute == AppRoutes.home,
                      onTap: () => _handleMenuTap(AppRoutes.home),
                    ),
                      const SizedBox(height: 4),
                      _buildOrdersMenu(context),
                      const SizedBox(height: 4),
                      _buildProductsMenu(context),
                      const SizedBox(height: 4),
                      _buildInventoryMenu(context),
                      const SizedBox(height: 4),
                      _buildCustomersMenu(context),
                      const SizedBox(height: 4),
                      _buildStaffMenu(context),
                      const SizedBox(height: 4),
                      _buildReportsMenu(context),
                      const SizedBox(height: 4),
                      _buildSettingsMenu(context),
                    ],
                  ),
                ),
              ),
            ),
          // Support Card
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  border: Border.all(color: Colors.blue.shade100),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CẦN HỖ TRỢ?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade600,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Liên hệ đội ngũ kỹ thuật ngay.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue.shade800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tính năng đang được phát triển')),
                        );
                      },
                      child: Row(
                        children: [
                          Text(
                            'Gửi yêu cầu',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_forward, size: 14, color: Colors.blue.shade700),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F172A) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? Colors.white : const Color(0xFF64748B),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersMenu(BuildContext context) {
    final activeRoute = widget.activeRoute ?? '';
    final bool isOrdersActive = _selectedMenuGroup == 'orders' ||
        activeRoute == AppRoutes.salesHistory ||
        activeRoute == AppRoutes.returnInvoice ||
        activeRoute == AppRoutes.cancelInvoice ||
        activeRoute == AppRoutes.electronicInvoice;
    
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              // Highlight menu ngay khi bấm vào
              _selectedMenuGroup = 'orders';
              
              if (!_isOrdersExpanded) {
                // Nếu chưa expand, expand và navigate đến route đầu tiên
                _isOrdersExpanded = true;
                _collapseAllExcept('orders');
                _handleMenuTap(AppRoutes.salesHistory);
              } else {
                // Nếu đã expand, chỉ collapse
                _isOrdersExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isOrdersActive ? const Color(0xFF0F172A) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.shopping_cart,
                  size: 18,
                  color: isOrdersActive ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Đơn hàng',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isOrdersActive ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Icon(
                  _isOrdersExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: isOrdersActive ? Colors.white : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_isOrdersExpanded) ...[
          const SizedBox(height: 4),
          _buildSubMenuItem(
            context,
            label: 'Hóa đơn bán hàng',
            isActive: activeRoute == AppRoutes.salesHistory,
            onTap: () => _handleMenuTap(AppRoutes.salesHistory),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Hóa đơn trả hàng',
            isActive: activeRoute == AppRoutes.returnInvoice,
            onTap: () => _handleMenuTap(AppRoutes.returnInvoice),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Hóa đơn hủy',
            isActive: activeRoute == AppRoutes.cancelInvoice,
            onTap: () => _handleMenuTap(AppRoutes.cancelInvoice),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Hóa đơn điện tử',
            isActive: activeRoute == AppRoutes.electronicInvoice,
            onTap: () => _handleMenuTap(AppRoutes.electronicInvoice),
          ),
        ],
      ],
    );
  }

  Widget _buildSubMenuItem(
    BuildContext context, {
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0F172A).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsMenu(BuildContext context) {
    final activeRoute = widget.activeRoute ?? '';
    final bool isProductsActive = _selectedMenuGroup == 'products' ||
        activeRoute == AppRoutes.inventory ||
        activeRoute == AppRoutes.productGroup ||
        activeRoute == AppRoutes.serviceList ||
        activeRoute == AppRoutes.serviceGroup;
    
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              // Highlight menu ngay khi bấm vào
              _selectedMenuGroup = 'products';
              
              if (!_isProductsExpanded) {
                // Nếu chưa expand, expand và navigate đến route đầu tiên
                _isProductsExpanded = true;
                _collapseAllExcept('products');
                _handleMenuTap(AppRoutes.inventory);
              } else {
                // Nếu đã expand, chỉ collapse
                _isProductsExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isProductsActive ? const Color(0xFF0F172A) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  size: 18,
                  color: isProductsActive ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Sản phẩm',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isProductsActive ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Icon(
                  _isProductsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: isProductsActive ? Colors.white : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_isProductsExpanded) ...[
          const SizedBox(height: 4),
          _buildSubMenuItem(
            context,
            label: 'Danh sách sản phẩm',
            isActive: activeRoute == AppRoutes.inventory,
            onTap: () => _handleMenuTap(AppRoutes.inventory),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Nhóm sản phẩm',
            isActive: activeRoute == AppRoutes.productGroup,
            onTap: () => _handleMenuTap(AppRoutes.productGroup),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Danh sách dịch vụ',
            isActive: activeRoute == AppRoutes.serviceList,
            onTap: () => _handleMenuTap(AppRoutes.serviceList),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Nhóm dịch vụ',
            isActive: activeRoute == AppRoutes.serviceGroup,
            onTap: () => _handleMenuTap(AppRoutes.serviceGroup),
          ),
        ],
      ],
    );
  }

  Widget _buildInventoryMenu(BuildContext context) {
    final activeRoute = widget.activeRoute ?? '';
    final bool isInventoryActive = _selectedMenuGroup == 'inventory' ||
        activeRoute == AppRoutes.stockOverview ||
        activeRoute == AppRoutes.purchase ||
        activeRoute == AppRoutes.transferStock ||
        activeRoute == AppRoutes.adjustStock;
    
    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              // Highlight menu ngay khi bấm vào
              _selectedMenuGroup = 'inventory';
              
              if (!_isInventoryExpanded) {
                // Nếu chưa expand, expand và navigate đến route đầu tiên
                _isInventoryExpanded = true;
                _collapseAllExcept('inventory');
                _handleMenuTap(AppRoutes.stockOverview);
              } else {
                // Nếu đã expand, chỉ collapse
                _isInventoryExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isInventoryActive ? const Color(0xFF0F172A) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warehouse,
                  size: 18,
                  color: isInventoryActive ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quản lý kho',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isInventoryActive ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Icon(
                  _isInventoryExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: isInventoryActive ? Colors.white : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_isInventoryExpanded) ...[
          const SizedBox(height: 4),
          _buildSubMenuItem(
            context,
            label: 'Tồn kho',
            isActive: activeRoute == AppRoutes.stockOverview,
            onTap: () => _handleMenuTap(AppRoutes.stockOverview),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Nhập kho',
            isActive: activeRoute == AppRoutes.purchase,
            onTap: () => _handleMenuTap(AppRoutes.purchase),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Chuyển kho',
            isActive: activeRoute == AppRoutes.transferStock,
            onTap: () => _handleMenuTap(AppRoutes.transferStock),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Điều chỉnh kho',
            isActive: activeRoute == AppRoutes.adjustStock,
            onTap: () => _handleMenuTap(AppRoutes.adjustStock),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomersMenu(BuildContext context) {
    final activeRoute = widget.activeRoute ?? '';
    final bool isCustomersActive = _selectedMenuGroup == 'customers' ||
        activeRoute == AppRoutes.customerManagement ||
        activeRoute == AppRoutes.customerGroupManagement;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              // Highlight menu ngay khi bấm vào
              _selectedMenuGroup = 'customers';
              
              if (!_isCustomersExpanded) {
                // Nếu chưa expand, expand và navigate đến route đầu tiên
                _isCustomersExpanded = true;
                _collapseAllExcept('customers');
                _handleMenuTap(AppRoutes.customerManagement);
              } else {
                // Nếu đã expand, chỉ collapse
                _isCustomersExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isCustomersActive ? const Color(0xFF0F172A) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.people,
                  size: 18,
                  color: isCustomersActive ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Khách hàng',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isCustomersActive ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Icon(
                  _isCustomersExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: isCustomersActive ? Colors.white : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_isCustomersExpanded) ...[
          const SizedBox(height: 4),
          _buildSubMenuItem(
            context,
            label: 'Danh sách khách hàng',
            isActive: activeRoute == AppRoutes.customerManagement,
            onTap: () => _handleMenuTap(AppRoutes.customerManagement),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Nhóm khách hàng',
            isActive: activeRoute == AppRoutes.customerGroupManagement,
            onTap: () => _handleMenuTap(AppRoutes.customerGroupManagement),
          ),
        ],
      ],
    );
  }

  Widget _buildStaffMenu(BuildContext context) {
    final activeRoute = widget.activeRoute ?? '';
    final bool isStaffActive = _selectedMenuGroup == 'staff' ||
        activeRoute == AppRoutes.employeeManagement ||
        activeRoute == AppRoutes.employeeGroupManagement;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              // Highlight menu ngay khi bấm vào
              _selectedMenuGroup = 'staff';
              
              if (!_isStaffExpanded) {
                // Nếu chưa expand, expand và navigate đến route đầu tiên
                _isStaffExpanded = true;
                _collapseAllExcept('staff');
                _handleMenuTap(AppRoutes.employeeManagement);
              } else {
                // Nếu đã expand, chỉ collapse
                _isStaffExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isStaffActive ? const Color(0xFF0F172A) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.badge,
                  size: 18,
                  color: isStaffActive ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Quản lý nhân viên',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isStaffActive ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Icon(
                  _isStaffExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: isStaffActive ? Colors.white : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_isStaffExpanded) ...[
          const SizedBox(height: 4),
          _buildSubMenuItem(
            context,
            label: 'Danh sách nhân viên',
            isActive: activeRoute == AppRoutes.employeeManagement,
            onTap: () => _handleMenuTap(AppRoutes.employeeManagement),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Nhóm nhân viên',
            isActive: activeRoute == AppRoutes.employeeGroupManagement,
            onTap: () => _handleMenuTap(AppRoutes.employeeGroupManagement),
          ),
        ],
      ],
    );
  }

  Widget _buildReportsMenu(BuildContext context) {
    final activeRoute = widget.activeRoute ?? '';
    final bool isReportsActive = _selectedMenuGroup == 'reports' ||
        activeRoute == AppRoutes.reports ||
        activeRoute == AppRoutes.salesReport ||
        activeRoute == AppRoutes.profitReport ||
        activeRoute == AppRoutes.stockMovementReport ||
        activeRoute == AppRoutes.debtReport ||
        activeRoute == AppRoutes.salesReturnReport;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              // Highlight menu ngay khi bấm vào
              _selectedMenuGroup = 'reports';
              
              if (!_isReportsExpanded) {
                // Nếu chưa expand, expand và navigate đến route đầu tiên
                _isReportsExpanded = true;
                _collapseAllExcept('reports');
                _handleMenuTap(AppRoutes.salesReport);
              } else {
                // Nếu đã expand, chỉ collapse
                _isReportsExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isReportsActive ? const Color(0xFF0F172A) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  size: 18,
                  color: isReportsActive ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Báo cáo',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isReportsActive ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Icon(
                  _isReportsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: isReportsActive ? Colors.white : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_isReportsExpanded) ...[
          const SizedBox(height: 4),
          _buildSubMenuItem(
            context,
            label: 'Báo cáo doanh số',
            isActive: activeRoute == AppRoutes.salesReport,
            onTap: () => _handleMenuTap(AppRoutes.salesReport),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Báo cáo lợi nhuận',
            isActive: activeRoute == AppRoutes.profitReport,
            onTap: () => _handleMenuTap(AppRoutes.profitReport),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Báo cáo nhập xuất tồn',
            isActive: activeRoute == AppRoutes.stockMovementReport,
            onTap: () => _handleMenuTap(AppRoutes.stockMovementReport),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Báo cáo công nợ',
            isActive: activeRoute == AppRoutes.debtReport,
            onTap: () => _handleMenuTap(AppRoutes.debtReport),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Báo cáo hàng trả',
            isActive: activeRoute == AppRoutes.salesReturnReport,
            onTap: () => _handleMenuTap(AppRoutes.salesReturnReport),
          ),
        ],
      ],
    );
  }

  Widget _buildSettingsMenu(BuildContext context) {
    final activeRoute = widget.activeRoute ?? '';
    final bool isSettingsActive = _selectedMenuGroup == 'settings' ||
        activeRoute == AppRoutes.shopSettings ||
        activeRoute == AppRoutes.branchManagement ||
        activeRoute == AppRoutes.advancedSettings ||
        activeRoute == AppRoutes.appAccountSettings;

    return Column(
      children: [
        InkWell(
          onTap: () {
            setState(() {
              // Highlight menu ngay khi bấm vào
              _selectedMenuGroup = 'settings';
              
              if (!_isSettingsExpanded) {
                // Nếu chưa expand, expand và navigate đến route đầu tiên
                _isSettingsExpanded = true;
                _collapseAllExcept('settings');
                _handleMenuTap(AppRoutes.shopSettings);
              } else {
                // Nếu đã expand, chỉ collapse
                _isSettingsExpanded = false;
              }
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSettingsActive ? const Color(0xFF0F172A) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.settings,
                  size: 18,
                  color: isSettingsActive ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cài đặt',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSettingsActive ? Colors.white : const Color(0xFF64748B),
                    ),
                  ),
                ),
                Icon(
                  _isSettingsExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: isSettingsActive ? Colors.white : const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),
        if (_isSettingsExpanded) ...[
          const SizedBox(height: 4),
          _buildSubMenuItem(
            context,
            label: 'Thông tin cửa hàng',
            isActive: activeRoute == AppRoutes.shopSettings,
            onTap: () => _handleMenuTap(AppRoutes.shopSettings),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Chi nhánh',
            isActive: activeRoute == AppRoutes.branchManagement,
            onTap: () => _handleMenuTap(AppRoutes.branchManagement),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Hóa đơn điện tử',
            isActive: false, // chia sẻ cùng màn với Thông tin cửa hàng
            onTap: () => _handleMenuTap(AppRoutes.shopSettings),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Tính năng nâng cao',
            isActive: activeRoute == AppRoutes.advancedSettings,
            onTap: () => _handleMenuTap(AppRoutes.advancedSettings),
          ),
          const SizedBox(height: 2),
          _buildSubMenuItem(
            context,
            label: 'Tài khoản app',
            isActive: activeRoute == AppRoutes.appAccountSettings,
            onTap: () => _handleMenuTap(AppRoutes.appAccountSettings),
          ),
        ],
      ],
    );
  }
}
