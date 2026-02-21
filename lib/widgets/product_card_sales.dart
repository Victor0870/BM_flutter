import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import 'responsive_container.dart';
import 'variant_picker_modal.dart';

// ─── Design tokens (aligned with product list mobile) ─────────────────────────
const double _kCardRadius = 16;
const double _kShadowBlur = 10;
const double _kShadowOpacity = 0.04;
const double _kNameSize = 16;
const double _kPriceSize = 14;
const double _kPadding = 12;

/// Thẻ sản phẩm dùng cho màn hình bán hàng: ảnh lớn, tên, giá, badge tồn kho.
/// Thiết kế: đổ bóng nhẹ, bo góc 16, typography rõ ràng, giá màu primary.
/// Tap: nếu có biến thể thì mở [VariantPickerModal], không thì gọi [onAddToCart].
class ProductCardSales extends StatelessWidget {
  final ProductModel product;
  final Map<String, String>? branchIdToName;
  final VoidCallback? onAddToCart;
  final void Function(ProductModel product, ProductVariant? variant)? onAddVariantToCart;

  const ProductCardSales({
    super.key,
    required this.product,
    this.branchIdToName,
    this.onAddToCart,
    this.onAddVariantToCart,
  });

  String _stockBadgeText() {
    final stock = product.branchStock;
    if (stock.isEmpty) return '0';
    final names = branchIdToName ?? {};
    final parts = stock.entries
        .where((e) => e.value > 0 || product.inventories.any((i) => i.branchId == e.key))
        .map((e) {
      final name = names[e.key] ?? e.key;
      final qty = e.value.toInt();
      return '$name: $qty';
    })
        .toList();
    if (parts.isEmpty) return '0';
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final hasVariants = product.hasVariants && product.variants.isNotEmpty;
    final imageUrl = product.imageUrl ?? (product.images.isNotEmpty ? product.images.first : null);
    final price = product.price;
    final stockText = _stockBadgeText();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_kCardRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: _kShadowOpacity),
            blurRadius: _kShadowBlur,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_kCardRadius),
        child: InkWell(
          onTap: () {
            if (hasVariants) {
              VariantPickerModal.show(
                context,
                product: product,
                branchIdToName: branchIdToName,
                onSelect: (variant) {
                  if (onAddVariantToCart != null && variant != null) {
                    onAddVariantToCart!(product, variant);
                  }
                },
                onAddSimple: onAddToCart != null ? () => onAddToCart!() : null,
              );
            } else {
              onAddToCart?.call();
            }
          },
          borderRadius: BorderRadius.circular(_kCardRadius),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl != null && imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _placeholderImage(theme),
                      )
                    else
                      _placeholderImage(theme),
                    Positioned(
                      left: kSpacingSm,
                      right: kSpacingSm,
                      bottom: kSpacingSm,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          stockText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (hasVariants)
                      Positioned(
                        top: kSpacingSm,
                        right: kSpacingSm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${product.variants.length} biến thể',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(_kPadding, _kPadding, _kPadding, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: TextStyle(
                        fontSize: _kNameSize,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${NumberFormat('#,###').format(price.toInt())}đ',
                      style: TextStyle(
                        fontSize: _kPriceSize,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderImage(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Icon(
        Icons.image_outlined,
        size: 48,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
    );
  }
}
