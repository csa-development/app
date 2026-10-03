import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:my_first_flutter/screens/loggedin_user_pages/profile_pages/edit_profile.dart';
import 'package:my_first_flutter/screens/login_screen.dart';
import 'package:my_first_flutter/screens/registration_screen.dart';
import 'package:my_first_flutter/services/phone_format.dart';
import 'package:shared_preferences/shared_preferences.dart';

String typedText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText).last).controller.text;

void main() {
  group('placeholder pattern', () {
    test('Ghana (9 digits) is xx xxx xxxx', () {
      expect(phoneMaskForIso('GH'), 'xx xxx xxxx');
    });

    test('every country gets exactly as many x as digits it allows', () {
      expect(countries.length, greaterThan(200));
      for (final c in countries) {
        final mask = phoneMaskFor(c);
        expect(mask.replaceAll(' ', '').length, c.maxLength, reason: c.name);
        expect(mask, matches(RegExp(r'^x+( x+)*$')), reason: c.name);
      }
    });
  });

  testWidgets('every country stops accepting digits at its own limit',
      (tester) async {
    for (final c in countries) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IntlPhoneField(
              key: UniqueKey(),
              initialCountryCode: c.code,
              disableLengthCheck: false,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(hintText: phoneMaskFor(c)),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextFormField), '12345678901234567890');
      expect(typedText(tester).length, c.maxLength, reason: c.name);
    }
  });

  group('registration screen', () {
    Future<void> pumpRegistration(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 3000);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RegistrationScreen(
              firstNameController: TextEditingController(),
              surnameController: TextEditingController(),
              emailController: TextEditingController(),
              phoneController: TextEditingController(),
              onNext: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows the faded pattern and stops at 9 digits for Ghana',
        (tester) async {
      await pumpRegistration(tester);

      expect(find.text('xx xxx xxxx'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '244123456789012');
      expect(typedText(tester), '244123456');
    });

    testWidgets('letters and symbols cannot be typed', (tester) async {
      await pumpRegistration(tester);

      await tester.enterText(find.byType(TextFormField), '24-4abc+12');
      expect(typedText(tester), '24412');
    });

    testWidgets('the pattern and limit follow the selected country',
        (tester) async {
      await pumpRegistration(tester);

      await tester.tap(find.text('+233'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Nigeria');
      await tester.pumpAndSettle();
      // The search box also holds the text "Nigeria"; the list entry is last.
      await tester.tap(find.text('Nigeria').last);
      await tester.pumpAndSettle();

      // Nigeria accepts up to 11 digits.
      expect(find.text('xxx xxxx xxxx'), findsOneWidget);
      expect(find.text('xx xxx xxxx'), findsNothing);

      await tester.enterText(find.byType(TextFormField), '803123456789012');
      expect(typedText(tester), '80312345678');
    });
  });

  testWidgets('login screen: phone field shows the pattern and limits digits',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LoginScreen(onBack: () {}))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Phone Number'));
    await tester.pumpAndSettle();

    expect(find.text('xx xxx xxxx'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '244123456789012');
    expect(typedText(tester), '244123456');
  });

  testWidgets('edit profile: pattern shows when empty and limits digits',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'full_name': 'Test User',
      'email': 'test@example.com',
      'phone': '',
    });
    tester.view.physicalSize = const Size(1080, 3000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: EditProfilePage()));
    await tester.pumpAndSettle();

    expect(find.text('xx xxx xxxx'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '244123456789012');
    expect(typedText(tester), '244123456');
  });
}
