import 'platform_utils_io.dart'
    if (dart.library.html) 'platform_utils_web.dart' as impl;

bool get isMobilePlatform => impl.isMobilePlatform;
bool get isDesktopPlatform => impl.isDesktopPlatform;
bool get isAndroidPlatform => impl.isAndroidPlatform;
