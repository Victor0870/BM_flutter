import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/branch_provider.dart';
import '../../models/branch_model.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';

/// Màn hình quản lý chi nhánh (mobile/desktop theo platform).
class BranchManagementScreen extends StatefulWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const BranchManagementScreen({super.key, this.forceMobile});

  @override
  State<BranchManagementScreen> createState() => _BranchManagementScreenState();
}

class _BranchManagementScreenState extends State<BranchManagementScreen> {
  @override
  void initState() {
    super.initState();
    // Load branches khi màn hình được khởi tạo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BranchProvider>().loadBranches();
    });
  }

  Future<void> _refreshBranches() async {
    await context.read<BranchProvider>().loadBranches();
  }

  void _showAddBranchDialog({BranchModel? branch}) {
    final nameController = TextEditingController(text: branch?.name ?? '');
    final addressController = TextEditingController(text: branch?.address ?? '');
    final phoneController = TextEditingController(text: branch?.phone ?? '');
    bool isActive = branch?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(branch == null ? 'Thêm chi nhánh' : 'Sửa chi nhánh'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên chi nhánh *',
                      hintText: 'Ví dụ: Chi nhánh 1, Cửa hàng trung tâm...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Vui lòng nhập tên chi nhánh';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ',
                      hintText: 'Địa chỉ chi nhánh...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Số điện thoại',
                      hintText: 'Số điện thoại liên hệ...',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: const Text('Hoạt động'),
                    subtitle: const Text('Bật/tắt chi nhánh này'),
                    value: isActive,
                    onChanged: (value) {
                      setDialogState(() {
                        isActive = value;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final branchProvider = context.read<BranchProvider>();
                  final authProvider = branchProvider.authProvider;

                  if (authProvider.user == null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Chưa đăng nhập'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                    return;
                  }

                  final branchToSave = BranchModel(
                    id: branch?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.trim(),
                    address: addressController.text.trim().isEmpty
                        ? null
                        : addressController.text.trim(),
                    phone: phoneController.text.trim().isEmpty
                        ? null
                        : phoneController.text.trim(),
                    isActive: isActive,
                  );

                  bool success;
                  if (branch == null) {
                    success = await branchProvider.addBranch(branchToSave);
                  } else {
                    success = await branchProvider.updateBranch(branchToSave);
                  }

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            branch == null
                                ? 'Thêm chi nhánh thành công!'
                                : 'Cập nhật chi nhánh thành công!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    await _refreshBranches();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          branchProvider.errorMessage ?? 'Có lỗi xảy ra',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: Text(branch == null ? 'Thêm' : 'Cập nhật'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BranchModel branch) async {
    // Không cho xóa chi nhánh mặc định "Cửa hàng chính"
    if (branch.id == kMainStoreBranchId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xóa chi nhánh mặc định "Cửa hàng chính"'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa chi nhánh "${branch.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final branchProvider = context.read<BranchProvider>();
      final success = await branchProvider.deleteBranch(branch.id);

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Xóa chi nhánh thành công!'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                branchProvider.errorMessage ?? 'Có lỗi xảy ra',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý chi nhánh'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            tooltip: 'Về trang chủ',
          ),
        ],
      ),
      body: ResponsiveContainer(
        maxWidth: 800,
        padding: const EdgeInsets.all(8.0),
        child: Consumer<BranchProvider>(
          builder: (context, branchProvider, child) {
            if (branchProvider.isLoading && branchProvider.branches.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (branchProvider.branches.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.store_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có chi nhánh nào',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nhấn nút + để thêm chi nhánh mới',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: _refreshBranches,
              child: ListView.builder(
                itemCount: branchProvider.branches.length,
                itemBuilder: (context, index) {
                  final branch = branchProvider.branches[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4.0),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: branch.isActive
                            ? Theme.of(context).colorScheme.primary
                            : Colors.grey,
                        child: Icon(
                          Icons.store,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        branch.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          decoration: branch.isActive
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (branch.address != null && branch.address!.isNotEmpty)
                            Text('Địa chỉ: ${branch.address}'),
                          if (branch.phone != null && branch.phone!.isNotEmpty)
                            Text('SĐT: ${branch.phone}'),
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(
                              branch.isActive ? 'Hoạt động' : 'Ngừng hoạt động',
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: branch.isActive
                                ? Colors.green[100]
                                : Colors.grey[300],
                            padding: const EdgeInsets.all(0),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Không cho sửa tên chi nhánh mặc định
                          if (branch.id != kMainStoreBranchId)
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showAddBranchDialog(branch: branch),
                              tooltip: 'Sửa',
                            ),
                          // Không cho xóa chi nhánh mặc định
                          if (branch.id != kMainStoreBranchId)
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(branch),
                              tooltip: 'Xóa',
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBranchDialog(),
        tooltip: 'Thêm chi nhánh',
        child: const Icon(Icons.add),
      ),
    );
  }
}
