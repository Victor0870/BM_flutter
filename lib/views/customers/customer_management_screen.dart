import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../controllers/customer_provider.dart';
import '../../models/customer_model.dart';
import '../../models/customer_group_model.dart';
import '../../utils/platform_utils.dart';
import '../../core/routes.dart';
import 'customer_management_screen_data.dart';
import 'customer_management_screen_mobile.dart';
import 'customer_management_screen_desktop.dart';
import 'customer_filter_screen.dart';
import 'customer_form_screen.dart';
import 'customer_edit_dialog.dart';
import 'import_customer_dialog.dart';

/// Màn hình quản lý khách hàng (mobile/desktop theo platform).
/// Tệp điều phối — chọn giao diện Mobile hoặc Desktop theo platform.
class CustomerManagementScreen extends StatefulWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const CustomerManagementScreen({super.key, this.forceMobile});

  @override
  State<CustomerManagementScreen> createState() => _CustomerManagementScreenState();
}

class _CustomerManagementScreenState extends State<CustomerManagementScreen> {
  bool get _useMobileLayout => widget.forceMobile ?? isMobilePlatform;

  final TextEditingController _searchController = TextEditingController();
  String? _selectedGroupId;
  CustomerModel? _selectedCustomer;

  // Sidebar filter state (desktop)
  String? _filterBranchId;
  DateTime? _filterCreatedAtFrom;
  DateTime? _filterCreatedAtTo;
  int _filterGender = 0;
  DateTime? _filterBirthDateFrom;
  DateTime? _filterBirthDateTo;
  String _filterTotalSalesFromText = '';
  String _filterTotalSalesToText = '';
  String _filterDebtFromText = '';
  String _filterDebtToText = '';
  String _filterDeliveryArea = '';
  int _filterStatus = 1;

  late Map<String, bool> _visibleColumns;

