import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter/widgets/quick_action_tile.dart';

void main() {
  testWidgets('glass circle: frosted body, cool edge, no glow, black icon',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: QuickActionTile(
              icon: Icons.phone_outlined,
              label: 'Contact\nCSA',
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );

    final circles = tester
        .widgetList<Container>(find.descendant(
          of: find.byType(QuickActionTile),
          matching: find.byType(Container),
        ))
        .where((c) =>
            c.decoration is BoxDecoration &&
            (c.decoration as BoxDecoration).shape == BoxShape.circle)
        .map((c) => c.decoration as BoxDecoration)
        .toList();
    expect(circles.length, 1);
    final glass = circles.single;

    // No shadow or glow.
    expect(glass.boxShadow, isNull);

    // Frosted gradient body, not a flat fill, with a thin cool edge.
    expect(glass.color, isNull);
    expect((glass.gradient as LinearGradient).colors, QuickActionTile.bodyColors);
    final edge = glass.border as Border;
    expect(edge.top.color, QuickActionTile.edgeColor);
    expect(edge.top.width, 1);

    // No panel behind it and no blur layer: it stands on its own.
    expect(find.byType(BackdropFilter), findsNothing);

    // Thin black icon at the same size as before.
    final icon = tester.widget<Icon>(find.byIcon(Icons.phone_outlined));
    expect(icon.color, Colors.black);
    expect(icon.size, 24);

    expect(find.text('Contact\nCSA'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.phone_outlined));
    expect(taps, 1);
    await tester.tap(find.text('Contact\nCSA'));
    expect(taps, 2);
  });
}
