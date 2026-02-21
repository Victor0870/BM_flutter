import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/auth_provider.dart';
import '../controllers/product_provider.dart';
import '../controllers/customer_provider.dart';

/// Bọc app để khi chuyển từ background về foreground (resume) thì chạy đồng bộ tăng dần
/// (products + customers), giảm lượt đọc Firestore.
class SyncOnResumeWrapper extends StatefulWidget {
  const SyncOnResumeWrapper({super.key, required this.child});

  final Widget child;

  @override
  State<SyncOnResumeWrapper> createState() => _SyncOnResumeWrapperState();
}

class _SyncOnResumeWrapperState extends State<SyncOnResumeWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _runIncrementalSync());
  }

  void _runIncrementalSync() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.user == null || !auth.isPro) return;
    context.read<ProductProvider>().syncIncremental();
    context.read<CustomerProvider>().syncIncremental();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
