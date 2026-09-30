import 'package:flutter/material.dart';

import 'registration_screen.dart';
import 'registration_screen_2.dart';

class RegistrationFlow extends StatefulWidget {
  const RegistrationFlow({super.key});

  @override
  State<RegistrationFlow> createState() => _RegistrationFlowState();
}

class _RegistrationFlowState extends State<RegistrationFlow> {
  final PageController _pageController = PageController();

  // Step 1 fields
  final firstNameController = TextEditingController();
  final surnameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  // Step 2 fields
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();

    firstNameController.dispose();
    surnameController.dispose();
    emailController.dispose();
    phoneController.dispose();

    passwordController.dispose();
    confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // STEP 1 → STEP 2
  // Only the NEXT button calls this.
  // ============================================================

  void goToStep2() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ============================================================
  // STEP 2 → STEP 1
  // Back arrow or RIGHT swipe calls this.
  // ============================================================

  void goToStep1() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ============================================================
  // REGISTRATION STEP 1
  //
  // Swipe RIGHT = return to Continue screen.
  // Swipe LEFT  = do nothing.
  // ============================================================

  void _handleStep1Swipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity > 300) {
      Navigator.pop(context);
    }
  }

  // ============================================================
  // REGISTRATION STEP 2
  //
  // Swipe RIGHT = return to Step 1.
  // Swipe LEFT  = do nothing.
  // ============================================================

  void _handleStep2Swipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity > 300) {
      goToStep1();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: PageView(
        controller: _pageController,

        // Prevents free left/right PageView swiping.
        // Navigation is now controlled intentionally.
        physics: const NeverScrollableScrollPhysics(),

        children: [
          // ====================================================
          // REGISTRATION STEP 1
          // ====================================================

          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _handleStep1Swipe,
            child: RegistrationScreen(
              firstNameController: firstNameController,
              surnameController: surnameController,
              emailController: emailController,
              phoneController: phoneController,
              onNext: goToStep2,
            ),
          ),

          // ====================================================
          // REGISTRATION STEP 2
          // ====================================================

          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _handleStep2Swipe,
            child: RegistrationScreen2(
              firstNameController: firstNameController,
              surnameController: surnameController,
              emailController: emailController,
              phoneController: phoneController,
              passwordController: passwordController,
              confirmPasswordController: confirmPasswordController,
              onBack: goToStep1,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SHARED TOP TOAST
// ============================================================

class RegistrationTopToast extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const RegistrationTopToast({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  @override
  State<RegistrationTopToast> createState() =>
      _RegistrationTopToastState();
}

class _RegistrationTopToastState
    extends State<RegistrationTopToast>
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
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
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

void showRegistrationTopError(
  BuildContext context,
  String message,
) {
  final overlay = Overlay.of(context);

  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (_) => RegistrationTopToast(
      message: message,
      onDismiss: () => entry.remove(),
    ),
  );

  overlay.insert(entry);
}