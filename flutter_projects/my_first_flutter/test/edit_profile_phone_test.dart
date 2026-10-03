import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:my_first_flutter/screens/loggedin_user_pages/profile_pages/edit_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpEditProfile(WidgetTester tester, String storedPhone) async {
  SharedPreferences.setMockInitialValues({
    'full_name': 'Test User',
    'email': 'test@example.com',
    'phone': storedPhone,
  });
  // Tall enough that the Save button is on screen.
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MaterialApp(home: EditProfilePage()));
  await tester.pumpAndSettle();
}

void main() {
  group('Edit Profile phone field', () {
    testWidgets('uses the flag phone field, pre-filled from a +233 number',
        (tester) async {
      await pumpEditProfile(tester, '+233244123456');

      expect(find.byType(IntlPhoneField), findsOneWidget);
      expect(find.text('🇬🇭'), findsOneWidget);
      expect(find.text('+233'), findsOneWidget);
      expect(find.text('244123456'), findsOneWidget);
    });

    testWidgets('an older local-format number still shows as Ghana',
        (tester) async {
      await pumpEditProfile(tester, '0244123456');

      expect(find.text('🇬🇭'), findsOneWidget);
      expect(find.text('+233'), findsOneWidget);
      expect(find.text('244123456'), findsOneWidget);
    });

    testWidgets('a number from another country keeps its own flag',
        (tester) async {
      await pumpEditProfile(tester, '+2348012345678');

      expect(find.text('🇳🇬'), findsOneWidget);
      expect(find.text('+234'), findsOneWidget);
      expect(find.text('8012345678'), findsOneWidget);
    });

    testWidgets('no saved number shows an empty Ghana field', (tester) async {
      await pumpEditProfile(tester, '');

      expect(find.text('🇬🇭'), findsOneWidget);
      expect(find.text('+233'), findsOneWidget);
    });

    testWidgets('a half-typed new number is rejected before anything is sent',
        (tester) async {
      await pumpEditProfile(tester, '+233244123456');

      await tester.enterText(find.byType(TextFormField), '24');
      await tester.pump();
      await tester.tap(find.text('SAVE CHANGES'));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Enter a valid phone number'), findsOneWidget);

      // Let the toast's own timer finish so the test ends cleanly.
      await tester.pump(const Duration(seconds: 10));
    });
  });
}
