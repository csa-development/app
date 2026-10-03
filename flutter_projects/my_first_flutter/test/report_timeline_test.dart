import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter/screens/loggedin_user_pages/report_page/report_detail.dart';

/// True if any box on screen has a shadow/glow.
bool hasGlow(WidgetTester tester) {
  for (final box in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
    final d = box.decoration;
    if (d is BoxDecoration && (d.boxShadow?.isNotEmpty ?? false)) return true;
  }
  return false;
}

Future<void> pumpReport(
  WidgetTester tester,
  String status, {
  List<Map<String, String>> statuses = const [],
}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: ReportDetailPage(
        report: {
          'status': status,
          'ref': 'CSA-1234',
          'type': 'Phishing',
          'date': '2026-10-01',
          'description': 'A suspicious message.',
        },
        statuses: statuses,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// How many stage circles are filled with [color].
int circlesColoured(WidgetTester tester, Color color) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .where((b) {
  final d = b.decoration;
  return d is BoxDecoration && d.shape == BoxShape.circle && d.color == color;
}).length;

void main() {
  testWidgets('control: the glow check really detects a glow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Container(
          decoration: const BoxDecoration(
            boxShadow: [BoxShadow(color: Colors.orange, blurRadius: 8)],
          ),
        ),
      ),
    );
    expect(hasGlow(tester), isTrue);
  });

  for (final entry in {
    'Pending': const Color(0xFFD97706),
    'Under Review': const Color(0xFF00334D),
    'Resolved': const Color(0xFF1A7F4B),
  }.entries) {
    testWidgets('no glow on the ${entry.key} stage, colour kept',
        (tester) async {
      await pumpReport(tester, entry.key);

      expect(hasGlow(tester), isFalse);
      // The current stage is still drawn in its own colour.
      expect(circlesColoured(tester, entry.value), greaterThanOrEqualTo(1));
    });
  }

  testWidgets('no glow on any stage or colour of a custom stage list',
      (tester) async {
    const custom = [
      {'key': 'NEW', 'label': 'New', 'color': '#E11D48'},
      {'key': 'TRIAGE', 'label': 'Triage', 'color': '#7C3AED'},
      {'key': 'ACTION', 'label': 'In Action', 'color': '#0891B2'},
      {'key': 'DONE', 'label': 'Done', 'color': '#65A30D'},
    ];

    for (final stage in custom) {
      await pumpReport(tester, stage['label']!, statuses: custom);

      expect(hasGlow(tester), isFalse, reason: stage['label']);
      final hex = int.parse(stage['color']!.substring(1), radix: 16);
      expect(circlesColoured(tester, Color(0xFF000000 | hex)),
          greaterThanOrEqualTo(1),
          reason: stage['label']);
    }
  });
}
