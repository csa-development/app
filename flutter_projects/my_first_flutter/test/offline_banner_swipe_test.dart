import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter/widgets/offline_banner.dart';

Future<ValueNotifier<bool>> _pumpApp(WidgetTester tester) async {
  final offline = ValueNotifier<bool>(false);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) =>
          OfflineBanner(offline: offline, child: child!),
      home: Scaffold(appBar: AppBar(title: const Text('Home'))),
    ),
  );
  return offline;
}

final _headline = find.textContaining("You're offline");
final _hint = find.textContaining('Check your Wi-Fi or mobile data');

void main() {
  testWidgets('shows the banner with the Wi-Fi / mobile data message',
      (tester) async {
    final offline = await _pumpApp(tester);
    offline.value = true;
    await tester.pumpAndSettle();

    expect(_headline, findsOneWidget);
    expect(_hint, findsOneWidget);
  });

  testWidgets('stays put for as long as there is no connection',
      (tester) async {
    final offline = await _pumpApp(tester);
    offline.value = true;
    await tester.pumpAndSettle();

    // A long time passes with nobody touching it...
    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();
    expect(_headline, findsOneWidget);
  });

  testWidgets('goes away by itself when the connection returns',
      (tester) async {
    final offline = await _pumpApp(tester);
    final titleTopOnline = tester.getTopLeft(find.text('Home')).dy;

    offline.value = true;
    await tester.pumpAndSettle();
    offline.value = false;
    await tester.pumpAndSettle();

    expect(_headline, findsNothing);
    expect(tester.getTopLeft(find.text('Home')).dy, titleTopOnline);
  });

  testWidgets('it floats over the screen: nothing underneath moves',
      (tester) async {
    final offline = await _pumpApp(tester);
    final titleTopOnline = tester.getTopLeft(find.text('Home')).dy;

    offline.value = true;
    await tester.pumpAndSettle();

    expect(_headline, findsOneWidget);
    expect(tester.getTopLeft(find.text('Home')).dy, titleTopOnline,
        reason: 'the screen must stay exactly where it was');
    // ...and the banner really is at the top, over the title bar.
    expect(tester.getTopLeft(_headline).dy, lessThan(kToolbarHeight));
  });

  testWidgets('swiping it up makes it vanish, and the screen never moves',
      (tester) async {
    final offline = await _pumpApp(tester);
    final titleTopOnline = tester.getTopLeft(find.text('Home')).dy;

    offline.value = true;
    await tester.pumpAndSettle();
    await tester.drag(_headline, const Offset(0, -80));
    await tester.pumpAndSettle();

    expect(_headline, findsNothing);
    expect(tester.getTopLeft(find.text('Home')).dy, titleTopOnline);
  });

  testWidgets('the screen behind the banner can still be tapped',
      (tester) async {
    var taps = 0;
    final offline = ValueNotifier<bool>(true);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            OfflineBanner(offline: offline, child: child!),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ElevatedButton(
                onPressed: () => taps++, child: const Text('below')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('below'));
    expect(taps, 1);
  });

  testWidgets('once swiped away it stays away for the rest of the outage',
      (tester) async {
    final offline = await _pumpApp(tester);
    offline.value = true;
    await tester.pumpAndSettle();
    await tester.drag(_headline, const Offset(0, -80));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    expect(_headline, findsNothing, reason: 'still offline, but dismissed');
  });

  testWidgets('it comes back if the connection drops again later',
      (tester) async {
    final offline = await _pumpApp(tester);
    offline.value = true;
    await tester.pumpAndSettle();
    await tester.drag(_headline, const Offset(0, -80));
    await tester.pumpAndSettle();
    expect(_headline, findsNothing);

    offline.value = false; // connection returns
    await tester.pumpAndSettle();
    offline.value = true; // ...and drops again
    await tester.pumpAndSettle();

    expect(_headline, findsOneWidget);
  });

  testWidgets('a tiny nudge or a downward pull does not dismiss it',
      (tester) async {
    final offline = await _pumpApp(tester);
    offline.value = true;
    await tester.pumpAndSettle();

    await tester.drag(_headline, const Offset(0, -5));
    await tester.pumpAndSettle();
    expect(_headline, findsOneWidget);

    await tester.drag(_headline, const Offset(0, 80));
    await tester.pumpAndSettle();
    expect(_headline, findsOneWidget);
  });
}
