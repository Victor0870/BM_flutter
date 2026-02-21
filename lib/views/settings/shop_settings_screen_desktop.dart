import 'package:flutter/material.dart';

/// Layout body cho màn hình Cài đặt shop - Desktop.
/// Nhận nội dung form đã build sẵn từ coordinator.
/// Có thể mở rộng thêm sidebar TOC, 2 cột, v.v.
class ShopSettingsDesktopBody extends StatelessWidget {
  const ShopSettingsDesktopBody({
    super.key,
    required this.formContent,
  });

  final Widget formContent;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: formContent,
    );
  }
}
