import 'package:flutter_test/flutter_test.dart';
import 'package:my_first_flutter/utils/event_status.dart';

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

// Dates the way the API sends them: "January 05, 2026".
String _daysFromToday(int days) {
  final d = DateTime.now().add(Duration(days: days));
  return '${_months[d.month - 1]} ${d.day.toString().padLeft(2, '0')}, ${d.year}';
}

void main() {
  group('events', () {
    test('the server\'s answer wins over the dates', () {
      expect(
        eventHasEnded({'has_ended': true, 'event_date': _daysFromToday(30)}),
        isTrue,
      );
      expect(
        eventHasEnded({'has_ended': false, 'event_date': _daysFromToday(-30)}),
        isFalse,
      );
    });

    test('yesterday has ended, today and tomorrow have not', () {
      expect(eventHasEnded({'event_date': _daysFromToday(-1)}), isTrue);
      expect(eventHasEnded({'event_date': _daysFromToday(0)}), isFalse);
      expect(eventHasEnded({'event_date': _daysFromToday(1)}), isFalse);
    });

    test('a multi-day event runs until its end date, not its start date', () {
      expect(
        eventHasEnded({
          'event_date': _daysFromToday(-3),
          'end_date': _daysFromToday(2),
        }),
        isFalse,
      );
      expect(
        eventHasEnded({
          'event_date': _daysFromToday(-5),
          'end_date': _daysFromToday(-1),
        }),
        isTrue,
      );
    });

    test('missing or unreadable dates are treated as not ended', () {
      expect(eventHasEnded({}), isFalse);
      expect(eventHasEnded({'event_date': 'not a date'}), isFalse);
    });
  });

  group('campaigns', () {
    test('uses the end date when there is one', () {
      expect(
        campaignHasEnded({
          'start_date': _daysFromToday(-10),
          'end_date': _daysFromToday(3),
        }),
        isFalse,
      );
      expect(
        campaignHasEnded({
          'start_date': _daysFromToday(-10),
          'end_date': _daysFromToday(-2),
        }),
        isTrue,
      );
    });

    test('with no end date it counts as a one-day campaign', () {
      expect(campaignHasEnded({'start_date': _daysFromToday(-1)}), isTrue);
      expect(campaignHasEnded({'start_date': _daysFromToday(0)}), isFalse);
    });

    test('the server\'s answer wins', () {
      expect(campaignHasEnded({'has_ended': true}), isTrue);
      expect(
        campaignHasEnded({
          'has_ended': false,
          'start_date': _daysFromToday(-30),
        }),
        isFalse,
      );
    });
  });
}
