import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_provider.dart';
import '../../models/supplier_model.dart';
import '../../services/supplier_service.dart';
import '../../core/routes.dart';

/// Màn hình danh sách nhà cung cấp: list + FAB thêm.
class SupplierListScreen extends StatelessWidget {
  const SupplierListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhà cung cấp'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _openForm(context, null),
            tooltip: 'Thêm nhà cung cấp',
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, _) {
          final userId = authProvider.user?.uid;
          if (userId == null || userId.isEmpty) {
            return const Center(child: Text('Vui lòng đăng nhập.'));
          }
          final service = SupplierService(userId: userId);
          return StreamBuilder<List<SupplierModel>>(
            stream: service.streamByShop(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Lỗi: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final list = snapshot.data!;
              if (list.isEmpty) {
                return _EmptyState(onAdd: () => _openForm(context, null));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final supplier = list[index];
                  return _SupplierTile(
                    supplier: supplier,
                    onTap: () => _openForm(context, supplier),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Thêm nhà cung cấp'),
      ),
    );
  }

  void _openForm(BuildContext context, SupplierModel? supplier) {
    Navigator.pushNamed(
      context,
      AppRoutes.supplierForm,
      arguments: supplier,
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_center_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'Chưa có nhà cung cấp',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Thêm nhà cung cấp để chọn khi nhập kho.',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Thêm nhà cung cấp'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupplierTile extends StatelessWidget {
  final SupplierModel supplier;
  final VoidCallback onTap;

  const _SupplierTile({required this.supplier, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.2),
          child: const Icon(Icons.business_center, color: Color(0xFF0D9488)),
        ),
        title: Text(
          supplier.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: supplier.phone != null && supplier.phone!.isNotEmpty
            ? Text(supplier.phone!)
            : (supplier.address != null && supplier.address!.isNotEmpty
                ? Text(supplier.address!, maxLines: 1, overflow: TextOverflow.ellipsis)
                : null),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
