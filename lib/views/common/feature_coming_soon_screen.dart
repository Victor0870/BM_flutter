import 'package:flutter/material.dart';

import '../../core/routes.dart';
import '../../utils/platform_utils.dart';
import '../../widgets/responsive_container.dart';

/// Màn hình dùng chung hiển thị thông báo "Tính năng đang được phát triển" (mobile/desktop theo platform).
class FeatureComingSoonScreen extends StatelessWidget {
  final String title;
  /// Nếu null: dùng [isMobilePlatform].
  final bool? forceMobile;

  const FeatureComingSoonScreen({
    super.key,
    required this.title,
    this.forceMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktopPlatform
          ? null
          : AppBar(
              title: Text(title),
            ),
      body: ResponsiveContainer(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.construction, size: 72, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Tính năng "$title" đang được phát triển',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.home,
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.home),
                label: const Text('Quay về trang tổng quan'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

