import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/branch_provider.dart';
import '../../models/user_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/platform_utils.dart';

/// Màn hình danh sách nhân viên & điều khiển allowRegistration (mobile/desktop theo platform).
class EmployeeManagementScreen extends StatefulWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const EmployeeManagementScreen({super.key, this.forceMobile});

  @override
  State<EmployeeManagementScreen> createState() =>
      _EmployeeManagementScreenState();
}

class _EmployeeManagementScreenState extends State<EmployeeManagementScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  bool _isLoading = false;
  List<UserModel> _pendingStaff = [];

  @override
  void initState() {
    super.initState();
    _loadPendingStaff();
  }

  Future<void> _loadPendingStaff() async {
    final authProvider = context.read<AuthProvider>();
    final shopId = authProvider.shop?.id;
    if (shopId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final staff =
          await _firebaseService.getPendingStaffByShopId(shopId);
      if (mounted) {
        setState(() {
          _pendingStaff = staff;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleAllowRegistration(
      AuthProvider authProvider, bool value) async {
    final shop = authProvider.shop;
    if (shop == null) return;

    try {
      await _firebaseService.updateShopRegistrationStatus(shop.id, value);
      final updatedShop = shop.copyWith(
        allowRegistration: value,
      );
      await authProvider.updateShop(updatedShop);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Đã bật cho phép nhân viên đăng ký.'
                  : 'Đã tắt cho phép nhân viên đăng ký.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật cấu hình: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveStaff(
    UserModel user,
    bool approve, {
    String? workingBranchId,
  }) async {
    try {
      await _firebaseService.updateStaffApprovalStatus(
        uid: user.uid,
        isApproved: approve,
        workingBranchId: workingBranchId,
      );
      await _loadPendingStaff();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? 'Đã phê duyệt nhân viên.'
                  : 'Đã cập nhật trạng thái nhân viên.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi cập nhật nhân viên: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Hiển thị dialog để chọn chi nhánh khi phê duyệt nhân viên
  Future<void> _showApproveStaffDialog(UserModel user) async {
    final branchProvider = context.read<BranchProvider>();
    
    // Đảm bảo branches đã được load
    if (branchProvider.branches.isEmpty) {
      await branchProvider.loadBranches();
    }

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
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Phê duyệt nhân viên'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Email: ${user.email}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chọn chi nhánh làm việc:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBranchId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Chi nhánh',
                      hintText: 'Chọn chi nhánh',
                    ),
                    items: branches.map((branch) {
                      return DropdownMenuItem<String>(
                        value: branch.id,
                        child: Row(
                          children: [
                            const Icon(Icons.store, size: 18),
                            const SizedBox(width: 8),
                            Text(branch.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          selectedBranchId = value;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Vui lòng chọn chi nhánh';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lưu ý: Nhân viên sẽ được gán vào chi nhánh này và có quyền truy cập dữ liệu của chi nhánh.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedBranchId != null && selectedBranchId!.isNotEmpty) {
                      Navigator.of(context).pop();
                      _approveStaff(user, true, workingBranchId: selectedBranchId);
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

  /// Hiển thị dialog để thay đổi chi nhánh làm việc của nhân viên
  Future<void> _showChangeBranchDialog(UserModel user) async {
    final branchProvider = context.read<BranchProvider>();
    
    // Đảm bảo branches đã được load
    if (branchProvider.branches.isEmpty) {
      await branchProvider.loadBranches();
    }

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
    
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Điều chuyển chi nhánh'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nhân viên: ${user.displayName ?? user.email}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Chọn chi nhánh làm việc mới:',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedBranchId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Chi nhánh',
                      hintText: 'Chọn chi nhánh',
                    ),
                    items: branches.map((branch) {
                      return DropdownMenuItem<String>(
                        value: branch.id,
                        child: Row(
                          children: [
                            const Icon(Icons.store, size: 18),
                            const SizedBox(width: 8),
                            Text(branch.name),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      if (value != null) {
                        setState(() {
                          selectedBranchId = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (selectedBranchId != null && selectedBranchId!.isNotEmpty) {
                      Navigator.of(context).pop();
                      final branchId = selectedBranchId!;
                      try {
                        await _firebaseService.updateStaffWorkingBranch(
                          uid: user.uid,
                          workingBranchId: branchId,
                        );
                        await _loadPendingStaff();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Đã điều chuyển nhân viên sang chi nhánh: ${branches.firstWhere((b) => b.id == branchId).name}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lỗi khi điều chuyển nhân viên: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final shop = authProvider.shop;
        // Dùng so sánh == true để an toàn ngay cả khi dữ liệu cũ có thể null
        final bool allowRegistration = shop?.allowRegistration == true;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Danh sách nhân viên'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: SwitchListTile(
                    title: const Text('Cho phép đăng ký nhân viên mới'),
                    subtitle: Text(
                      allowRegistration
                          ? 'Nhân viên có thể tự đăng ký bằng Shop ID / QR Code.'
                          : 'Tắt đăng ký nhân viên mới, chỉ Admin tạo tài khoản.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    value: allowRegistration,
                    onChanged: (value) =>
                        _toggleAllowRegistration(authProvider, value),
                    secondary: Icon(
                      allowRegistration ? Icons.check_circle : Icons.cancel,
                      color:
                          allowRegistration ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Nhân viên chờ phê duyệt',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                        )
                      : _pendingStaff.isEmpty
                          ? const Center(
                              child: Text('Không có nhân viên chờ phê duyệt.'),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadPendingStaff,
                              child: ListView.builder(
                                itemCount: _pendingStaff.length,
                                itemBuilder: (context, index) {
                                  final staff = _pendingStaff[index];
                                  return Card(
                                    child: ListTile(
                                      leading: const Icon(Icons.person),
                                      title: Text(staff.email),
                                      subtitle: Text(
                                        'UID: ${staff.uid}\nNgày tạo: ${staff.createdAt}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                      isThreeLine: true,
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Hiển thị chi nhánh hiện tại nếu có
                                          if (staff.workingBranchId != null)
                                            Padding(
                                              padding: const EdgeInsets.only(right: 8.0),
                                              child: Consumer<BranchProvider>(
                                                builder: (context, branchProvider, child) {
                                                  final branch = branchProvider.branches
                                                      .firstWhere(
                                                        (b) => b.id == staff.workingBranchId,
                                                        orElse: () => branchProvider.branches.first,
                                                      );
                                                  return Chip(
                                                    avatar: const Icon(Icons.store, size: 16),
                                                    label: Text(
                                                      branch.name,
                                                      style: const TextStyle(fontSize: 12),
                                                    ),
                                                    onDeleted: () => _showChangeBranchDialog(staff),
                                                    deleteIcon: const Icon(Icons.edit, size: 16),
                                                  );
                                                },
                                              ),
                                            )
                                          else
                                            Padding(
                                              padding: const EdgeInsets.only(right: 8.0),
                                              child: Chip(
                                                avatar: const Icon(Icons.store_outlined, size: 16),
                                                label: const Text(
                                                  'Chưa gán',
                                                  style: TextStyle(fontSize: 12),
                                                ),
                                                backgroundColor: Colors.orange.shade50,
                                              ),
                                            ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.check,
                                              color: Colors.green,
                                            ),
                                            tooltip: 'Phê duyệt',
                                            onPressed: () => _showApproveStaffDialog(staff),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

