import 'package:flutter/material.dart';

import '../utils/platform_utils.dart';
import 'main_scaffold_mobile.dart';
import 'main_scaffold_desktop.dart';

/// MainScaffold: chọn giao diện theo platform.
/// - Mobile (Android/iOS): MainScaffoldMobile (BottomNav + nested Navigator)
/// - Desktop (Windows/Mac/Linux/Web): MainScaffoldDesktop (Sidebar + IndexedStack)
class MainScaffold extends StatelessWidget {
  const MainScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    if (isMobilePlatform) {
      return const MainScaffoldMobile();
    }
    return const MainScaffoldDesktop();
  }
}
