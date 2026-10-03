import 'package:flutter/material.dart';

import 'registration_screen.dart';
import 'registration_screen_2.dart';
import '../widgets/top_toast.dart';

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

void showRegistrationTopError(
  BuildContext context,
  String message,
) {
  showTopToast(context, message);
}