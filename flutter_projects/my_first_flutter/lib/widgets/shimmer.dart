import 'package:flutter/material.dart';

// Sweeps a soft light band across whatever's inside it, on a loop —
// the same shimmer-skeleton effect used on the news/events/home
// loading states, extracted here so it doesn't need to be
// re-duplicated in every screen that wants it.

class Shimmer extends StatefulWidget {
  final Widget child;
  const Shimmer({super.key, required this.child});

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final slide = _controller.value;
            return LinearGradient(
              colors: const [
                Color(0xFFE3E3E3),
                Color(0xFFF6F6F6),
                Color(0xFFE3E3E3),
              ],
              stops: const [0.0, 0.5, 1.0],
              begin: Alignment(-1.0 + 3 * slide, 0),
              end: Alignment(1.0 + 3 * slide, 0),
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// Plain grey rounded-rect placeholder block, matching the skeletons
// used elsewhere.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
