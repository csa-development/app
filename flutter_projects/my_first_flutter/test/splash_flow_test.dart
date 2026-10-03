import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter/screens/continue_login_flow.dart';
import 'package:my_first_flutter/screens/introduction_screens.dart';
import 'package:my_first_flutter/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Records every status-bar style the app sends to the platform.
List<Map<Object?, Object?>> recordStatusBarStyles(WidgetTester tester) {
  final styles = <Map<Object?, Object?>>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'SystemChrome.setSystemUIOverlayStyle') {
        styles.add(Map<Object?, Object?>.from(call.arguments as Map));
      }
      return null;
    },
  );
  addTearDown(() => tester.binding.defaultBinaryMessenger
      .setMockMethodCallHandler(SystemChannels.platform, null));
  return styles;
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
  });

  testWidgets('leaves after ~1.2s, not the old fixed 3 seconds', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    // Still showing just before the minimum time is up...
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byType(SplashScreen), findsOneWidget);
    expect(find.byType(ContinueLoginFlow), findsNothing);

    // ...and gone shortly after it, well under the old 3 seconds.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ContinueLoginFlow), findsOneWidget);
  });

  testWidgets('first launch ever goes to the intro screens', (tester) async {
    SharedPreferences.setMockInitialValues({}); // onboarding not seen yet

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(OnboardingFlow), findsOneWidget);
    expect(find.byType(ContinueLoginFlow), findsNothing);
  });

  testWidgets('status bar icons: light on the navy splash, dark again on leaving',
      (tester) async {
    final styles = recordStatusBarStyles(tester);

    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    // On the navy splash: light icons (Android) on a dark background (iOS).
    expect(styles, isNotEmpty);
    expect(styles.first['statusBarIconBrightness'], 'Brightness.light');
    expect(styles.first['statusBarBrightness'], 'Brightness.dark');

    // Once it has moved on, the normal dark icons are back, so the next light
    // screen doesn't inherit invisible white icons.
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ContinueLoginFlow), findsOneWidget);
    expect(styles.last['statusBarIconBrightness'], 'Brightness.dark');
    expect(styles.last['statusBarBrightness'], 'Brightness.light');
  });
}
