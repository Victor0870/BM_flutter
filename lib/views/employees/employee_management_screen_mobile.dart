import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../../models/branch_model.dart';
import '../../models/employee_group_model.dart';

/// Màn hình quản lý nhân viên tối ưu cho điện thoại: danh sách Card, Switch kích hoạt/vô hiệu hóa, FAB thêm mới.
class EmployeeManagementScreenMobile extends StatelessWidget {
  const EmployeeManagementScreenMobile({
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
    if (branchId == null || branchId.isEmpty) return 'Chưa gán';
    try {
      return branches.firstWhere((e) => e.id == branchId).name;
    } catch (_) {
      return branchId;
    }
  }

  String _groupName(String? groupId) {
    if (groupId == null || groupId.isEmpty) return '—';
    final g = getEmployeeGroupById(groupId);
    return g?.name ?? groupId;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý nhân viên'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => onRefresh(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Card(
                  child: SwitchListTile(
                    title: const Text('Cho phép đăng ký nhân viên mới'),
                    subtitle: Text(
                      allowRegistration
                          ? 'Nhân viên có thể tự đăng ký bằng Shop ID / QR Code.'
                          : 'Tắt đăng ký nhân viên mới, chỉ Admin tạo tài khoản.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    value: allowRegistration,
                    onChanged: onToggleAllowRegistration,
                    secondary: Icon(
                      allowRegistration ? Icons.check_circle : Icons.cancel,
                      color: allowRegistration ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Danh sách nhân viên',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ),
            if (isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (employees.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Chưa có nhân viên',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final e = employees[index];
                      return _EmployeeCard(
                        employee: e,
                        branchName: _branchName(e.workingBranchId),
                        groupName: _groupName(e.groupId),
                        roleLabel: _roleLabel(e.role),
                        onToggle: (value) => onToggleApproval(e, value),
                        onApprove: () => onApproveStaff(e),
                        onChangeBranch: () => onChangeBranch(e),
                        onChangeGroup: () => onChangeGroup(e),
                      );
                    },
                    childCount: employees.length,
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onAdd,
        tooltip: 'Thêm nhân viên',
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmployeeCard extends StatelessWidget {
  const _EmployeeCard({
    required this.employee,
    required this.branchName,
    required this.groupName,
    required this.roleLabel,
    required this.onToggle,
    required this.onApprove,
    required this.onChangeBranch,
    required this.onChangeGroup,
  });

  final UserModel employee;
  final String branchName;
  final String groupName;
  final String roleLabel;
  final void Function(bool value) onToggle;
  final VoidCallback onApprove;
  final VoidCallback onChangeBranch;
  final VoidCallback onChangeGroup;

  @override
  Widget build(BuildContext context) {
    final displayName = employee.displayName ?? employee.email;
    final isApproved = employee.isApproved;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isApproved ? Colors.green.shade100 : Colors.orange.shade100,
                  child: Icon(
                    Icons.person,
                    color: isApproved ? Colors.green.shade700 : Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        employee.email,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Chip(
                            label: Text(roleLabel, style: const TextStyle(fontSize: 11)),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          InkWell(
                            onTap: onChangeBranch,
                            child: Chip(
                              avatar: const Icon(Icons.store, size: 16),
                              label: Text(
                                branchName,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          InkWell(
                            onTap: onChangeGroup,
                            child: Chip(
                              avatar: const Icon(Icons.badge, size: 16),
                              label: Text(
                                groupName,
                                style: const TextStyle(fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                              padding: EdgeInsets.zero,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isApproved,
                  onChanged: (value) {
                    if (value && (employee.workingBranchId == null || employee.workingBranchId!.isEmpty)) {
                      onApprove();
                    } else {
                      onToggle(value);
                    }
                  },
                ),
              ],
            ),
            if (!isApproved) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('Phê duyệt và gán chi nhánh'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
