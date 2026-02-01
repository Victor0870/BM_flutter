import 'dart:io' show Platform;

bool get isMobilePlatform => Platform.isAndroid || Platform.isIOS;

bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

bool get isAndroidPlatform => Platform.isAndroid;
