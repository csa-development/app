// Decides whether an event or campaign is over.
//
// The server's own answer (`has_ended`, worked out from the server's clock)
// always wins. The dates are only a fallback for data that doesn't carry it —
// for example an event bookmarked before the server started sending the flag.
//
// "Ended" means the whole last day has passed, so a same-day event stays open
// until the day is over.

const List<String> _months = [
  'january', 'february', 'march', 'april', 'may', 'june',
  'july', 'august', 'september', 'october', 'november', 'december',
];

// The API formats dates like "January 05, 2026".
DateTime? _parseDisplayDate(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})$')
      .firstMatch(value.trim());
  if (match == null) return null;
  final month = _months.indexOf(match.group(1)!.toLowerCase()) + 1;
  if (month == 0) return null;
  return DateTime(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(2)!),
  );
}

bool _dayHasPassed(DateTime? lastDay) {
  if (lastDay == null) return false;
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).isAfter(lastDay);
}

bool eventHasEnded(Map<dynamic, dynamic> event) {
  final flag = event['has_ended'];
  if (flag is bool) return flag;
  return _dayHasPassed(
    _parseDisplayDate(event['end_date']) ??
        _parseDisplayDate(event['event_date'] ?? event['start_date']),
  );
}

bool campaignHasEnded(Map<dynamic, dynamic> campaign) {
  final flag = campaign['has_ended'];
  if (flag is bool) return flag;
  // With no end date a campaign counts as a one-day campaign.
  return _dayHasPassed(
    _parseDisplayDate(campaign['end_date']) ??
        _parseDisplayDate(campaign['start_date']),
  );
}
