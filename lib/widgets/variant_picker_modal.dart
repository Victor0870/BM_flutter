import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/product_model.dart';
import 'responsive_container.dart';

/// Modal chọn biến thể (Màu sắc, Size) bằng Chips thay vì dropdown.
/// Gọi [VariantPickerModal.show], truyền [onSelect(variant)] hoặc [onAddSimple] nếu thêm luôn sản phẩm không chọn biến thể.
class VariantPickerModal extends StatelessWidget {
  final ProductModel product;
  final Map<String, String>? branchIdToName;
  final void Function(ProductVariant? variant)? onSelect;
  final VoidCallback? onAddSimple;

  const VariantPickerModal({
    super.key,
    required this.product,
    this.branchIdToName,
    this.onSelect,
    this.onAddSimple,
  });

  static Future<void> show(
    BuildContext context, {
    required ProductModel product,
    Map<String, String>? branchIdToName,
    void Function(ProductVariant? variant)? onSelect,
    VoidCallback? onAddSimple,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => VariantPickerModal(
        product: product,
        branchIdToName: branchIdToName,
        onSelect: onSelect,
        onAddSimple: onAddSimple,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final variants = product.variants;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingMd, kSpacingLg, kSpacingSm),
            child: Text(
              product.name,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: kSpacingLg),
            child: Text(
              'Chọn biến thể',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: kSpacingSm),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(kSpacingLg, kSpacingSm, kSpacingLg, kSpacingLg),
              child: Wrap(
                spacing: kSpacingSm,
                runSpacing: kSpacingSm,
                children: variants.map((v) {
                  final price = v.price;
                  final stock = v.stock;
                  final canAdd = stock > 0;
                  return FilterChip(
                    selected: false,
                    showCheckmark: false,
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.name,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${NumberFormat('#,###').format(price.toInt())}đ • Tồn: ${stock.toInt()}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    onSelected: (selected) {
                      if (canAdd) {
                        onSelect?.call(v);
                        Navigator.of(context).pop();
                      }
                    },
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    disabledColor: theme.colorScheme.surfaceContainerHighest,
                  );
                }).toList(),
              ),
            ),
          ),
          if (onAddSimple != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(kSpacingLg, 0, kSpacingLg, kSpacingLg),
              child: OutlinedButton(
                onPressed: () {
                  onAddSimple!();
                  Navigator.of(context).pop();
                },
                child: const Text('Thêm sản phẩm (mặc định)'),
              ),
            ),
        ],
      ),
    );
  }
}
