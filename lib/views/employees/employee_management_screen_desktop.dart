import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/branch_model.dart';
import '../../models/employee_group_model.dart';

/// Màn hình quản lý nhân viên tối ưu cho màn hình rộng: bảng dữ liệu, tìm kiếm, lọc theo chi nhánh.
class EmployeeManagementScreenDesktop extends StatefulWidget {
  const EmployeeManagementScreenDesktop({
    super.key,
    required this.employees,
    required this.isLoading,
    required this.allowRegistration,
    required this.branches,
    required this.employeeGroups,
    required this.getEmployeeGroupById,
    required this.onRefresh,
    required this.onToggleAllowRegistration,
    required this.onToggleApproval,
    required this.onApproveStaff,
    required this.onChangeBranch,
    required this.onChangeGroup,
    required this.onAdd,
  });

  final List<UserModel> employees;
  final bool isLoading;
  final bool allowRegistration;
  final List<BranchModel> branches;
  final List<EmployeeGroupModel> employeeGroups;
  final EmployeeGroupModel? Function(String? groupId) getEmployeeGroupById;
  final VoidCallback onRefresh;
  final void Function(bool value) onToggleAllowRegistration;
  final void Function(UserModel employee, bool value) onToggleApproval;
  final void Function(UserModel user) onApproveStaff;
  final void Function(UserModel user) onChangeBranch;
  final void Function(UserModel user) onChangeGroup;
  final VoidCallback onAdd;

  @override
  State<EmployeeManagementScreenDesktop> createState() =>
      _EmployeeManagementScreenDesktopState();
}

class _EmployeeManagementScreenDesktopState
    extends State<EmployeeManagementScreenDesktop> {
  final TextEditingController _searchController = TextEditingController();
  String? _branchFilterId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  static String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.owner:
        return 'Chủ shop';
      case UserRole.manager:
        return 'Quản lý';
      case UserRole.staff:
        return 'Nhân viên';
    }
  }

  String _branchName(String? branchId) {
    if (branchId == null || branchId.isEmpty) return '—';
    try {
      return widget.branches.firstWhere((e) => e.id == branchId).name;
    } catch (_) {
      return branchId;
    }
  }

  String _groupName(String? groupId) {
    if (groupId == null || groupId.isEmpty) return '—';
    final g = widget.getEmployeeGroupById(groupId);
    return g?.name ?? groupId;
  }

  List<UserModel> get _filteredEmployees {
    var list = widget.employees;
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((e) {
        final name = (e.displayName ?? e.email).toLowerCase();
        final email = e.email.toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();
    }
    if (_branchFilterId != null && _branchFilterId!.isNotEmpty) {
      list = list.where((e) => e.workingBranchId == _branchFilterId).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredEmployees;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý nhân viên'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Làm mới',
            onPressed: widget.isLoading ? null : widget.onRefresh,
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: widget.onAdd,
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Thêm nhân viên'),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: SwitchListTile(
                title: const Text('Cho phép đăng ký nhân viên mới'),
                subtitle: Text(
                  widget.allowRegistration
                      ? 'Nhân viên có thể tự đăng ký bằng Shop ID / QR Code.'
                      : 'Tắt đăng ký nhân viên mới, chỉ Admin tạo tài khoản.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                value: widget.allowRegistration,
                onChanged: widget.onToggleAllowRegistration,
                secondary: Icon(
                  widget.allowRegistration ? Icons.check_circle : Icons.cancel,
                  color: widget.allowRegistration ? Colors.green : Colors.orange,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên hoặc email...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<String?>(
                    initialValue: _branchFilterId,
                    decoration: InputDecoration(
                      labelText: 'Lọc theo chi nhánh',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Tất cả chi nhánh'),
                      ),
                      ...widget.branches
                          .map((b) => DropdownMenuItem<String?>(
                                value: b.id,
                                child: Text(b.name),
                              )),
                    ],
                    onChanged: (v) => setState(() => _branchFilterId = v),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: widget.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                widget.employees.isEmpty
                                    ? 'Chưa có nhân viên'
                                    : 'Không có kết quả phù hợp',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SingleChildScrollView(
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                Colors.grey.shade100,
                              ),
                              columns: const [
                                DataColumn(
                                  label: Text(
                                    'TÊN',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'EMAIL',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'VAI TRÒ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'CHI NHÁNH',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'NHÓM',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'LẦN CUỐI ĐĂNG NHẬP',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    'TRẠNG THÁI',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                              rows: filtered.map((e) {
                                final displayName =
                                    e.displayName ?? e.email;
                                return DataRow(
                                  cells: [
                                    DataCell(Text(displayName)),
                                    DataCell(Text(e.email)),
                                    DataCell(Text(_roleLabel(e.role))),
                                    DataCell(
                                      InkWell(
                                        onTap: () => widget.onChangeBranch(e),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(_branchName(e.workingBranchId)),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.edit,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      InkWell(
                                        onTap: () => widget.onChangeGroup(e),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(_groupName(e.groupId)),
                                            const SizedBox(width: 4),
                                            Icon(
                                              Icons.edit,
                                              size: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const DataCell(Text('—')),
                                    DataCell(
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Switch(
                                            value: e.isApproved,
                                            onChanged: (value) {
                                              if (value &&
                                                  (e.workingBranchId == null ||
                                                      e.workingBranchId!.isEmpty)) {
                                                widget.onApproveStaff(e);
                                              } else {
                                                widget.onToggleApproval(e, value);
                                              }
                                            },
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            e.isApproved ? 'Đang hoạt động' : 'Vô hiệu hóa',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: e.isApproved ? Colors.green : Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }
}
