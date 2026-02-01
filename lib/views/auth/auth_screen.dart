import 'package:flutter/material.dart';

import '../../utils/platform_utils.dart';
import 'auth_screen_mobile.dart';
import 'auth_screen_desktop.dart';

/// AuthScreen: chọn giao diện theo platform.
/// - Mobile (Android/iOS): AuthScreenMobile
/// - Desktop (Windows/Mac/Linux/Web): AuthScreenDesktop
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (isMobilePlatform) {
      return const AuthScreenMobile();
    }
    return const AuthScreenDesktop();
  }
}
