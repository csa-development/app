import 'package:flutter/material.dart';

import '../services/auth_storage.dart';
import 'continue_login_flow.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow> {
  static const Color primaryBlue = Color(0xFF00334D);

  final PageController _pageController = PageController();

  bool _imagesPrecached = false;

  final List<_IntroData> _slides = const [
    _IntroData(
      image: 'assets/public_final.png',
      text:
          'The Cyber Security Authority Safeguards National Digital Systems and Citizens.',
    ),
    _IntroData(
      image: 'assets/business_csa.png',
      text:
          'Access Cybersecurity News, Alerts, Advisories, and Major National Events.',
    ),
    _IntroData(
      image: 'assets/children_final.png',
      text:
          'Report Cyber Incidents and Participate in CSA Programs and Campaigns',
    ),
  ];

  // ============================================================
  // PRELOAD ALL ONBOARDING IMAGES
  // ============================================================

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_imagesPrecached) {
      _imagesPrecached = true;

      precacheImage(
        const AssetImage('assets/public_final.png'),
        context,
      );

      precacheImage(
        const AssetImage('assets/business_csa.png'),
        context,
      );

      precacheImage(
        const AssetImage('assets/children_final.png'),
        context,
      );

      precacheImage(
        const AssetImage('assets/CSALOGO.png'),
        context,
      );
    }
  }

  // ============================================================
  // NEXT BUTTON NAVIGATION
  // ============================================================

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  // ============================================================
  // GET STARTED / SKIP
  //
  // Both land on ContinueLoginFlow (continue_login_flow.dart) —
  // the swipeable wrapper hosting the Continue page (Login /
  // Create Account / Continue without account) and the Login
  // page together.
  // ============================================================

  void _getStarted() async {
    await AuthStorage.setSeenOnboarding();
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ContinueLoginFlow(),
      ),
    );
  }

  void _skip() async {
    await AuthStorage.setSeenOnboarding();
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ContinueLoginFlow(),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ============================================================
  // MAIN ONBOARDING
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: PageView(
        controller: _pageController,

        // Keeps normal page snapping without the previous
        // custom blocking / jumping behaviour.
        physics: const ClampingScrollPhysics(),

        // There are ONLY FOUR pages now:
        // Intro 1
        // Intro 2
        // Intro 3
        // Welcome
        children: [
          for (int i = 0; i < _slides.length; i++)
            _buildIntroSlide(
              _slides[i],
              i,
            ),

          _buildWelcomePage(),
        ],
      ),
    );
  }

  // ============================================================
  // INTRO PAGES 1, 2 & 3
  // ============================================================

  Widget _buildIntroSlide(
    _IntroData slide,
    int index,
  ) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 28,
        ),
        child: Stack(
          children: [
            // ==================================================
            // IMAGE
            // ==================================================

            Column(
              children: [
                const Spacer(flex: 5),

                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 280,
                    maxWidth: 280,
                  ),
                  child: Image.asset(
                    slide.image,
                    fit: BoxFit.contain,
                    gaplessPlayback: true,
                  ),
                ),

                const SizedBox(height: 28),

                // Invisible copy.
                // This is only used to preserve the image layout.
                Opacity(
                  opacity: 0,
                  child: Text(
                    slide.text,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),
                ),

                const Spacer(flex: 3),

                Opacity(
                  opacity: 0,
                  child: _indicator(
                    activeIndex: index,
                  ),
                ),

                const SizedBox(height: 20),

                const SizedBox(
                  height: 52,
                ),

                const SizedBox(height: 32),
              ],
            ),

            // ==================================================
            // SKIP — top right corner
            // Only shown on the 2nd and 3rd intro slides, not
            // the first one.
            // Tapping this jumps straight to the Continue page
            // (Login / Create Account / Continue without account),
            // same destination as GET STARTED.
            // ==================================================

            if (index != 0)
              Positioned(
                top: 8,
                right: 0,
                child: TextButton(
                  onPressed: _skip,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black54,
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),

            // ==================================================
            // VISIBLE TEXT + DOTS + NEXT
            // ==================================================

            Positioned(
              left: 0,
              right: 0,

              // Increase = move text/dots/NEXT UP.
              // Decrease = move text/dots/NEXT DOWN.
              bottom: 52,

              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  // ==================================================
                  // LEFT-ALIGNED WORDING
                  // ==================================================

                  Text(
                    slide.text,

                    // IMPORTANT:
                    // INTRO WORDING IS LEFT ALIGNED.
                    textAlign: TextAlign.left,

                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Each intro page now knows its own indicator
                  // position. No setState is required.
                  _indicator(
                    activeIndex: index,
                  ),

                  const SizedBox(height: 20),

                  // ==================================================
                  // NEXT BUTTON
                  // ==================================================

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,

                        // 6px curve.
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                      ),

                      onPressed: () {
                        _goToPage(index + 1);
                      },

                      child: const Text(
                        'NEXT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PAGE 4 — WELCOME / GET STARTED
  // ============================================================

  Widget _buildWelcomePage() {
    // ==========================================================
    // MOVE ONLY:
    // CSA LOGO + WELCOME TEXT
    //
    // Increase = move DOWN.
    // Decrease = move UP.
    //
    // Example:
    // 180 = higher
    // 200 = current
    // 220 = lower
    // ==========================================================

    const double welcomePosition = 200;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 35,
        ),
        child: Stack(
          children: [
            // ==================================================
            // CSA LOGO + WELCOME TEXT
            // ==================================================

            Positioned(
              top: welcomePosition,
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Image.asset(
                      'assets/CSALOGO.png',
                      height: 150,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Center(
                    child: Text(
                      'Welcome to the CSA Mobile Application',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // DOTS + GET STARTED
            // ==================================================

            Positioned(
              left: 0,
              right: 0,

              // Increase = dots/button move UP.
              // Decrease = dots/button move DOWN.
              bottom: 53,

              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Welcome is always indicator number 4.
                  _indicator(
                    activeIndex: 3,
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // GET STARTED
                  // ==================================================

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,

                        // 6px curve.
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                      ),

                      onPressed: _getStarted,

                      child: const Text(
                        'GET STARTED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// INTRO DATA
// ============================================================

class _IntroData {
  final String image;
  final String text;

  const _IntroData({
    required this.image,
    required this.text,
  });
}

// ============================================================
// PAGE INDICATOR
// ============================================================

Widget _indicator({
  required int activeIndex,
}) {
  final clampedIndex =
      activeIndex > 3 ? 3 : activeIndex;

  return Row(
    mainAxisAlignment:
        MainAxisAlignment.center,
    children: List.generate(
      4,
      (index) {
        final isActive =
            index == clampedIndex;

        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 4,
          ),
          width: isActive ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF00334D)
                : Colors.grey.shade300,
            borderRadius:
                BorderRadius.circular(10),
          ),
        );
      },
    ),
  );
}