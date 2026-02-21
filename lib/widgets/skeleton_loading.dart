import 'package:flutter/material.dart';

/// Skeleton loading theo Material Design 3 — shimmer nhẹ, bo góc, spacing tinh tế.
class SkeletonLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  @override
  State<SkeletonLoading> createState() => _SkeletonLoadingState();
}

class _SkeletonLoadingState extends State<SkeletonLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final highlight = isDark ? const Color(0xFF4B5563) : const Color(0xFFF3F4F6);

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            color: Color.lerp(base, highlight, 0.3 + 0.4 * _animation.value),
          ),
        );
      },
    );
  }
}

/// Skeleton cho danh sách sản phẩm dạng grid (ảnh + tên + giá).
class SkeletonProductGrid extends StatelessWidget {
  final int crossAxisCount;
  final int itemCount;
  final double aspectRatio;
  final double spacing;

  const SkeletonProductGrid({
    super.key,
    this.crossAxisCount = 3,
    this.itemCount = 9,
    this.aspectRatio = 0.85,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(spacing),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: spacing,
        crossAxisSpacing: spacing,
        childAspectRatio: aspectRatio,
      ),
      itemCount: itemCount,
      itemBuilder: (_, _) => _SkeletonProductCard(aspectRatio: aspectRatio),
    );
  }
}

class _SkeletonProductCard extends StatelessWidget {
  final double aspectRatio;

  const _SkeletonProductCard({required this.aspectRatio});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: (aspectRatio * 100).round(),
          child: const SkeletonLoading(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 12,
          ),
        ),
        const SizedBox(height: 8),
        SkeletonLoading(
          width: double.infinity,
          height: 14,
          borderRadius: 4,
        ),
        const SizedBox(height: 6),
        SkeletonLoading(
          width: 80,
          height: 12,
          borderRadius: 4,
        ),
      ],
    );
  }
}

/// Skeleton cho danh sách dạng list (1 dòng = avatar + 2 dòng chữ).
class SkeletonListTile extends StatelessWidget {
  final double height;

  const SkeletonListTile({super.key, this.height = 72});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          SkeletonLoading(
            width: 48,
            height: 48,
            borderRadius: 12,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SkeletonLoading(
                  width: double.infinity,
                  height: 14,
                  borderRadius: 4,
                ),
                const SizedBox(height: 8),
                SkeletonLoading(
                  width: 120,
                  height: 12,
                  borderRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton cho cả list (n items).
class SkeletonListView extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const SkeletonListView({
    super.key,
    this.itemCount = 8,
    this.itemHeight = 72,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (_, _) => SkeletonListTile(height: itemHeight),
    );
  }
}
