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

/// Màn hình thông báo tính năng chỉ dành cho gói PRO (ví dụ: Quản lý nhân viên).
class FeatureProOnlyScreen extends StatelessWidget {
  final String featureName;

  const FeatureProOnlyScreen({super.key, required this.featureName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isDesktopPlatform
          ? null
          : AppBar(
              title: const Text('Yêu cầu gói PRO'),
            ),
      body: ResponsiveContainer(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium, size: 72, color: Colors.amber.shade700),
              const SizedBox(height: 16),
              Text(
                'Tính năng "$featureName" chỉ có ở gói PRO',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, AppRoutes.accountPackage);
                    },
                    icon: const Icon(Icons.card_membership),
                    label: const Text('Xem gói dịch vụ'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context,
                        AppRoutes.home,
                        (route) => false,
                      );
                    },
                    icon: const Icon(Icons.home),
                    label: const Text('Về trang chủ'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

