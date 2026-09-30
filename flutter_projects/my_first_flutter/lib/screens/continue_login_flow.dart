import 'package:flutter/material.dart';

import 'continue_screen.dart';
import 'login_screen.dart';

class ContinueLoginFlow extends StatefulWidget {
  final int initialPage;

  const ContinueLoginFlow({
    super.key,
    this.initialPage = 0,
  });

  @override
  State<ContinueLoginFlow> createState() => _ContinueLoginFlowState();
}

class _ContinueLoginFlowState extends State<ContinueLoginFlow> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();

    _pageController = PageController(
      initialPage: widget.initialPage,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // CONTINUE → LOGIN
  //
  // Only the LOGIN button calls this.
  // Swiping left on Continue does NOTHING.
  // ============================================================

  void _goToLogin() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ============================================================
  // LOGIN → CONTINUE
  //
  // Back arrow or RIGHT swipe calls this.
  // ============================================================

  void _goToContinue() {
    _pageController.animateToPage(
      0,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  // ============================================================
  // LOGIN SWIPE
  //
  // Swipe RIGHT = Continue
  // Swipe LEFT  = nothing
  // ============================================================

  void _handleLoginSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;

    if (velocity > 300) {
      _goToContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: PageView(
        controller: _pageController,

        // Prevents Continue and Login from freely swiping
        // left/right like carousel pages.
        physics: const NeverScrollableScrollPhysics(),

        children: [
          // ====================================================
          // CONTINUE SCREEN
          //
          // No swipe gesture attached.
          // Left swipe = nothing.
          // Right swipe = nothing.
          // ====================================================

          ContinueScreen(
            onGoToLogin: _goToLogin,
          ),

          // ====================================================
          // LOGIN SCREEN
          //
          // Right swipe = Continue.
          // Left swipe = nothing.
          // ====================================================

          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _handleLoginSwipe,
            child: LoginScreen(
              onBack: _goToContinue,
            ),
          ),
        ],
      ),
    );
  }
}