import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../controllers/employee_group_provider.dart';
import '../../models/user_model.dart';
import '../../services/employee_service.dart';
import '../../services/firebase_service.dart';
import '../../utils/platform_utils.dart';
import 'employee_management_screen_mobile.dart';
import 'employee_management_screen_desktop.dart';

/// Tệp điều hướng chính: chọn Mobile hoặc Desktop theo platform.
/// Giữ toàn bộ state và logic (load nhân viên, bật/tắt tài khoản, phê duyệt, đổi chi nhánh).
class EmployeeManagementScreen extends StatefulWidget {
  final bool? forceMobile;

  const EmployeeManagementScreen({super.key, this.forceMobile});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  List<UserModel> _employees = [];
  bool _isLoading = false;

  bool get _useMobileLayout =>
      widget.forceMobile ?? isMobilePlatform;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeGroupProvider>().loadEmployeeGroups();
    });
  }

  Future<void> _loadEmployees() async {
    final authProvider = context.read<AuthProvider>();
    final shopId = authProvider.shop?.id;
    if (shopId == null) return;

    setState(() => _isLoading = true);
    try {
      final service = EmployeeService(shopId: shopId);
      final list =
          await service.getEmployees(includeUnapproved: true);
      if (mounted) {
        setState(() {
          _employees = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleAllowRegistration(
      AuthProvider authProvider, bool value) async {
    final shop = authProvider.shop;
    if (shop == null) return;
    try {
      await _firebaseService.updateShopRegistrationStatus(shop.id, value);
      await authProvider.updateShop(shop.copyWith(allowRegistration: value));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value
                ? 'Đã bật cho phép nhân viên đăng ký.'
                : 'Đã tắt cho phép nhân viên đăng ký.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật cấu hình: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleApproval(UserModel employee, bool value) async {
    final shopId = context.read<AuthProvider>().shop?.id;
    if (shopId == null) return;
    if (value && (employee.workingBranchId == null || employee.workingBranchId!.isEmpty)) {
      if (mounted) _showApproveStaffDialog(employee);
      return;
    }
    try {
      if (value) {
        await _firebaseService.updateStaffApprovalStatus(
          uid: employee.uid,
          isApproved: true,
          workingBranchId: employee.workingBranchId,
        );
      } else {
        final service = EmployeeService(shopId: shopId);
        await service.updateEmployee(employee.uid, {'isApproved': false});
      }
      await _loadEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'Đã kích hoạt tài khoản.' : 'Đã vô hiệu hóa tài khoản.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveStaffWithBranch(UserModel user, String workingBranchId, {String? groupId}) async {
    try {
      await _firebaseService.updateStaffApprovalStatus(
        uid: user.uid,
        isApproved: true,
        workingBranchId: workingBranchId,
        groupId: groupId,
      );
      await _loadEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã phê duyệt nhân viên.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi phê duyệt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changeGroup(UserModel user, String? groupId) async {
    final shopId = context.read<AuthProvider>().shop?.id;
    if (shopId == null) return;
    try {
      final service = EmployeeService(shopId: shopId);
      await service.updateEmployee(user.uid, {'groupId': groupId});
      await _loadEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật nhóm nhân viên.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi cập nhật nhóm: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showChangeGroupDialog(UserModel user) async {
    final groupProvider = context.read<EmployeeGroupProvider>();
    String? selectedGroupId = user.groupId;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Chọn nhóm nhân viên'),
              content: DropdownButtonFormField<String?>(
                initialValue: selectedGroupId,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Nhóm',
                ),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('— Không nhóm')),
                  ...groupProvider.employeeGroups
                      .map((g) => DropdownMenuItem<String?>(value: g.id, child: Text(g.name))),
                ],
                onChanged: (v) => setState(() => selectedGroupId = v),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _changeGroup(user, selectedGroupId);
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _changeBranch(UserModel user, String branchId) async {
    try {
      await _firebaseService.updateStaffWorkingBranch(
        uid: user.uid,
        workingBranchId: branchId,
      );
      await _loadEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã điều chuyển chi nhánh.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi điều chuyển: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showApproveStaffDialog(UserModel user) async {
    final branchProvider = context.read<BranchProvider>();
    final groupProvider = context.read<EmployeeGroupProvider>();
    if (branchProvider.branches.isEmpty) await branchProvider.loadBranches();
    final branches = branchProvider.branches.where((b) => b.isActive).toList();
    if (branches.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa có chi nhánh nào. Vui lòng tạo chi nhánh trước.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    String? selectedBranchId = user.workingBranchId ?? branches.first.id;
    String? selectedGroupId = user.groupId;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Phê duyệt nhân viên'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Email: ${user.email}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    const Text('Chi nhánh làm việc:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedBranchId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Chi nhánh',
                      ),
                      items: branches
                          .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                          .toList(),
                      onChanged: (v) => setState(() => selectedBranchId = v),
                    ),
                    const SizedBox(height: 16),
                    const Text('Nhóm nhân viên:', style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String?>(
                      initialValue: selectedGroupId,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Nhóm',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('— Không nhóm')),
                        ...groupProvider.employeeGroups
                            .map((g) => DropdownMenuItem<String?>(value: g.id, child: Text(g.name))),
                      ],
                      onChanged: (v) => setState(() => selectedGroupId = v),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () {
                    if (selectedBranchId != null && selectedBranchId!.isNotEmpty) {
                      Navigator.of(ctx).pop();
                      _approveStaffWithBranch(user, selectedBranchId!, groupId: selectedGroupId);
                    }
                  },
                  child: const Text('Phê duyệt'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showChangeBranchDialog(UserModel user) async {
    final branchProvider = context.read<BranchProvider>();
    if (branchProvider.branches.isEmpty) await branchProvider.loadBranches();
    final branches = branchProvider.branches.where((b) => b.isActive).toList();
    if (branches.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chưa có chi nhánh nào. Vui lòng tạo chi nhánh trước.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    String? selectedBranchId = user.workingBranchId ?? branches.first.id;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Điều chuyển chi nhánh'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nhân viên: ${user.displayName ?? user.email}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Chọn chi nhánh làm việc mới:', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBranchId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Chi nhánh',
                    ),
                    items: branches
                        .map((b) => DropdownMenuItem(value: b.id, child: Text(b.name)))
                        .toList(),
                    onChanged: (v) => setState(() => selectedBranchId = v),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Hủy')),
                ElevatedButton(
                  onPressed: () {
                    if (selectedBranchId != null && selectedBranchId!.isNotEmpty) {
                      Navigator.of(ctx).pop();
                      _changeBranch(user, selectedBranchId!);
                    }
                  },
                  child: const Text('Lưu'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onAddEmployee() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tính năng thêm nhân viên đang được phát triển.'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final branchProvider = context.watch<BranchProvider>();
    final shop = authProvider.shop;
    final allowRegistration = shop?.allowRegistration == true;
    final branches = branchProvider.branches;

    final groupProvider = context.watch<EmployeeGroupProvider>();
    if (_useMobileLayout) {
      return EmployeeManagementScreenMobile(
        employees: _employees,
        isLoading: _isLoading,
        allowRegistration: allowRegistration,
        branches: branches,
        employeeGroups: groupProvider.employeeGroups,
        getEmployeeGroupById: groupProvider.getEmployeeGroupById,
        onRefresh: _loadEmployees,
        onToggleAllowRegistration: (v) => _toggleAllowRegistration(authProvider, v),
        onToggleApproval: _toggleApproval,
        onApproveStaff: _showApproveStaffDialog,
        onChangeBranch: _showChangeBranchDialog,
        onChangeGroup: _showChangeGroupDialog,
        onAdd: _onAddEmployee,
      );
    }
    return EmployeeManagementScreenDesktop(
      employees: _employees,
      isLoading: _isLoading,
      allowRegistration: allowRegistration,
      branches: branches,
      employeeGroups: groupProvider.employeeGroups,
      getEmployeeGroupById: groupProvider.getEmployeeGroupById,
      onRefresh: _loadEmployees,
      onToggleAllowRegistration: (v) => _toggleAllowRegistration(authProvider, v),
      onToggleApproval: _toggleApproval,
      onApproveStaff: _showApproveStaffDialog,
      onChangeBranch: _showChangeBranchDialog,
      onChangeGroup: _showChangeGroupDialog,
      onAdd: _onAddEmployee,
    );
  }
}
