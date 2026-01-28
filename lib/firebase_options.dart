// File này sẽ được tự động tạo bởi lệnh `flutterfire configure`
// 
// Để tạo file này:
// 1. Cài đặt Firebase CLI: npm install -g firebase-tools
// 2. Đăng nhập: firebase login
// 3. Cài đặt FlutterFire CLI: dart pub global activate flutterfire_cli
// 4. Chạy: flutterfire configure
//
// File này sẽ chứa cấu hình Firebase cho tất cả các platforms

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB3poeFCUsilXzqAyXzXFEDbK6LOPlJ6WA',
    appId: '1:924296680961:web:214b1537a63cb8187c5200',
    messagingSenderId: '924296680961',
    projectId: 'bizmate-1e317',
    authDomain: 'bizmate-1e317.firebaseapp.com',
    storageBucket: 'bizmate-1e317.firebasestorage.app',
    measurementId: 'G-LDL92GXJ59',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAai4udZ0epzb2xGiifuQDqwIHW2MAxj8U',
    appId: '1:924296680961:ios:79b6e6080413d2347c5200',
    messagingSenderId: '924296680961',
    projectId: 'bizmate-1e317',
    storageBucket: 'bizmate-1e317.firebasestorage.app',
    androidClientId: '924296680961-n39smgp6qh2fgsfngdcfafjhco1jed9u.apps.googleusercontent.com',
    iosClientId: '924296680961-07fo728gd3s5jdr9tghtqutscmimp0i2.apps.googleusercontent.com',
    iosBundleId: 'com.example.bizmateApp',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAai4udZ0epzb2xGiifuQDqwIHW2MAxj8U',
    appId: '1:924296680961:ios:79b6e6080413d2347c5200',
    messagingSenderId: '924296680961',
    projectId: 'bizmate-1e317',
    storageBucket: 'bizmate-1e317.firebasestorage.app',
    androidClientId: '924296680961-n39smgp6qh2fgsfngdcfafjhco1jed9u.apps.googleusercontent.com',
    iosClientId: '924296680961-07fo728gd3s5jdr9tghtqutscmimp0i2.apps.googleusercontent.com',
    iosBundleId: 'com.example.bizmateApp',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBFNwRPNCkk5xA7v2c41_RB2Rg33o55DTw',
    appId: '1:924296680961:android:3f36006871a542337c5200',
    messagingSenderId: '924296680961',
    projectId: 'bizmate-1e317',
    storageBucket: 'bizmate-1e317.firebasestorage.app',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyB3poeFCUsilXzqAyXzXFEDbK6LOPlJ6WA',
    appId: '1:924296680961:web:a398f35ca10ee0ec7c5200',
    messagingSenderId: '924296680961',
    projectId: 'bizmate-1e317',
    authDomain: 'bizmate-1e317.firebaseapp.com',
    storageBucket: 'bizmate-1e317.firebasestorage.app',
    measurementId: 'G-T1N1L0W512',
  );

}
