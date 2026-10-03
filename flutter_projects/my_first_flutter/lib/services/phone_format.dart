import 'package:intl_phone_field/countries.dart';
import 'package:intl_phone_field/phone_number.dart';

/// Faded placeholder for the phone field: one 'x' per digit it accepts,
/// grouped for readability (Ghana, 9 digits: 'xx xxx xxxx'). The groups are
/// a generic pattern per length; only the number of x's is exact.
String phoneMaskForLength(int digits) {
  const groups = {
    4: [4],
    5: [5],
    6: [3, 3],
    7: [3, 4],
    8: [4, 4],
    9: [2, 3, 4],
    10: [3, 3, 4],
    11: [3, 4, 4],
    12: [4, 4, 4],
    13: [3, 3, 3, 4],
    14: [3, 4, 4, 3],
    15: [4, 4, 4, 3],
  };

  final sizes = groups[digits];
  if (sizes != null) return sizes.map((n) => 'x' * n).join(' ');

  // Not expected (no country is outside 4-15), but never leave it blank.
  final parts = <String>[];
  for (var left = digits; left > 0; left -= 4) {
    parts.add('x' * (left < 4 ? left : 4));
  }
  return parts.join(' ');
}

/// The placeholder for a country: as many x's as the longest number the
/// field lets the user type for it (for countries that accept a range, such
/// as Nigeria's 10-11, that is the upper end).
String phoneMaskFor(Country country) => phoneMaskForLength(country.maxLength);

String phoneMaskForIso(String isoCode) => phoneMaskFor(
      countries.firstWhere((c) => c.code == isoCode, orElse: () => countries.first),
    );

/// A stored phone number split into what the flag phone field needs.
class SplitPhone {
  /// Country shown by the flag, e.g. 'GH'.
  final String isoCode;

  /// The number without its country code, e.g. '244123456'.
  final String national;

  const SplitPhone(this.isoCode, this.national);
}

String _stripFormatting(String s) => s.replaceAll(RegExp(r'[\s\-().]'), '');

/// Reduces any way a number may have been stored ('+233244123456',
/// '0244123456', '00233244123456', '233 24 412 3456') to digits only,
/// country code first, so two spellings of the same number compare equal.
/// A number with no country code is taken to be a Ghana number.
String canonicalPhone(String phone) {
  var s = _stripFormatting(phone.trim());
  if (s.startsWith('00')) s = '+${s.substring(2)}';
  final digits = s.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (s.startsWith('+')) return digits;
  if (digits.startsWith('0')) return '233${digits.substring(1)}';
  if (digits.startsWith('233') && digits.length >= 12) return digits;
  return '233$digits';
}

/// Splits a stored number into the country and national digits for the
/// flag field. An unrecognised country code falls back to showing the
/// digits under Ghana rather than failing.
SplitPhone splitStoredPhone(String stored) {
  final canonical = canonicalPhone(stored);
  if (canonical.isEmpty) return const SplitPhone('GH', '');

  try {
    final country = PhoneNumber.getCountry('+$canonical');
    return SplitPhone(
      country.code,
      canonical.substring(country.dialCode.length + country.regionCode.length),
    );
  } catch (_) {
    return SplitPhone(
      'GH',
      canonical.startsWith('233') ? canonical.substring(3) : canonical,
    );
  }
}
