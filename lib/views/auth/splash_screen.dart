import 'package:flutter/material.dart';

import '../../utils/platform_utils.dart';
import 'splash_screen_mobile.dart';
import 'splash_screen_desktop.dart';

/// SplashScreen: chọn giao diện theo platform.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (isMobilePlatform) {
      return const SplashScreenMobile();
    }
    return const SplashScreenDesktop();
  }
}
