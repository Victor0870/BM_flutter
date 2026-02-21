import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_provider.dart';
import '../core/routes.dart';

/// Bọc nội dung màn hình và kiểm tra quyền. Nếu không đủ quyền thì hiển thị "Bạn không có quyền truy cập" và nút về Trang chủ.
class PermissionGuard extends StatelessWidget {
  const PermissionGuard({
    super.key,
    required this.requiredPermission,
    required this.child,
  });

  final String requiredPermission;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (auth.hasPermission(requiredPermission)) {
      return child;
    }
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(
                'Bạn không có quyền truy cập trang này',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Liên hệ quản lý để được cấp quyền phù hợp.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
                icon: const Icon(Icons.home),
                label: const Text('Về Trang chủ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
