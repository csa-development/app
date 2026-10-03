import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter/screens/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // The splash checks login on start; give it empty storage to read.
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'has_seen_onboarding': true});
  });

  testWidgets(
    'splash does not shift when the logo finishes loading',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3.0; // 360 x 800 logical
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

      final tagline = find.text("Securing Ghana's Digital Space");
      final spinner = find.byType(CircularProgressIndicator);
      final brand = find.text('CYBER SECURITY AUTHORITY');
      final logoBlock = find.ancestor(
        of: brand,
        matching: find.byType(Visibility),
      );

      Visibility logo() => tester.widget<Visibility>(logoBlock);

      // Right after launch: logo not decoded yet, so not shown...
      expect(logo().visible, isFalse);
      final taglineBefore = tester.getTopLeft(tagline).dy;
      final spinnerBefore = tester.getTopLeft(spinner).dy;

      // ...then it decodes (real async, not fake-async) and appears.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 800)),
      );
      await tester.pump();

      expect(logo().visible, isTrue);
      final taglineAfter = tester.getTopLeft(tagline).dy;
      final spinnerAfter = tester.getTopLeft(spinner).dy;

      // ignore: avoid_print
      print('SPLASH tagline y: $taglineBefore -> $taglineAfter');
      // ignore: avoid_print
      print('SPLASH spinner y: $spinnerBefore -> $spinnerAfter');

      expect(taglineAfter, closeTo(taglineBefore, 0.01));
      expect(spinnerAfter, closeTo(spinnerBefore, 0.01));

      // Tear down so the splash's 3s navigation timer finds it unmounted.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    },
  );
}
