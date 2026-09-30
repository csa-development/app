import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/notification_service.dart';
import 'widgets/inactivity_watcher.dart';

// Shared route observer — lets any screen (e.g. LoggedInHome) find out
// when it's been returned to after a pushed screen (e.g. EventDetailPage)
// is popped, via the RouteAware mixin.
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

// Lets code outside the widget tree (InactivityWatcher, sitting above
// the Navigator via MaterialApp.builder) trigger navigation — e.g.
// dropping a dormant user back on the Continue page.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Runs in its own isolate (app backgrounded or fully killed), so it
  // can't rely on anything NotificationService.initialize() already
  // set up in the main isolate — showCsaNotification() re-initializes
  // what it needs itself. The backend sends `data`-only payloads
  // specifically so Android never auto-builds this notification on
  // its own (generic icon, no large icon) before this code runs.
  await NotificationService.showCsaNotification(message);
}

// The API is served over HTTPS with a certificate signed by CSA's own
// internal CA (not a public one), so the app is told to trust that CA.
// Adding it to the default SecurityContext covers every dart:io HttpClient
// - the `http` package and Image.network alike. Only the CA's PUBLIC
// certificate lives in the app; its private key never leaves the server PC.
Future<void> _trustCsaCertificateAuthority() async {
  try {
    final data = await rootBundle.load('assets/certs/csa_ca.pem');
    SecurityContext.defaultContext
        .setTrustedCertificatesBytes(data.buffer.asUint8List());
  } catch (e) {
    debugPrint('Could not load the CSA certificate authority: $e');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _trustCsaCertificateAuthority();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await NotificationService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      navigatorObservers: [routeObserver],
      builder: (context, child) =>
          InactivityWatcher(child: child ?? const SizedBox.shrink()),
      theme: ThemeData(
        // App-wide font, replacing the old bundled SourceSansPro/
        // BankGothic pair — GoogleFonts.poppinsTextTheme() sets every
        // TextTheme slot (bodyLarge, titleMedium, etc.) to Poppins in
        // one call, so individual overrides below only need to cover
        // the widget-theme spots (AppBar title, button text, hint
        // text) that don't read from TextTheme automatically.
        fontFamily: GoogleFonts.poppins().fontFamily,
        scaffoldBackgroundColor: const Color(0xFFF8F9FB),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF8F9FB),
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.black),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w700),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          hintStyle: GoogleFonts.poppins(),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}