  @override
  void initState() {
    super.initState();
    _visibleColumns = {
      for (final def in customerColumnDefs)
        def.id: def.id == 'code' || def.id == 'name' || def.id == 'phone' ||
            def.id == 'totalDebt' || def.id == 'totalInvoiced' || def.id == 'totalRevenue',
    };
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customerProvider = context.read<CustomerProvider>();
      customerProvider.loadCustomers();
      customerProvider.loadCustomerGroups();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatPrice(double price) {
    return price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  void _showColumnPicker() async {
    final result = await showDialog<Map<String, bool>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CustomerColumnPickerDialog(
        visibleColumns: Map.of(_visibleColumns),
        columnDefs: customerColumnDefs,
      ),
    );
    if (result != null && mounted) {
      setState(() => _visibleColumns = result);
    }
  }

  String _getCellValue(CustomerModel c, CustomerGroupModel? group, String columnId) {
    switch (columnId) {
      case 'code': return c.code ?? c.id;
      case 'name': return c.name;
      case 'customerType': return '—';
      case 'phone': return c.phone;
      case 'groupName': return group?.name ?? '—';
      case 'gender': return c.gender == null ? '—' : (c.gender! ? 'Nam' : 'Nữ');
      case 'birthDate': return c.birthDate != null ? DateFormat('dd/MM/yyyy').format(c.birthDate!) : '—';
      case 'email': return c.email ?? '—';
      case 'facebook': return '—';
      case 'organization': return c.organization ?? '—';
      case 'taxCode': return c.taxCode ?? '—';
      case 'idCard': return '—';
      case 'address': return c.address ?? '—';
      case 'deliveryArea': return c.locationName ?? '—';
      case 'wardName': return c.wardName ?? '—';
      case 'createdBy': return '—';
      case 'createdAt': return c.createdAt != null ? DateFormat('dd/MM/yyyy').format(c.createdAt!) : '—';
      case 'comments': return c.comments ?? '—';
      case 'lastTransactionDate': return '—';
      case 'createdBranch': return '—';
      case 'totalDebt': return _formatPrice(c.totalDebt);
      case 'totalInvoiced': return _formatPrice(c.totalInvoiced ?? c.totalRevenue);
      case 'currentPoints': return '—';
      case 'totalPoints': return '—';
      case 'totalRevenue': return _formatPrice(c.totalRevenue);
      case 'status': return '—';
      default: return '—';
    }
  }

  bool _isNumericColumn(String columnId) {
    return columnId == 'totalDebt' || columnId == 'totalInvoiced' || columnId == 'totalRevenue';
  }

  List<CustomerModel> _applySidebarFilters(List<CustomerModel> list) {
    var result = list;
    if (_filterCreatedAtFrom != null) {
      result = result.where((c) => c.createdAt != null && !c.createdAt!.isBefore(_filterCreatedAtFrom!)).toList();
    }
    if (_filterCreatedAtTo != null) {
      final end = DateTime(_filterCreatedAtTo!.year, _filterCreatedAtTo!.month, _filterCreatedAtTo!.day, 23, 59, 59);
      result = result.where((c) => c.createdAt != null && !c.createdAt!.isAfter(end)).toList();
    }
    if (_filterGender == 1) {
      result = result.where((c) => c.gender == true).toList();
    } else if (_filterGender == 2) {
      result = result.where((c) => c.gender == false).toList();
    }
    if (_filterBirthDateFrom != null) {
      result = result.where((c) => c.birthDate != null && !c.birthDate!.isBefore(_filterBirthDateFrom!)).toList();
    }
    if (_filterBirthDateTo != null) {
      final end = DateTime(_filterBirthDateTo!.year, _filterBirthDateTo!.month, _filterBirthDateTo!.day, 23, 59, 59);
      result = result.where((c) => c.birthDate != null && !c.birthDate!.isAfter(end)).toList();
    }
    final totalSalesFrom = double.tryParse(_filterTotalSalesFromText.replaceAll(',', ''));
    final totalSalesTo = double.tryParse(_filterTotalSalesToText.replaceAll(',', ''));
    if (totalSalesFrom != null && totalSalesFrom > 0) {
      result = result.where((c) => (c.totalInvoiced ?? c.totalRevenue) >= totalSalesFrom).toList();
    }
    if (totalSalesTo != null && totalSalesTo > 0) {
      result = result.where((c) => (c.totalInvoiced ?? c.totalRevenue) <= totalSalesTo).toList();
    }
    final debtFrom = double.tryParse(_filterDebtFromText.replaceAll(',', ''));
    final debtTo = double.tryParse(_filterDebtToText.replaceAll(',', ''));
    if (debtFrom != null && debtFrom > 0) {
      result = result.where((c) => c.totalDebt >= debtFrom).toList();
    }
    if (debtTo != null && debtTo > 0) {
      result = result.where((c) => c.totalDebt <= debtTo).toList();
    }
    if (_filterDeliveryArea.trim().isNotEmpty) {
      final q = _filterDeliveryArea.trim().toLowerCase();
      result = result.where((c) => (c.locationName ?? '').toLowerCase().contains(q)).toList();
    }
    return result;
  }

  CustomerManagementSnapshot _buildSnapshot() {
    final customerProvider = context.read<CustomerProvider>();
    var filteredCustomers = customerProvider.customers;

    final searchQuery = _searchController.text.trim().toLowerCase();
    if (searchQuery.isNotEmpty) {
      filteredCustomers = filteredCustomers.where((c) {
        final code = (c.code ?? '').toLowerCase();
        return c.name.toLowerCase().contains(searchQuery) ||
            c.phone.contains(searchQuery) ||
            code.contains(searchQuery);
      }).toList();
    }
    if (_selectedGroupId != null) {
      filteredCustomers = filteredCustomers.where((c) => c.groupId == _selectedGroupId).toList();
    }
    filteredCustomers = _applySidebarFilters(filteredCustomers);

    return CustomerManagementSnapshot(
      filteredCustomers: filteredCustomers,
      selectedGroupId: _selectedGroupId,
      selectedCustomer: _selectedCustomer,
      visibleColumns: _visibleColumns,
      customerGroups: customerProvider.customerGroups,
      isLoading: customerProvider.isLoading,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý khách hàng'),
        actions: [
          if (_useMobileLayout)
            IconButton(
              icon: const Icon(Icons.filter_list_rounded),
              onPressed: () async {
                final customerProvider = context.read<CustomerProvider>();
                final result = await Navigator.push<CustomerFilterResult>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CustomerFilterScreen(
                      initialGroupId: _selectedGroupId,
                      initialGender: _filterGender,
                      initialBirthDateFrom: _filterBirthDateFrom,
                      initialBirthDateTo: _filterBirthDateTo,
                      initialCreatedAtFrom: _filterCreatedAtFrom,
                      initialCreatedAtTo: _filterCreatedAtTo,
                      initialTotalSalesFromText: _filterTotalSalesFromText,
                      initialTotalSalesToText: _filterTotalSalesToText,
                      initialDebtFromText: _filterDebtFromText,
                      initialDebtToText: _filterDebtToText,
                      initialStatus: _filterStatus,
                      customerGroups: customerProvider.customerGroups,
                    ),
                  ),
                );
                if (result != null && mounted) {
                  setState(() {
                    _selectedGroupId = result.groupId;
                    _filterGender = result.gender;
                    _filterBirthDateFrom = result.birthDateFrom;
                    _filterBirthDateTo = result.birthDateTo;
                    _filterCreatedAtFrom = result.createdAtFrom;
                    _filterCreatedAtTo = result.createdAtTo;
                    _filterTotalSalesFromText = result.totalSalesFromText;
                    _filterTotalSalesToText = result.totalSalesToText;
                    _filterDebtFromText = result.debtFromText;
                    _filterDebtToText = result.debtToText;
                    _filterStatus = result.status;
                  });
                }
              },
              tooltip: 'Bộ lọc',
            ),
          if (!_useMobileLayout)
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: () async {
                final provider = context.read<CustomerProvider>();
                final ok = await ImportCustomerDialog.show(context);
                if (!mounted) return;
                if (ok == true) {
                  provider.loadCustomers();
                }
              },
              tooltip: 'Import khách hàng từ Excel',
            ),
          IconButton(
            icon: const Icon(Icons.group),
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.customerGroupManagement);
            },
            tooltip: 'Quản lý nhóm khách hàng',
          ),
        ],
      ),
      body: Consumer<CustomerProvider>(
        builder: (context, customerProvider, _) {
          final snapshot = _buildSnapshot();
          if (_useMobileLayout) {
            return CustomerManagementScreenMobile(
              snapshot: snapshot,
              searchController: _searchController,
              onSearchChanged: (_) => setState(() {}),
              onGroupChanged: (v) => setState(() => _selectedGroupId = v),
              formatPrice: _formatPrice,
              onEdit: (customer) async {
                final updated = await CustomerEditDialog.show(context, customer);
                if (mounted && updated != null) {
                  await customerProvider.loadCustomers();
                }
              },
            );
          }
          return CustomerManagementScreenDesktop(
            snapshot: snapshot,
            searchController: _searchController,
            onSearchChanged: (_) => setState(() {}),
            onGroupChanged: (v) => setState(() => _selectedGroupId = v),
            onShowColumnPicker: _showColumnPicker,
            onRefresh: () async => await customerProvider.loadCustomers(),
            onCustomerSelected: (c) => setState(() => _selectedCustomer = c),
            onEdit: () async {
              if (_selectedCustomer == null) return;
              final updated = await CustomerEditDialog.show(context, _selectedCustomer!);
              await customerProvider.loadCustomers();
              if (mounted && updated != null) {
                setState(() => _selectedCustomer = updated);
              }
            },
            formatPrice: _formatPrice,
            getCellValue: _getCellValue,
            isNumericColumn: _isNumericColumn,
            filterBranchId: _filterBranchId,
            onBranchChanged: (v) => setState(() => _filterBranchId = v),
            filterCreatedAtFrom: _filterCreatedAtFrom,
            filterCreatedAtTo: _filterCreatedAtTo,
            onCreatedAtChanged: (from, to) => setState(() {
              _filterCreatedAtFrom = from;
              _filterCreatedAtTo = to;
            }),
            filterGender: _filterGender,
            onGenderChanged: (v) => setState(() => _filterGender = v),
            filterBirthDateFrom: _filterBirthDateFrom,
            filterBirthDateTo: _filterBirthDateTo,
            onBirthDateChanged: (from, to) => setState(() {
              _filterBirthDateFrom = from;
              _filterBirthDateTo = to;
            }),
            filterTotalSalesFromText: _filterTotalSalesFromText,
            filterTotalSalesToText: _filterTotalSalesToText,
            onTotalSalesTextChanged: (from, to) => setState(() {
              _filterTotalSalesFromText = from;
              _filterTotalSalesToText = to;
            }),
            filterDebtFromText: _filterDebtFromText,
            filterDebtToText: _filterDebtToText,
            onDebtTextChanged: (from, to) => setState(() {
              _filterDebtFromText = from;
              _filterDebtToText = to;
            }),
            filterDeliveryArea: _filterDeliveryArea,
            onDeliveryAreaChanged: (v) => setState(() => _filterDeliveryArea = v),
            filterStatus: _filterStatus,
            onStatusChanged: (v) => setState(() => _filterStatus = v),
            onReset: () => setState(() {
              _selectedGroupId = null;
              _filterBranchId = null;
              _filterCreatedAtFrom = null;
              _filterCreatedAtTo = null;
              _filterGender = 0;
              _filterBirthDateFrom = null;
              _filterBirthDateTo = null;
              _filterTotalSalesFromText = '';
              _filterTotalSalesToText = '';
              _filterDebtFromText = '';
              _filterDebtToText = '';
              _filterDeliveryArea = '';
              _filterStatus = 1;
            }),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CustomerFormScreen(forceMobile: _useMobileLayout),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
