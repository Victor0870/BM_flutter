import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'admin/admin_app.dart';

/// Entry point chỉ cho bản Web Admin.
/// Build: flutter build web -t lib/main_admin.dart
/// App shop (APK, desktop) dùng main.dart — không chứa code admin.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Error initializing Firebase: $e');
  }

  runApp(const AdminApp());
}
