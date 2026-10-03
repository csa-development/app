import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter/screens/loggedin_user_pages/event_detail.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _openEvent(WidgetTester tester, Map<String, dynamic> event) async {
  FlutterSecureStorage.setMockInitialValues({});
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(400 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(home: EventDetailPage(event: event)));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

Map<String, dynamic> _event({required bool ended}) => {
      'id': 1,
      'title': 'Cyber Safety Day',
      'description': 'A day about staying safe online.',
      'location': 'Accra',
      'event_date': 'January 05, 2026',
      'has_ended': ended,
    };

void main() {
  testWidgets('an ended event shows a disabled "EVENT HAS ENDED" button and '
      'no calendar action', (tester) async {
    await _openEvent(tester, _event(ended: true));

    expect(find.text('EVENT HAS ENDED'), findsOneWidget);
    expect(find.text('REGISTER FOR EVENT'), findsNothing);
    expect(find.text('Add to Calendar'), findsNothing);
    expect(find.text('This event has ended'), findsOneWidget);

    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('EVENT HAS ENDED'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNull, reason: 'the button must not be tappable');
  });

  testWidgets('an upcoming event still offers registration and the calendar',
      (tester) async {
    await _openEvent(tester, _event(ended: false));

    expect(find.text('REGISTER FOR EVENT'), findsOneWidget);
    expect(find.text('Add to Calendar'), findsOneWidget);
    expect(find.text('EVENT HAS ENDED'), findsNothing);

    final button = tester.widget<ElevatedButton>(
      find.ancestor(
        of: find.text('REGISTER FOR EVENT'),
        matching: find.byType(ElevatedButton),
      ),
    );
    expect(button.onPressed, isNotNull);
  });
}
