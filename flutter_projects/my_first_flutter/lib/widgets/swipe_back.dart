import 'package:flutter/material.dart';

// Shared swipe-to-go-back wrappers so every screen doesn't hand-roll
// its own GestureDetector. Two variants, matching what the screen
// underneath can tolerate:
//
// - SwipeBack: full-screen right-swipe. Use on screens with no
//   horizontal scrolling/carousel content of their own (a right
//   swipe anywhere can't collide with anything else).
// - EdgeSwipeBack: only the left ~32px strip triggers back. Use on
//   screens that contain their own horizontal gesture surface
//   (PageView carousels, horizontal tab strips, maps, image
//   galleries) so a normal right-swipe on that content still reaches
//   it untouched.
//
// Both default to Navigator.pop(context) — pass onBack to go
// somewhere else (e.g. a PageView-based flow's own step-back).

const double kSwipeBackVelocityThreshold = 300;

// Wide enough to catch a swipe that starts anywhere near the left
// portion of the screen (not just a precise edge-hugging gesture),
// while still leaving the right ~80% of a typical phone screen free
// for the carousel/tabs/map this wraps to use normally.
const double kSwipeBackEdgeWidth = 100;

class SwipeBack extends StatelessWidget {
  final Widget child;
  final VoidCallback? onBack;

  const SwipeBack({super.key, required this.child, this.onBack});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > kSwipeBackVelocityThreshold) {
          (onBack ?? () => Navigator.maybePop(context))();
        }
      },
      child: child,
    );
  }
}

class EdgeSwipeBack extends StatefulWidget {
  final Widget child;
  final VoidCallback? onBack;
  final double edgeWidth;

  const EdgeSwipeBack({
    super.key,
    required this.child,
    this.onBack,
    this.edgeWidth = kSwipeBackEdgeWidth,
  });

  @override
  State<EdgeSwipeBack> createState() => _EdgeSwipeBackState();
}

class _EdgeSwipeBackState extends State<EdgeSwipeBack> {
  bool _startedAtEdge = false;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: widget.edgeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) => _startedAtEdge = true,
            onHorizontalDragEnd: (details) {
              if (_startedAtEdge &&
                  (details.primaryVelocity ?? 0) >
                      kSwipeBackVelocityThreshold) {
                (widget.onBack ?? () => Navigator.maybePop(context))();
              }
              _startedAtEdge = false;
            },
          ),
        ),
      ],
    );
  }
}
