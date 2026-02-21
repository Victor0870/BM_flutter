import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_provider.dart';
import '../controllers/tutorial_provider.dart';
import '../widgets/responsive_container.dart';
import 'main_scaffold_mobile.dart';
import 'main_scaffold_desktop.dart';

/// MainScaffold: chọn giao diện theo chiều rộng màn hình (Material Design 3).
/// Sau khi auth thành công, kiểm tra tutorial flags và hiển thị AlertDialog chào mừng nếu cần.
class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  bool _welcomeCheckDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkWelcomeAndTutorial());
  }

  Future<void> _checkWelcomeAndTutorial() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    final tutorialProvider = context.read<TutorialProvider>();
    if (!authProvider.isAuthenticated) return;
    if (!tutorialProvider.flagsLoaded) return;
    if (_welcomeCheckDone) return;
    if (tutorialProvider.hasSeenWelcomePopup) return;
    _welcomeCheckDone = true;
    if (!mounted) return;
    _showWelcomeDialog(context, tutorialProvider);
  }

  void _showWelcomeDialog(BuildContext context, TutorialProvider tutorialProvider) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Chào mừng đến với BizMate'),
        content: const Text(
          'Bạn có muốn xem hướng dẫn nhanh về các chức năng chính của ứng dụng không?',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await tutorialProvider.setHasSeenWelcomePopup(true);
            },
            child: const Text('Bỏ qua'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await tutorialProvider.setHasSeenWelcomePopup(true);
              tutorialProvider.requestPhase1Tour();
            },
            child: const Text('Bắt đầu'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < kBreakpointMobile) {
      return const MainScaffoldMobile();
    }
    return MainScaffoldDesktop(useRail: width < kBreakpointTablet);
  }
}
