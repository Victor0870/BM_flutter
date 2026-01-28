import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Widget hiển thị banner quảng cáo
/// Chỉ hiển thị trên Android/iOS, ẩn trên các nền tảng khác
class AdBannerWidget extends StatelessWidget {
  const AdBannerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Kiểm tra nền tảng: chỉ hiển thị trên Android hoặc iOS
    final bool isMobile = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    if (!isMobile) {
      // Không hiển thị trên Windows, web, và các nền tảng khác
      return const SizedBox.shrink();
    }

    // Hiển thị placeholder banner trên Android/iOS
    return Container(
      height: 50,
      width: double.infinity,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: const Text(
        'Ad Placeholder',
        style: TextStyle(
          color: Colors.grey,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

