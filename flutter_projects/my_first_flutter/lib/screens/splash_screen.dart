import 'dart:async';

import 'package:flutter/material.dart';

import '../services/auth_storage.dart';
import 'continue_login_flow.dart';
import 'introduction_screens.dart';
import 'loggedin_user_pages/dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const String _logoAsset = 'assets/main_csa_logo_final.png';

  // Image.asset decodes asynchronously, so on a cold image cache
  // (always true right after a hot restart) the text was painting a
  // frame or two before the logo was ready to draw. Precaching and
  // holding the logo+text together until it resolves means they
  // always appear in the same frame.
  bool _logoReady = false;
  bool _precacheStarted = false;

  @override
  void initState() {
    super.initState();
    _checkLoginAndNavigate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precacheStarted) {
      _precacheStarted = true;
      precacheImage(const AssetImage(_logoAsset), context).then((_) {
        if (mounted) setState(() => _logoReady = true);
      });
    }
  }

  Future<void> _checkLoginAndNavigate() async {
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final isLoggedIn = await AuthStorage.isLoggedIn();

    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoggedInDashboard()),
      );
      return;
    }

    // Onboarding only ever shows once, on the very first launch —
    // every launch after that (logged in or not) skips straight past
    // it, even across full app restarts.
    final hasSeenOnboarding = await AuthStorage.hasSeenOnboarding();

    if (!mounted) return;

    if (hasSeenOnboarding) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ContinueLoginFlow()),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingFlow()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00334D),
      body: Column(
        children: [
          const Spacer(flex: 3),
          Center(
            child: _logoReady
                ? Column(
                    children: [
                      Image.asset(_logoAsset, height: 110),
                      const SizedBox(height: 20),
                      // Side padding + FittedBox: on a narrow phone (or one with
                      // a large system font) the title shrinks to fit on one
                      // line instead of touching the screen edges. On wider
                      // phones it stays at the full 17px. noScaling ignores the
                      // phone's font-size setting so this branding line is
                      // always the same size.
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            textScaler: TextScaler.noScaling,
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'CYBER SECURITY AUTHORITY',
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'REPUBLIC OF GHANA',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const Spacer(flex: 2),
          const Text(
            'Securing Ghana\'s Digital Space',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
