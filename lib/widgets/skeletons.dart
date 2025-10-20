import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class FixerDashboardSkeleton extends StatelessWidget {
  const FixerDashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              children: const [
                _SkeletonCircle(diameter: 56),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(height: 16),
                      SizedBox(height: 8),
                      _SkeletonBox(width: 140, height: 14),
                      SizedBox(height: 6),
                      _SkeletonBox(width: 100, height: 12),
                    ],
                  ),
                ),
                SizedBox(width: 12),
                _SkeletonBox(width: 48, height: 48, radius: 16),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(child: _SkeletonStatisticCard()),
              SizedBox(width: 12),
              Expanded(child: _SkeletonStatisticCard()),
            ],
          ),
          const SizedBox(height: 12),
          const _SkeletonStatisticCard(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonBox(height: 16),
                SizedBox(height: 8),
                _SkeletonBox(width: 160, height: 14),
                SizedBox(height: 14),
                _SkeletonBox(width: 120, height: 32, radius: 12),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(
              3,
              (index) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: _SkeletonBookingTile(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FixerBookingsSkeleton extends StatelessWidget {
  const FixerBookingsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              children: const [
                _SkeletonCircle(diameter: 40),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(height: 16),
                      SizedBox(height: 8),
                      _SkeletonBox(width: 180, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                _SkeletonBox(width: 70, height: 32, radius: 20),
                _SkeletonBox(width: 86, height: 32, radius: 20),
                _SkeletonBox(width: 96, height: 32, radius: 20),
                _SkeletonBox(width: 82, height: 32, radius: 20),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: 8,
              itemBuilder: (context, index) {
                return const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: _SkeletonBookingTile(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonStatisticCard extends StatelessWidget {
  const _SkeletonStatisticCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SkeletonBox(width: 80, height: 12),
          SizedBox(height: 10),
          _SkeletonBox(width: 120, height: 18),
          SizedBox(height: 8),
          _SkeletonBox(width: 60, height: 12),
        ],
      ),
    );
  }
}

class _SkeletonBookingTile extends StatelessWidget {
  const _SkeletonBookingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SkeletonCircle(diameter: 46),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SkeletonBox(height: 16),
                SizedBox(height: 8),
                _SkeletonBox(width: 160, height: 12),
                SizedBox(height: 6),
                _SkeletonBox(width: 110, height: 12),
              ],
            ),
          ),
          SizedBox(width: 12),
          _SkeletonBox(width: 60, height: 28, radius: 12),
        ],
      ),
    );
  }
}

class _ShimmerWrapper extends StatelessWidget {
  const _ShimmerWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2D2D30) : const Color(0xFFE3E6EC);
    final highlightColor =
        isDark ? const Color(0xFF3C3C40) : const Color(0xFFF2F4F8);
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    this.width,
    required this.height,
    this.radius = 12,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width ?? double.infinity,
        height: height,
        color: Colors.white,
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  const _SkeletonCircle({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(diameter / 2),
      child: Container(
        width: diameter,
        height: diameter,
        color: Colors.white,
      ),
    );
  }
}
