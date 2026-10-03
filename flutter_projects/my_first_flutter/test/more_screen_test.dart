import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter/screens/loggedin_user_pages/more.dart';

void main() {
  testWidgets('every More item is its own separate card', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0; // 360 x 800 logical
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: LoggedInMore()));

    const titles = [
      'Licensing & Accreditation',
      'Events & Campaigns',
      'About CSA',
      'Cybersecurity Act, 2020 (Act 1038)',
      'Contact CSA',
    ];

    Finder cardFor(String title) => find.ancestor(
          of: find.text(title),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == LoggedInMore.tileBg,
          ),
        );

    // Each title has exactly one card of its own...
    for (final t in titles) {
      expect(cardFor(t), findsOneWidget, reason: t);
    }
    final cards = [for (final t in titles) tester.getRect(cardFor(t))];

    // ...so no two items share a card, and no divider joins them.
    expect(find.byType(Divider), findsNothing);
    for (var i = 0; i < cards.length; i++) {
      for (var j = i + 1; j < cards.length; j++) {
        expect(cards[i].overlaps(cards[j]), isFalse,
            reason: '${titles[i]} / ${titles[j]}');
      }
    }

    // Cards in the same group are exactly 12px apart.
    expect(cards[1].top - cards[0].bottom, 12); // CSA Services
    expect(cards[3].top - cards[2].bottom, 12); // Information

    // Groups stay further apart than items within a group.
    expect(cards[2].top - cards[1].bottom, greaterThan(12));
    expect(cards[4].top - cards[3].bottom, greaterThan(12));

    // All cards are the same full width.
    for (final c in cards) {
      expect(c.width, cards.first.width);
    }
  });
}
