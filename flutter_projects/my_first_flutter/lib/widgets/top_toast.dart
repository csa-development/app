import 'dart:async';

import 'package:flutter/material.dart';

// The one banner used everywhere in the app (validation errors, success
// messages, info). It slides in from the top and leaves by itself after a
// couple of seconds; swiping it up sends it away immediately.

void showTopToast(
  BuildContext context,
  String message, {
  bool isError = true,
  // Lets callers preserve a neutral (e.g. black54 "info") tone from an
  // old SnackBar instead of forcing red/green — same color, just moved
  // to slide in from the top.
  Color? backgroundColor,
  IconData? icon,
}) {
  final overlay = Overlay.of(context);

  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => _TopToast(
      message: message,
      isError: isError,
      backgroundColor: backgroundColor,
      icon: icon,
      onDismiss: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}

class _TopToast extends StatefulWidget {
  final String message;
  final bool isError;
  final Color? backgroundColor;
  final IconData? icon;
  final VoidCallback onDismiss;

  const _TopToast({
    required this.message,
    required this.onDismiss,
    this.isError = true,
    this.backgroundColor,
    this.icon,
  });

  @override
  State<_TopToast> createState() => _TopToastState();
}

class _TopToastState extends State<_TopToast>
    with SingleTickerProviderStateMixin {
  static const Duration _visibleFor = Duration(milliseconds: 2500);
  // After a half-finished swipe snaps back, it stays a little longer
  // before leaving on its own.
  static const Duration _visibleAfterSnapBack = Duration(milliseconds: 1500);
  // How far (px) or how fast (px/s) an upward swipe has to be to count.
  static const double _dismissDistance = 24;
  static const double _dismissVelocity = 250;

  late final AnimationController _controller;
  late final Animation<Offset> _slide;

  Timer? _autoDismissTimer;
  double _dragOffset = 0; // 0 or negative: how far it's been pulled up
  bool _isDragging = false;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
    _startAutoDismissTimer(_visibleFor);
  }

  void _startAutoDismissTimer(Duration after) {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(after, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _autoDismissTimer?.cancel();

    // Slides on up from wherever it currently is (including mid-swipe).
    await _controller.reverse();
    widget.onDismiss();
  }

  void _onDragStart(DragStartDetails details) {
    if (_isDismissing) return;
    // Don't let it vanish out from under the user's finger.
    _autoDismissTimer?.cancel();
    setState(() => _isDragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isDismissing) return;
    setState(() {
      // Only upward; pulling down does nothing.
      _dragOffset = (_dragOffset + details.delta.dy).clamp(-200.0, 0.0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isDismissing) return;
    final velocity = details.primaryVelocity ?? 0;
    final swipedUp =
        _dragOffset <= -_dismissDistance || velocity <= -_dismissVelocity;

    setState(() => _isDragging = false);

    if (swipedUp) {
      _dismiss();
    } else {
      // Not a real swipe: ease back into place, then carry on as usual.
      setState(() => _dragOffset = 0);
      _startAutoDismissTimer(_visibleAfterSnapBack);
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final background = widget.backgroundColor ??
        (widget.isError ? Colors.red : Colors.green);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: SlideTransition(
          position: _slide,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _onDragStart,
            onVerticalDragUpdate: _onDragUpdate,
            onVerticalDragEnd: _onDragEnd,
            child: AnimatedContainer(
              // Follows the finger instantly while dragging; eases back
              // when released without a swipe.
              duration: _isDragging
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(0, _dragOffset, 0),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: background,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          widget.icon ??
                              (widget.isError
                                  ? Icons.error_outline
                                  : Icons.check_circle_outline),
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            widget.message,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
