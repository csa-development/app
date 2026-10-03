import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter/widgets/registered_pill.dart';

Future<void> pumpPill(WidgetTester tester, {required bool checkedIn}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Container(
        color: Colors.black,
        alignment: Alignment.bottomRight,
        child: RegisteredPill(checkedIn: checkedIn),
      ),
    ),
  );
}

void main() {
  for (final checkedIn in [false, true]) {
    final label = checkedIn ? 'Checked In' : 'Registered';

    testWidgets('$label: no white pill, no shadow, white text', (tester) async {
      await pumpPill(tester, checkedIn: checkedIn);

      // Nothing behind the chip: no coloured/rounded/shadowed box inside it.
      final boxes = find.descendant(
        of: find.byType(RegisteredPill),
        matching: find.byType(DecoratedBox),
      );
      expect(boxes, findsNothing);

      // The wording and icon are kept, and the text is readable on the
      // dark image (white).
      final text = tester.widget<Text>(find.text(label));
      expect(text.style?.color, Colors.white);
      expect(
        find.byIcon(checkedIn ? Icons.verified : Icons.check_circle),
        findsOneWidget,
      );
    });
  }
}
