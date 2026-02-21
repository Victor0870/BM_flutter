import 'package:flutter/material.dart';

import '../core/routes.dart';

/// Hiển thị popup thông báo tính năng chỉ dành cho gói PRO.
/// Có nút OK và nút "Gói tài khoản" để chuyển đến màn giới thiệu gói.
Future<void> showProRequiredDialog(
  BuildContext context, {
  String? featureName,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Tính năng gói PRO'),
      content: Text(
        featureName != null
            ? 'Đây là tính năng của bản PRO ($featureName). Vui lòng nâng cấp để sử dụng.'
            : 'Đây là tính năng của bản PRO. Vui lòng nâng cấp để sử dụng.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('OK'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            Navigator.pushNamed(ctx, AppRoutes.accountPackage);
          },
          child: const Text('Gói tài khoản'),
        ),
      ],
    ),
  );
}
