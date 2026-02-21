import 'package:flutter/material.dart';
import '../../widgets/responsive_container.dart';

/// Layout body cho màn hình bán hàng - giao diện Desktop.
/// Hai cột: trái (sản phẩm/giỏ), phải (khách hàng/thanh toán).
class SalesScreenDesktopBody extends StatelessWidget {
  const SalesScreenDesktopBody({
    super.key,
    required this.productGrid,
    required this.cartAndPayment,
    this.cartItemCount = 0,
  });

  final Widget productGrid;
  final Widget cartAndPayment;
  final int cartItemCount;

  @override
  Widget build(BuildContext context) {
    return SalesLayoutBuilder(
      productGrid: productGrid,
      cartAndPayment: cartAndPayment,
      cartItemCount: cartItemCount,
      mobileUseFabForCart: false,
    );
  }
}
