import 'package:flutter/material.dart';

class PremiumSkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius borderRadius;

  const PremiumSkeleton({
    super.key,
    this.height = 16,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
  });

  @override
  State<PremiumSkeleton> createState() => _PremiumSkeletonState();
}

class _PremiumSkeletonState extends State<PremiumSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 - _controller.value * 2, 0),
              end: Alignment(1.0 - _controller.value * 2, 0),
              colors: [
                base.withValues(alpha: 0.4),
                base.withValues(alpha: 0.8),
                base.withValues(alpha: 0.4),
              ],
            ),
          ),
        );
      },
    );
  }
}

class PremiumSkeletonList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const PremiumSkeletonList({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: PremiumSkeleton(height: itemHeight),
        ),
      ),
    );
  }
}

class PremiumSkeletonCard extends StatelessWidget {
  const PremiumSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            PremiumSkeleton(height: 20, width: 160),
            SizedBox(height: 16),
            PremiumSkeleton(height: 14),
            SizedBox(height: 8),
            PremiumSkeleton(height: 14, width: 240),
          ],
        ),
      ),
    );
  }
}
