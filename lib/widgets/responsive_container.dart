import 'package:flutter/material.dart';

// ==================== BREAKPOINTS CHUẨN ====================
/// Ngưỡng chiều rộng: dưới giá trị này = Mobile
const double kBreakpointMobile = 600;

/// Ngưỡng chiều rộng: từ [kBreakpointMobile] đến dưới giá trị này = Tablet
const double kBreakpointTablet = 1200;

/// Chiều rộng tối đa cho nội dung trên Desktop (dùng trong ResponsiveContainer mặc định)
const double kContentMaxWidth = 800;

// ==================== HELPERS PHÂN CHIA LOGIC HIỂN THỊ ====================
/// Trả về true nếu màn hình được coi là Mobile (width < [kBreakpointMobile]).
bool isMobile(BuildContext context) {
  return MediaQuery.sizeOf(context).width < kBreakpointMobile;
}

/// Trả về true nếu màn hình được coi là Tablet (width >= [kBreakpointMobile] và < [kBreakpointTablet]).
bool isTablet(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  return w >= kBreakpointMobile && w < kBreakpointTablet;
}

/// Trả về true nếu màn hình được coi là Desktop (width >= [kBreakpointTablet]).
bool isDesktop(BuildContext context) {
  return MediaQuery.sizeOf(context).width >= kBreakpointTablet;
}

/// Trả về true nếu là màn hình nhỏ (Mobile hoặc Tablet), dùng khi chỉ cần phân biệt "nhỏ" vs "lớn".
bool isSmallScreen(BuildContext context) {
  return MediaQuery.sizeOf(context).width < kBreakpointTablet;
}

// ==================== WIDGET ====================
/// Widget container responsive để giới hạn chiều rộng nội dung trên màn hình lớn
/// và căn giữa nội dung. Mặc định [maxWidth] = [kContentMaxWidth].
class ResponsiveContainer extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;

  const ResponsiveContainer({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: padding != null
            ? Padding(
                padding: padding!,
                child: child,
              )
            : child,
      ),
    );
  }
}

