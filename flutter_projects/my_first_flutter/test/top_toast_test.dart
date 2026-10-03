import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter/widgets/top_toast.dart';

Future<void> _pumpAppWithToast(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => showTopToast(context, 'Hello banner'),
              child: const Text('show'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('show'));
  await tester.pump(); // insert the overlay
  await tester.pump(const Duration(milliseconds: 300)); // slide-in finished
}

void main() {
  testWidgets('leaves on its own after the usual time when not touched',
      (tester) async {
    await _pumpAppWithToast(tester);
    expect(find.text('Hello banner'), findsOneWidget);

    // Still there shortly before the 2.5s mark...
    await tester.pump(const Duration(milliseconds: 2000));
    expect(find.text('Hello banner'), findsOneWidget);

    // ...and gone once the time is up and it has slid away.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Hello banner'), findsNothing);
  });

  testWidgets('swiping up dismisses it straight away', (tester) async {
    await _pumpAppWithToast(tester);
    expect(find.text('Hello banner'), findsOneWidget);

    await tester.drag(find.text('Hello banner'), const Offset(0, -80));
    // Only the slide-away animation runs - far less than the 2.5s timer.
    await tester.pumpAndSettle();

    expect(find.text('Hello banner'), findsNothing);
  });

  testWidgets('a tiny nudge does not dismiss it, and it still leaves later',
      (tester) async {
    await _pumpAppWithToast(tester);

    await tester.drag(find.text('Hello banner'), const Offset(0, -5));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hello banner'), findsOneWidget);

    // Then it carries on and leaves by itself.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Hello banner'), findsNothing);
  });

  testWidgets('pulling it downward does nothing', (tester) async {
    await _pumpAppWithToast(tester);

    await tester.drag(find.text('Hello banner'), const Offset(0, 80));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Hello banner'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Hello banner'), findsNothing);
  });
}
