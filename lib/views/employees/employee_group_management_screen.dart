import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../controllers/employee_group_provider.dart';
import '../../models/employee_group_model.dart';
import '../../widgets/responsive_container.dart';

/// Màn hình quản lý nhóm nhân viên (phân quyền). Material 3, hỗ trợ Desktop.
class EmployeeGroupManagementScreen extends StatefulWidget {
  final bool? forceMobile;

  const EmployeeGroupManagementScreen({super.key, this.forceMobile});

  @override
  State<EmployeeGroupManagementScreen> createState() =>
      _EmployeeGroupManagementScreenState();
}

class _EmployeeGroupManagementScreenState
    extends State<EmployeeGroupManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeGroupProvider>().loadEmployeeGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý nhóm nhân viên'),
        actions: const [],
      ),
      body: ResponsiveContainer(
        child: Consumer<EmployeeGroupProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.employeeGroups.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.employeeGroups.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group_work_rounded,
                      size: 64,
                      color: colorScheme.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có nhóm nhân viên nào',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nhấn nút + để thêm nhóm và cấu hình quyền',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => provider.loadEmployeeGroups(),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: provider.employeeGroups.length,
                itemBuilder: (context, index) {
                  final group = provider.employeeGroups[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(
                          Icons.badge_rounded,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(
                        group.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${group.permissions.length} quyền',
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => _showAddOrEditDialog(context, group),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: colorScheme.error),
                            onPressed: () => _showDeleteConfirmation(context, group),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddOrEditDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm nhóm'),
      ),
    );
  }

  void _showAddOrEditDialog(BuildContext context, [EmployeeGroupModel? group]) {
    final nameController = TextEditingController(text: group?.name ?? '');
    final formKey = GlobalKey<FormState>();
    final authProvider = context.read<AuthProvider>();
    final shopId = authProvider.shop?.id ?? '';
    final now = DateTime.now();

    // Trạng thái quyền: Map permission -> enabled
    final Map<String, bool> permissions = {};
    for (final p in EmployeePermissions.all) {
      permissions[p] = group?.hasPermission(p) ?? false;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(group == null ? 'Thêm nhóm nhân viên' : 'Sửa nhóm nhân viên'),
            content: SizedBox(
              width: 400,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Tên nhóm *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Vui lòng nhập tên nhóm';
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Quyền',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...EmployeePermissions.all.map((permission) {
                        return CheckboxListTile(
                          title: Text(EmployeePermissions.label(permission)),
                          value: permissions[permission] ?? false,
                          onChanged: (value) {
                            setState(() => permissions[permission] = value ?? false);
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Hủy'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final selectedPermissions = permissions.entries
                      .where((e) => e.value)
                      .map((e) => e.key)
                      .toList();

                  final newGroup = EmployeeGroupModel(
                    id: group?.id ?? '',
                    name: nameController.text.trim(),
                    shopId: shopId,
                    permissions: selectedPermissions,
                    createdAt: group?.createdAt ?? now,
                    updatedAt: now,
                  );

                  final provider = context.read<EmployeeGroupProvider>();
                  final success = group == null
                      ? await provider.addEmployeeGroup(newGroup)
                      : await provider.updateEmployeeGroup(newGroup);

                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(group == null
                              ? 'Đã thêm nhóm nhân viên'
                              : 'Đã cập nhật nhóm nhân viên'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(provider.errorMessage ?? 'Có lỗi xảy ra'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: Text(group == null ? 'Thêm' : 'Cập nhật'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, EmployeeGroupModel group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa nhóm "${group.name}"? Nhân viên trong nhóm sẽ không bị xóa nhưng sẽ mất quyền từ nhóm.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () async {
              final provider = context.read<EmployeeGroupProvider>();
              final success = await provider.deleteEmployeeGroup(group.id);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã xóa nhóm nhân viên'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(provider.errorMessage ?? 'Có lỗi xảy ra'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
