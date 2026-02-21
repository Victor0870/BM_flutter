import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/customer_model.dart';
import '../../models/customer_group_model.dart';
import '../../controllers/customer_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../core/routes.dart';
import 'customer_management_screen_data.dart';

/// Popup chọn cột hiển thị trong bảng khách hàng.
class CustomerColumnPickerDialog extends StatefulWidget {
  final Map<String, bool> visibleColumns;
  final List<CustomerColumnDef> columnDefs;

  const CustomerColumnPickerDialog({
    super.key,
    required this.visibleColumns,
    required this.columnDefs,
  });

  @override
  State<CustomerColumnPickerDialog> createState() => _CustomerColumnPickerDialogState();
}

class _CustomerColumnPickerDialogState extends State<CustomerColumnPickerDialog> {
  late Map<String, bool> _visible;

  @override
  void initState() {
    super.initState();
    _visible = Map.of(widget.visibleColumns);
  }

  void _close() {
    Navigator.of(context).pop(_visible);
  }

  @override
  Widget build(BuildContext context) {
    const splitAt = 13;
    final left = widget.columnDefs.take(splitAt).toList();
    final right = widget.columnDefs.skip(splitAt).toList();

    return Dialog(
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Chọn cột hiển thị', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _close,
                  tooltip: 'Đóng',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: left.map((def) => CheckboxListTile(
                          value: _visible[def.id] ?? false,
                          onChanged: (v) => setState(() => _visible[def.id] = v ?? false),
                          title: Text(def.label, style: const TextStyle(fontSize: 14)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        )).toList(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: right.map((def) => CheckboxListTile(
                          value: _visible[def.id] ?? false,
                          onChanged: (v) => setState(() => _visible[def.id] = v ?? false),
                          title: Text(def.label, style: const TextStyle(fontSize: 14)),
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                        )).toList(),
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
}

/// Màn hình Quản lý khách hàng - giao diện Desktop.
class CustomerManagementScreenDesktop extends StatelessWidget {
  const CustomerManagementScreenDesktop({
    super.key,
    required this.snapshot,
    required this.searchController,
    required this.onSearchChanged,
    required this.onGroupChanged,
    required this.onShowColumnPicker,
    required this.onRefresh,
    required this.onCustomerSelected,
    required this.onEdit,
    required this.formatPrice,
    required this.getCellValue,
    required this.isNumericColumn,
    // Sidebar filter state
    required this.filterBranchId,
    required this.onBranchChanged,
    required this.filterCreatedAtFrom,
    required this.filterCreatedAtTo,
    required this.onCreatedAtChanged,
    required this.filterGender,
    required this.onGenderChanged,
    required this.filterBirthDateFrom,
    required this.filterBirthDateTo,
    required this.onBirthDateChanged,
    required this.filterTotalSalesFromText,
    required this.filterTotalSalesToText,
    required this.onTotalSalesTextChanged,
    required this.filterDebtFromText,
    required this.filterDebtToText,
    required this.onDebtTextChanged,
    required this.filterDeliveryArea,
    required this.onDeliveryAreaChanged,
    required this.filterStatus,
    required this.onStatusChanged,
    required this.onReset,
  });

  final CustomerManagementSnapshot snapshot;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onGroupChanged;
  final VoidCallback onShowColumnPicker;
  final Future<void> Function() onRefresh;
  final ValueChanged<CustomerModel?> onCustomerSelected;
  final VoidCallback onEdit;
  final String Function(double) formatPrice;
  final String Function(CustomerModel, CustomerGroupModel?, String) getCellValue;
  final bool Function(String) isNumericColumn;
  final String? filterBranchId;
  final ValueChanged<String?> onBranchChanged;
  final DateTime? filterCreatedAtFrom;
  final DateTime? filterCreatedAtTo;
  final void Function(DateTime?, DateTime?) onCreatedAtChanged;
  final int filterGender;
  final ValueChanged<int> onGenderChanged;
  final DateTime? filterBirthDateFrom;
  final DateTime? filterBirthDateTo;
  final void Function(DateTime?, DateTime?) onBirthDateChanged;
  final String filterTotalSalesFromText;
  final String filterTotalSalesToText;
  final void Function(String, String) onTotalSalesTextChanged;
  final String filterDebtFromText;
  final String filterDebtToText;
  final void Function(String, String) onDebtTextChanged;
  final String filterDeliveryArea;
  final ValueChanged<String> onDeliveryAreaChanged;
  final int filterStatus;
  final ValueChanged<int> onStatusChanged;
  final VoidCallback onReset;

  static const Color _headerBlue = Color(0xFFE3F2FD);

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 300,
          child: _CustomerFilterSidebar(
            selectedGroupId: snapshot.selectedGroupId,
            onGroupChanged: onGroupChanged,
            filterBranchId: filterBranchId,
            onBranchChanged: onBranchChanged,
            filterCreatedAtFrom: filterCreatedAtFrom,
            filterCreatedAtTo: filterCreatedAtTo,
            onCreatedAtChanged: onCreatedAtChanged,
            filterGender: filterGender,
            onGenderChanged: onGenderChanged,
            filterBirthDateFrom: filterBirthDateFrom,
            filterBirthDateTo: filterBirthDateTo,
            onBirthDateChanged: onBirthDateChanged,
            filterTotalSalesFromText: filterTotalSalesFromText,
            filterTotalSalesToText: filterTotalSalesToText,
            onTotalSalesTextChanged: onTotalSalesTextChanged,
            filterDebtFromText: filterDebtFromText,
            filterDebtToText: filterDebtToText,
            onDebtTextChanged: onDebtTextChanged,
            filterDeliveryArea: filterDeliveryArea,
            onDeliveryAreaChanged: onDeliveryAreaChanged,
            filterStatus: filterStatus,
            onStatusChanged: onStatusChanged,
            onReset: onReset,
          ),
        ),
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm theo mã, tên, SĐT...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    searchController.clear();
                                    onSearchChanged('');
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: onSearchChanged,
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String?>(
                        initialValue: snapshot.selectedGroupId,
                        decoration: InputDecoration(
                          labelText: 'Lọc theo nhóm',
                          prefixIcon: const Icon(Icons.filter_list),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          filled: true,
                          fillColor: Colors.grey[50],
                        ),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('Tất cả nhóm')),
                          ...snapshot.customerGroups.map((g) => DropdownMenuItem<String?>(value: g.id, child: Text(g.name))),
                        ],
                        onChanged: onGroupChanged,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.view_column),
                      onPressed: onShowColumnPicker,
                      tooltip: 'Chọn cột hiển thị',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _buildBodyContent(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    if (snapshot.isLoading && snapshot.filteredCustomers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (snapshot.filteredCustomers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Không tìm thấy khách hàng',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Thử xóa ô tìm kiếm hoặc chọn "Tất cả" ở bộ lọc bên trái để xem toàn bộ',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    return Consumer<CustomerProvider>(
      builder: (context, customerProvider, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (snapshot.selectedCustomer != null)
              _CustomerDetailPanel(
                customer: snapshot.selectedCustomer!,
                group: customerProvider.getCustomerGroupById(snapshot.selectedCustomer!.groupId),
                formatPrice: formatPrice,
                onClose: () => onCustomerSelected(null),
                onEdit: onEdit,
              ),
            Expanded(
              child: _buildDesktopTable(context, customerProvider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDesktopTable(BuildContext context, CustomerProvider customerProvider) {
    final filteredCustomers = snapshot.filteredCustomers;
    double sumDebt = 0, sumTotalInvoiced = 0, sumTotalRevenue = 0;
    for (final c in filteredCustomers) {
      sumDebt += c.totalDebt;
      sumTotalInvoiced += (c.totalInvoiced ?? c.totalRevenue);
      sumTotalRevenue += c.totalRevenue;
    }

    final visibleDefs = customerColumnDefs.where((d) => snapshot.visibleColumns[d.id] == true).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(_headerBlue),
                  columns: [
                    for (final def in visibleDefs)
                      DataColumn(
                        label: def.hasTotal
                            ? Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(def.label),
                                  const SizedBox(height: 2),
                                  Text(
                                    def.id == 'totalDebt'
                                        ? formatPrice(sumDebt)
                                        : def.id == 'totalInvoiced'
                                            ? formatPrice(sumTotalInvoiced)
                                            : formatPrice(sumTotalRevenue),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ],
                              )
                            : Text(def.label),
                      ),
                  ],
                  rows: List<DataRow>.generate(filteredCustomers.length, (index) {
                    final customer = filteredCustomers[index];
                    final group = customerProvider.getCustomerGroupById(customer.groupId);
                    return DataRow(
                      color: WidgetStateProperty.all(
                        index.isEven ? Colors.white : Colors.grey.shade50,
                      ),
                      cells: [
                        for (final def in visibleDefs)
                          DataCell(
                            InkWell(
                              onTap: () => onCustomerSelected(customer),
                              child: def.id == 'name'
                                  ? Text(getCellValue(customer, group, def.id))
                                  : isNumericColumn(def.id)
                                      ? Align(
                                          alignment: Alignment.centerRight,
                                          child: Text(getCellValue(customer, group, def.id)),
                                        )
                                      : Text(getCellValue(customer, group, def.id)),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Panel chi tiết khách hàng (desktop).
class _CustomerDetailPanel extends StatefulWidget {
  final CustomerModel customer;
  final CustomerGroupModel? group;
  final String Function(double) formatPrice;
  final VoidCallback onClose;
  final VoidCallback onEdit;

  const _CustomerDetailPanel({
    required this.customer,
    required this.group,
    required this.formatPrice,
    required this.onClose,
    required this.onEdit,
  });

  @override
  State<_CustomerDetailPanel> createState() => _CustomerDetailPanelState();
}

class _CustomerDetailPanelState extends State<_CustomerDetailPanel>
    with SingleTickerProviderStateMixin {
  static const Color _headerBlue = Color(0xFFE3F2FD);

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.customer;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: _headerBlue,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: widget.onClose,
                  tooltip: 'Đóng',
                ),
                const SizedBox(width: 8),
                Text(c.code ?? c.id, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    c.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(c.phone, style: TextStyle(fontSize: 14, color: Colors.grey[800])),
                const SizedBox(width: 24),
                Text(widget.formatPrice(c.totalDebt), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(width: 16),
                Text(widget.formatPrice(c.totalRevenue), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF2563EB),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF2563EB),
              tabs: const [
                Tab(text: 'Thông tin'),
                Tab(text: 'Địa chỉ nhận hàng'),
                Tab(text: 'Nợ cần thu từ khách'),
                Tab(text: 'Lịch sử tích điểm'),
              ],
            ),
          ),
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInfoTab(c),
                const Center(child: Text('Nội dung Địa chỉ nhận hàng đang cập nhật')),
                _buildDebtTab(c),
                const Center(child: Text('Nội dung Lịch sử tích điểm đang cập nhật')),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.lock_outline, size: 18),
                  label: const Text('Ngừng hoạt động'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                    side: BorderSide(color: Colors.grey[400]!),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Chỉnh sửa'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebtTab(CustomerModel c) {
    if (c.totalDebt <= 0) {
      return const Center(child: Text('Khách hàng không có nợ cần thu'));
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nợ hiện tại', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            '${widget.formatPrice(c.totalDebt)} đ',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab(CustomerModel c) {
    final group = widget.group;
    final dateCreated = c.createdAt != null ? DateFormat('dd/MM/yyyy').format(c.createdAt!) : '—';
    final groupName = group?.name ?? '—';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: c.totalDebt > 0 ? Colors.red[100]! : Colors.blue[100]!,
                child: Icon(
                  Icons.person,
                  size: 40,
                  color: c.totalDebt > 0 ? Colors.red[700]! : Colors.blue[700]!,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      c.code ?? c.id,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Người tạo: — | Ngày tạo: $dateCreated | Nhóm khách: $groupName',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bar_chart, size: 18, color: Colors.blue[700]),
                          const SizedBox(width: 6),
                          Text('Xem phân tích', style: TextStyle(fontSize: 14, color: Colors.blue[700], fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Điện thoại', c.phone),
                    _infoRow('Email', c.email ?? 'Chưa có'),
                    _infoRow('Địa chỉ', c.address ?? 'Chưa có'),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Sinh nhật', c.birthDate != null ? DateFormat('dd/MM/yyyy').format(c.birthDate!) : 'Chưa có'),
                    _infoRow('Facebook', 'Chưa có'),
                    _infoRow('Giới tính', c.gender == null ? 'Chưa có' : (c.gender! ? 'Nam' : 'Nữ')),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          InkWell(
            onTap: () {},
            child: Text(
              'Thêm thông tin xuất hóa đơn',
              style: TextStyle(fontSize: 14, color: Colors.blue[700], fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.note_outlined, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 8),
              Text(c.comments ?? 'Chưa có ghi chú', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
              const SizedBox(width: 24),
              Icon(Icons.delete_outline, size: 18, color: Colors.grey[600]),
              const SizedBox(width: 6),
              Text('Xóa', style: TextStyle(fontSize: 14, color: Colors.grey[700])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}

const Color _customerFilterPrimary = Color(0xFF2563EB);
const Color _customerFilterText = Color(0xFF1E293B);
const Color _customerFilterBorder = Color(0xFFE2E8F0);

/// Sidebar bộ lọc khách hàng (desktop).
class _CustomerFilterSidebar extends StatelessWidget {
  final String? selectedGroupId;
  final ValueChanged<String?> onGroupChanged;
  final String? filterBranchId;
  final ValueChanged<String?> onBranchChanged;
  final DateTime? filterCreatedAtFrom;
  final DateTime? filterCreatedAtTo;
  final void Function(DateTime?, DateTime?) onCreatedAtChanged;
  final int filterGender;
  final ValueChanged<int> onGenderChanged;
  final DateTime? filterBirthDateFrom;
  final DateTime? filterBirthDateTo;
  final void Function(DateTime?, DateTime?) onBirthDateChanged;
  final String filterTotalSalesFromText;
  final String filterTotalSalesToText;
  final void Function(String, String) onTotalSalesTextChanged;
  final String filterDebtFromText;
  final String filterDebtToText;
  final void Function(String, String) onDebtTextChanged;
  final String filterDeliveryArea;
  final ValueChanged<String> onDeliveryAreaChanged;
  final int filterStatus;
  final ValueChanged<int> onStatusChanged;
  final VoidCallback? onReset;

  const _CustomerFilterSidebar({
    required this.selectedGroupId,
    required this.onGroupChanged,
    required this.filterBranchId,
    required this.onBranchChanged,
    required this.filterCreatedAtFrom,
    required this.filterCreatedAtTo,
    required this.onCreatedAtChanged,
    required this.filterGender,
    required this.onGenderChanged,
    required this.filterBirthDateFrom,
    required this.filterBirthDateTo,
    required this.onBirthDateChanged,
    required this.filterTotalSalesFromText,
    required this.filterTotalSalesToText,
    required this.onTotalSalesTextChanged,
    required this.filterDebtFromText,
    required this.filterDebtToText,
    required this.onDebtTextChanged,
    required this.filterDeliveryArea,
    required this.onDeliveryAreaChanged,
    required this.filterStatus,
    required this.onStatusChanged,
    this.onReset,
  });

  static InputDecoration _inputDeco(String hint, {Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500], fontStyle: FontStyle.italic),
      prefixIcon: prefixIcon,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _customerFilterBorder)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _customerFilterBorder)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _segmentButton({required String label, required bool selected, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? _customerFilterPrimary : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? _customerFilterPrimary : _customerFilterBorder, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) const Icon(Icons.check, size: 16, color: Colors.white),
              if (selected) const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: selected ? Colors.white : _customerFilterText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, {required Widget child}) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: _customerFilterPrimary.withValues(alpha: 0.08),
        highlightColor: _customerFilterPrimary.withValues(alpha: 0.04),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        title: Text(
          title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _customerFilterText),
        ),
        iconColor: _customerFilterPrimary,
        collapsedIconColor: _customerFilterText,
        initiallyExpanded: true,
        children: [child],
      ),
    );
  }

  Widget _segmentRow({required List<String> labels, required int selected, required ValueChanged<int> onTap}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(labels.length, (i) {
        return _segmentButton(
          label: labels[i],
          selected: selected == i,
          onTap: () => onTap(i),
        );
      }),
    );
  }

  Widget _dateRow(BuildContext ctx, DateTime? from, DateTime? to, void Function(DateTime?, DateTime?) onPick) {
    final isAllTime = from == null && to == null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => onPick(null, null),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(isAllTime ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: isAllTime ? _customerFilterPrimary : _customerFilterBorder),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(ctx)!.allTime, style: const TextStyle(fontSize: 13, color: _customerFilterText, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: ctx,
              initialDate: from ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (date != null) onPick(date, to);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(!isAllTime ? Icons.radio_button_checked : Icons.radio_button_off, size: 20, color: !isAllTime ? _customerFilterPrimary : _customerFilterBorder),
                const SizedBox(width: 10),
                Text(AppLocalizations.of(ctx)!.customDate, style: const TextStyle(fontSize: 13, color: _customerFilterText, fontWeight: FontWeight.w500)),
                const SizedBox(width: 8),
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _rangeTextSection({
    required String fromText,
    required String toText,
    required void Function(String, String) onChanged,
  }) {
    return Column(
      children: [
        TextFormField(
          key: ValueKey('from-$fromText'),
          initialValue: fromText,
          decoration: _inputDeco('Từ - Nhập giá trị'),
          onChanged: (v) => onChanged(v, toText),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: ValueKey('to-$toText'),
          initialValue: toText,
          decoration: _inputDeco('Tới - Nhập giá trị'),
          onChanged: (v) => onChanged(fromText, v),
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topRight: Radius.circular(16), bottomRight: Radius.circular(16)),
        border: Border(right: BorderSide(color: _customerFilterBorder)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(-2, 0)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
            child: Row(
              children: [
                Icon(Icons.filter_list, color: _customerFilterPrimary, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.advancedFilter,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _customerFilterText),
                  ),
                ),
                if (onReset != null)
                  IconButton(
                    icon: Icon(Icons.refresh, size: 20, color: _customerFilterText),
                    onPressed: onReset,
                    tooltip: AppLocalizations.of(context)!.resetFilter,
                    style: IconButton.styleFrom(foregroundColor: _customerFilterText),
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: _customerFilterBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _section(context, 'Nhóm khách hàng', child: Consumer<CustomerProvider>(
                  builder: (context, provider, _) {
                    final groups = provider.customerGroups;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        DropdownButtonFormField<String?>(
                          initialValue: selectedGroupId,
                          decoration: _inputDeco('Tất cả các nhóm'),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('Tất cả các nhóm')),
                            ...groups.map((g) => DropdownMenuItem(value: g.id, child: Text(g.name))),
                          ],
                          onChanged: onGroupChanged,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.pushNamed(context, AppRoutes.customerGroupManagement),
                          icon: Icon(Icons.add, size: 18, color: _customerFilterPrimary),
                          label: Text('Tạo mới', style: TextStyle(color: _customerFilterPrimary, fontWeight: FontWeight.w500)),
                          style: OutlinedButton.styleFrom(foregroundColor: _customerFilterPrimary, side: BorderSide(color: _customerFilterBorder)),
                        ),
                      ],
                    );
                  },
                )),
                _section(context, 'Chi nhánh tạo', child: Consumer<BranchProvider>(
                  builder: (context, branchProvider, _) {
                    final branches = branchProvider.branches;
                    return DropdownButtonFormField<String?>(
                      initialValue: filterBranchId,
                      decoration: _inputDeco('Chọn chi nhánh'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Chọn chi nhánh')),
                        ...branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))),
                      ],
                      onChanged: onBranchChanged,
                    );
                  },
                )),
                _section(context, 'Ngày tạo', child: _dateRow(context, filterCreatedAtFrom, filterCreatedAtTo, onCreatedAtChanged)),
                _section(context, 'Loại khách hàng', child: _segmentRow(
                  labels: const ['Tất cả', 'Cá nhân', 'Công ty'],
                  selected: 0,
                  onTap: (_) {},
                )),
                _section(context, 'Giới tính', child: _segmentRow(
                  labels: const ['Tất cả', 'Nam', 'Nữ'],
                  selected: filterGender,
                  onTap: onGenderChanged,
                )),
                _section(context, 'Sinh nhật', child: _dateRow(context, filterBirthDateFrom, filterBirthDateTo, onBirthDateChanged)),
                _section(context, 'Ngày giao dịch cuối', child: _dateRow(context, null, null, (_, _) {})),
                _section(context, 'Tổng bán', child: _rangeTextSection(
                  fromText: filterTotalSalesFromText,
                  toText: filterTotalSalesToText,
                  onChanged: onTotalSalesTextChanged,
                )),
                _section(context, 'Nợ hiện tại', child: _rangeTextSection(
                  fromText: filterDebtFromText,
                  toText: filterDebtToText,
                  onChanged: onDebtTextChanged,
                )),
                _section(context, 'Khu vực giao hàng', child: TextFormField(
                  key: ValueKey('delivery-$filterDeliveryArea'),
                  initialValue: filterDeliveryArea,
                  decoration: _inputDeco('Chọn Tỉnh/TP - Quận/Huyện'),
                  onChanged: onDeliveryAreaChanged,
                )),
                _section(context, 'Trạng thái', child: _segmentRow(
                  labels: const ['Tất cả', 'Đang hoạt động', 'Ngừng hoạt động'],
                  selected: filterStatus,
                  onTap: onStatusChanged,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
