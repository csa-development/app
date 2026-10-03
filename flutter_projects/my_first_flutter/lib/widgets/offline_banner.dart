import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../services/connectivity_service.dart';

/// Wraps the whole app (via MaterialApp.builder). While the phone has no
/// network, a small red "You're offline" banner floats at the top of every
/// screen. The screen underneath does not move.
///
/// It stays until the connection returns. The user can also swipe it up to
/// get it out of the way; it then stays hidden for the rest of that outage and
/// comes back if the connection drops again later.
class OfflineBanner extends StatefulWidget {
  final Widget child;
  final ValueListenable<bool>? offline;

  const OfflineBanner({super.key, required this.child, this.offline});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  // How far (px) or how fast (px/s) an upward swipe has to be to count.
  static const double _dismissDistance = 24;
  static const double _dismissVelocity = 250;

  late final ValueListenable<bool> _offline =
      widget.offline ?? ConnectivityService.isOffline;

  bool _dismissed = false;
  double _dragOffset = 0; // 0 or negative: how far it's been pulled up
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _offline.addListener(_onConnectionChanged);
  }

  @override
  void dispose() {
    _offline.removeListener(_onConnectionChanged);
    super.dispose();
  }

  // Going offline or coming back online both start a fresh state: a banner
  // swiped away during one outage must show again for the next.
  void _onConnectionChanged() {
    if (!mounted) return;
    setState(() {
      _dismissed = false;
      _dragOffset = 0;
      _isDragging = false;
    });
  }

  void _onDragStart(DragStartDetails details) {
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      // Only upward; pulling down does nothing.
      _dragOffset = (_dragOffset + details.delta.dy).clamp(-120.0, 0.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final swipedUp =
        _dragOffset <= -_dismissDistance || velocity <= -_dismissVelocity;
    setState(() {
      _isDragging = false;
      if (swipedUp) {
        _dismissed = true; // the banner slides on up and out
      } else {
        _dragOffset = 0; // not a real swipe: ease back into place
      }
    });
  }

  Widget _banner(double topInset) {
    return Padding(
      // Sits just under the status bar. The padding itself takes no touches,
      // so only the banner is tappable and the screen behind it still works.
      padding: EdgeInsets.fromLTRB(12, topInset + 6, 12, 0),
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onVerticalDragStart: _onDragStart,
        onVerticalDragUpdate: _onDragUpdate,
        onVerticalDragEnd: _onDragEnd,
        child: AnimatedContainer(
          // Follows the finger instantly while dragging; eases back when
          // released without a swipe.
          duration:
              _isDragging ? Duration.zero : const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _dragOffset, 0),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.red.shade700,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "You're offline.",
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(
                            text: ' Check your Wi-Fi or mobile data.',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      style: TextStyle(fontSize: 12, color: Colors.white),
                    ),
                  ),
                  SizedBox(width: 6),
                  // A hint that it can be swiped up.
                  Icon(Icons.keyboard_arrow_up_rounded,
                      color: Colors.white70, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _offline,
      builder: (context, isOffline, _) {
        final visible = isOffline && !_dismissed;
        final topInset = MediaQuery.of(context).padding.top;

        return Stack(
          fit: StackFit.expand,
          children: [
            widget.child,
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(end: visible ? 1 : 0),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                builder: (context, t, child) {
                  if (t == 0) return const SizedBox.shrink();
                  // Slides down from above the screen when it appears and
                  // back up when it goes.
                  return FractionalTranslation(
                    translation: Offset(0, -(1 - t)),
                    child: child,
                  );
                },
                child: _banner(topInset),
              ),
            ),
          ],
        );
      },
    );
  }
}
