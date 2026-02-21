import 'package:flutter/material.dart';

// ==================== BREAKPOINTS CHUẨN (Material Design 3) ====================
/// Ngưỡng chiều rộng: dưới giá trị này = Mobile
const double kBreakpointMobile = 600;

/// Ngưỡng chiều rộng: từ [kBreakpointMobile] đến dưới giá trị này = Tablet
const double kBreakpointTablet = 1200;

/// Chiều rộng tối đa cho nội dung trên Desktop (dùng trong ResponsiveContainer mặc định)
const double kContentMaxWidth = 800;

/// Spacing chuẩn (8dp grid)
const double kSpacingXs = 4;
const double kSpacingSm = 8;
const double kSpacingMd = 16;
const double kSpacingLg = 24;
const double kSpacingXl = 32;

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

// ==================== SALES LAYOUT (2 cột Desktop / FAB + BottomSheet Mobile) ====================

/// Layout màn hình bán hàng: Desktop = 2 cột (trái: grid sản phẩm, phải: giỏ + thanh toán);
/// Mobile = toàn màn hình grid + FAB giỏ hàng mở Bottom Sheet.
class SalesLayoutBuilder extends StatelessWidget {
  /// Cột trái: danh sách sản phẩm dạng grid (desktop) hoặc full màn hình (mobile).
  final Widget productGrid;
  /// Cột phải (desktop): giỏ hàng + thanh toán. Trên mobile dùng làm nội dung Bottom Sheet.
  final Widget cartAndPayment;
  /// Số lượng item trong giỏ (để hiển thị badge trên FAB).
  final int cartItemCount;
  /// Trên mobile: có dùng FAB + bottom sheet (true) hay vẫn hiện cart dưới cùng (false).
  final bool mobileUseFabForCart;

  const SalesLayoutBuilder({
    super.key,
    required this.productGrid,
    required this.cartAndPayment,
    this.cartItemCount = 0,
    this.mobileUseFabForCart = true,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= kBreakpointTablet;

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: productGrid,
          ),
          SizedBox(
            width: 400,
            child: Material(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              child: cartAndPayment,
            ),
          ),
        ],
      );
    }

    if (mobileUseFabForCart) {
      return Stack(
        children: [
          productGrid,
          Positioned(
            right: kSpacingMd,
            bottom: kSpacingMd + MediaQuery.paddingOf(context).bottom,
            child: _CartFab(
              cartItemCount: cartItemCount,
              onTap: () => _showCartBottomSheet(context),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(child: productGrid),
        cartAndPayment,
      ],
    );
  }

  void _showCartBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: cartAndPayment,
        ),
      ),
    );
  }
}

class _CartFab extends StatelessWidget {
  final int cartItemCount;
  final VoidCallback onTap;

  const _CartFab({required this.cartItemCount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(16),
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_cart_rounded,
                color: theme.colorScheme.onPrimaryContainer,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Giỏ hàng',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              if (cartItemCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$cartItemCount',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

