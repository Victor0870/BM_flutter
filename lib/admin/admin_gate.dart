import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'admin_auth_provider.dart';
import 'admin_login_screen.dart';
import 'admin_dashboard_screen.dart';

/// Kiểm tra đăng nhập và quyền admin: chưa đăng nhập -> Login; đã đăng nhập nhưng không phải admin -> đăng xuất + thông báo; là admin -> Dashboard.
class AdminGate extends StatelessWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminAuthProvider>(
      builder: (context, auth, _) {
        if (auth.isCheckingAdmin && auth.isAuthenticated) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Đang kiểm tra quyền admin...'),
                ],
              ),
            ),
          );
        }
        if (!auth.isAuthenticated) {
          return const AdminLoginScreen();
        }
        if (!auth.isAdmin) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.block, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Bạn không có quyền truy cập trang Admin.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => auth.signOut(),
                      child: const Text('Đăng xuất'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return const AdminDashboardScreen();
      },
    );
  }
}
