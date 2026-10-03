import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter/screens/main_user_screens/license_accreditation/faq.dart';

Future<void> _openFaqs(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400 * 3, 900 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MaterialApp(home: faqli()));
}

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
}

const _cspOverview = 'How much does a CSP licence cost?';
const _ceOverview = 'How much does CE accreditation cost?';
const _cpOverview = 'How much does CP accreditation cost?';

void main() {
  testWidgets('the pricing card is the first card in every section',
      (tester) async {
    await _openFaqs(tester);

    double top(String text) => tester.getTopLeft(find.text(text)).dy;

    expect(top(_cspOverview),
        lessThan(top('Who is a Cybersecurity Service Provider (CSP)?')));
    expect(top(_ceOverview),
        lessThan(top('What is a Cybersecurity Establishment (CE)?')));
    expect(top(_cpOverview),
        lessThan(top('Who is a Cybersecurity Professional (CP)?')));
  });

  testWidgets('every fee you gave is on a card, with the right amount',
      (tester) async {
    await _openFaqs(tester);

    Future<void> open(String question) async {
      // The Professionals section is below the visible screen.
      await tester.ensureVisible(find.text(question));
      await tester.pumpAndSettle();
      await tester.tap(find.text(question));
      await tester.pump();
    }

    await open(_cpOverview);
    for (final line in [
      'Tier 1: GHS 5,000 per year',
      'Tier 2: GHS 3,000 per year',
      'Tier 3: GHS 2,000 per year',
      'Generals: GHS 500 per year',
    ]) {
      expect(find.textContaining(line), findsOneWidget, reason: line);
    }

    await open(_cspOverview);
    for (final line in [
      'Tier 1: GHS 20,000 per year',
      'Tier 2: GHS 15,000 per year',
      'Tier 3: GHS 10,000 per year',
    ]) {
      expect(find.textContaining(line), findsOneWidget, reason: line);
    }

    await open(_ceOverview);
    expect(find.textContaining('is GHS 5,000 per year.'), findsOneWidget);
  });

  testWidgets('there is a separate card for each tier', (tester) async {
    await _openFaqs(tester);
    for (final question in [
      'What is the licence fee for a Tier 1 Service Provider?',
      'What is the licence fee for a Tier 2 Service Provider?',
      'What is the licence fee for a Tier 3 Service Provider?',
      'What is the accreditation fee for a Tier 1 Professional?',
      'What is the accreditation fee for a Tier 2 Professional?',
      'What is the accreditation fee for a Tier 3 Professional?',
      'What is the accreditation fee for a General Professional?',
    ]) {
      expect(find.text(question), findsOneWidget, reason: question);
    }
  });

  group('searching for prices', () {
    for (final word in ['fee', 'fees', 'cost', 'price', 'pricing', 'how much',
        'pay', 'payment', 'charge', 'cedis', 'ghs', 'amount', 'per year']) {
      testWidgets('"$word" finds the pricing cards in all three sections',
          (tester) async {
        await _openFaqs(tester);
        await _search(tester, word);
        expect(find.text(_cspOverview), findsOneWidget);
        expect(find.text(_ceOverview), findsOneWidget);
        expect(find.text(_cpOverview), findsOneWidget);
        // ...and not the unrelated ones.
        expect(find.text('Who is a Cybersecurity Professional (CP)?'),
            findsNothing);
      });
    }

    testWidgets('"5000" and "5,000" both find the GHS 5,000 cards',
        (tester) async {
      for (final typed in ['5000', '5,000']) {
        await _openFaqs(tester);
        await _search(tester, typed);
        expect(find.text(_ceOverview), findsOneWidget, reason: typed);
        expect(find.text('What is the accreditation fee for a Tier 1 Professional?'),
            findsOneWidget, reason: typed);
      }
    });

    testWidgets('words in any order work: "tier 2 professional"',
        (tester) async {
      await _openFaqs(tester);
      await _search(tester, 'tier 2 professional');
      expect(find.text('What is the accreditation fee for a Tier 2 Professional?'),
          findsOneWidget);
      expect(find.text('What is the accreditation fee for a Tier 1 Professional?'),
          findsNothing);
    });

    testWidgets('a natural question works: "what is the fee for service providers"',
        (tester) async {
      await _openFaqs(tester);
      await _search(tester, 'what is the fee for service providers');
      expect(find.text(_cspOverview), findsOneWidget);
    });

    testWidgets('"generals" finds the Generals fee', (tester) async {
      await _openFaqs(tester);
      await _search(tester, 'generals');
      expect(find.text('What is the accreditation fee for a General Professional?'),
          findsOneWidget);
    });
  });

  testWidgets('the old searches still work and unrelated words find nothing',
      (tester) async {
    await _openFaqs(tester);

    await _search(tester, 'revoked');
    expect(find.text('Can a CSP licence be revoked?'), findsOneWidget);
    expect(find.text(_cspOverview), findsNothing);

    await _search(tester, 'zzzqqq');
    expect(find.textContaining('No FAQs found'), findsOneWidget);
  });
}
