import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/customer_provider.dart';
import '../../models/customer_group_model.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';

/// Màn hình quản lý nhóm khách hàng (mobile/desktop theo platform).
class CustomerGroupManagementScreen extends StatefulWidget {
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const CustomerGroupManagementScreen({super.key, this.forceMobile});

  @override
  State<CustomerGroupManagementScreen> createState() => _CustomerGroupManagementScreenState();
}

class _CustomerGroupManagementScreenState extends State<CustomerGroupManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().loadCustomerGroups();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý nhóm khách hàng'),
        actions: const [],
      ),
      body: ResponsiveContainer(
        child: Consumer<CustomerProvider>(
          builder: (context, customerProvider, child) {
            if (customerProvider.isLoading && customerProvider.customerGroups.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (customerProvider.customerGroups.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.group_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Chưa có nhóm khách hàng nào',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Nhấn nút + để thêm nhóm mới',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => customerProvider.loadCustomerGroups(),
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: customerProvider.customerGroups.length,
                itemBuilder: (context, index) {
                  final group = customerProvider.customerGroups[index];
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: group.discountPercent >= 0
                            ? Colors.green[100]
                            : Colors.red[100],
                        child: Icon(
                          group.discountPercent >= 0
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          color: group.discountPercent >= 0
                              ? Colors.green[700]
                              : Colors.red[700],
                        ),
                      ),
                      title: Text(
                        group.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            group.discountPercent >= 0
                                ? 'Giảm giá: ${group.discountPercent.toStringAsFixed(1)}%'
                                : 'Tăng giá: ${group.discountPercent.abs().toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: group.discountPercent >= 0
                                  ? Colors.green[700]
                                  : Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (group.description != null && group.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              group.description!,
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditGroupDialog(context, group),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddGroupDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Hiển thị dialog thêm nhóm
  void _showAddGroupDialog(BuildContext context, [CustomerGroupModel? group]) {
    final nameController = TextEditingController(text: group?.name ?? '');
    final discountController = TextEditingController(
      text: group?.discountPercent.toString() ?? '',
    );
    final descriptionController = TextEditingController(text: group?.description ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(group == null ? 'Thêm nhóm khách hàng' : 'Sửa nhóm khách hàng'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tên nhóm *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập tên nhóm';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: discountController,
                  decoration: const InputDecoration(
                    labelText: '% Ưu đãi *',
                    hintText: 'Nhập 5 để giảm 5%, -10 để tăng 10%',
                    border: OutlineInputBorder(),
                    suffixText: '%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập % ưu đãi';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Giá trị không hợp lệ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Hướng dẫn',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Nhập 5 để giảm giá 5%\n'
                        '• Nhập -10 để tăng giá 10% (cho khách nợ)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Mô tả',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
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
                final discount = double.parse(discountController.text);
                final newGroup = CustomerGroupModel(
                  id: group?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  discountPercent: discount,
                  description: descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  createdAt: group?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                final customerProvider = context.read<CustomerProvider>();
                final success = group == null
                    ? await customerProvider.addCustomerGroup(newGroup)
                    : await customerProvider.updateCustomerGroup(newGroup);

                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(group == null
                            ? 'Đã thêm nhóm khách hàng'
                            : 'Đã cập nhật nhóm khách hàng'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          customerProvider.errorMessage ?? 'Có lỗi xảy ra',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              }
            },
            child: Text(group == null ? 'Thêm' : 'Cập nhật'),
          ),
        ],
      ),
    );
  }

  /// Hiển thị dialog sửa nhóm
  void _showEditGroupDialog(BuildContext context, CustomerGroupModel group) {
    _showAddGroupDialog(context, group);
  }

  /// Hiển thị xác nhận xóa
  void _showDeleteConfirmation(BuildContext context, CustomerGroupModel group) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc muốn xóa nhóm "${group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () async {
              final customerProvider = context.read<CustomerProvider>();
              final success = await customerProvider.deleteCustomerGroup(group.id);
              
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã xóa nhóm khách hàng'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        customerProvider.errorMessage ?? 'Có lỗi xảy ra',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }
}
