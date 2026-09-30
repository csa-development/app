import 'package:flutter/material.dart';

// Shared top-sliding toast, matching the pattern already used on the
// Continue/Login/Verification/Registration screens — replaces
// ScaffoldMessenger's default bottom SnackBar so feedback (validation
// errors, success messages) consistently appears from the top across
// the app.

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
  late final AnimationController _controller;
  late final Animation<Offset> _slide;

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

    Future.delayed(
      const Duration(milliseconds: 2500),
      () async {
        if (!mounted) return;

        await _controller.reverse();
        widget.onDismiss();
      },
    );
  }

  @override
  void dispose() {
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
    );
  }
}
