import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // The splash is shown only as long as the app needs to start, with this
  // as a floor so it never just flashes. It used to wait a fixed 3 seconds
  // every time, even when the login check had finished long before.
  static const Duration _minDisplay = Duration(milliseconds: 1200);

  // The splash is navy, so the clock/battery icons must be light on it. They
  // are set explicitly (not with an AnnotatedRegion) because Flutter keeps the
  // last style when a screen doesn't set its own: left alone, light icons
  // would stay on the next, light screen and become invisible. So the normal
  // dark icons are restored right before leaving.
  static const SystemUiOverlayStyle _splashStatusBar = SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.light, // Android
    statusBarBrightness: Brightness.dark, // iOS
  );
  static const SystemUiOverlayStyle _appStatusBar = SystemUiOverlayStyle(
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(_splashStatusBar);
    _checkLoginAndNavigate();
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(_appStatusBar);
    super.dispose();
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
    // The login check runs while the minimum time elapses, so the splash
    // lasts as long as the slower of the two, not their sum.
    final results = await Future.wait<Widget?>([
      _chooseDestination(),
      Future<Widget?>.delayed(_minDisplay),
    ]);

    if (!mounted) return;

    // Back to the normal dark status bar icons before the next screen
    // slides in.
    SystemChrome.setSystemUIOverlayStyle(_appStatusBar);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => results.first!),
    );
  }

  Future<Widget> _chooseDestination() async {
    if (await AuthStorage.isLoggedIn()) return const LoggedInDashboard();

    // Onboarding only ever shows once, on the very first launch —
    // every launch after that (logged in or not) skips straight past
    // it, even across full app restarts.
    if (await AuthStorage.hasSeenOnboarding()) {
      return const ContinueLoginFlow();
    }
    return const OnboardingFlow();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00334D),
      body: Column(
        children: [
          const Spacer(flex: 3),
          Center(
            // Always laid out, only painted once the logo has decoded. It
            // used to be swapped in from a zero-height box, which made the
            // spacers re-split and shoved the tagline and spinner down
            // ~28px the moment it appeared.
            child: Visibility(
              visible: _logoReady,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Column(
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
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: TextScaler.noScaling),
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
              ),
            ),
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
