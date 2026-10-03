import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

// Poppins ships inside the app (assets/google_fonts) and main.dart turns
// off runtime fetching, so any weight that isn't bundled would silently
// fall back to the phone's default font. These tests fail if that happens.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('every Poppins style the app builds loads from the bundled files',
      () async {
    // Exactly what main.dart's ThemeData asks for.
    GoogleFonts.poppins();
    GoogleFonts.poppinsTextTheme();
    GoogleFonts.poppins(fontWeight: FontWeight.w700);

    // Every weight used by a screen anywhere in lib/, plus the italic
    // used on the splash screen.
    for (final weight in [
      FontWeight.w400,
      FontWeight.w500,
      FontWeight.w600,
      FontWeight.w700,
      FontWeight.w800,
      FontWeight.w900,
    ]) {
      GoogleFonts.poppins(fontWeight: weight);
    }
    GoogleFonts.poppins(fontStyle: FontStyle.italic);

    await GoogleFonts.pendingFonts();
  });

  test('control: a weight that is NOT bundled is detected', () async {
    GoogleFonts.poppins(fontWeight: FontWeight.w300);

    await expectLater(GoogleFonts.pendingFonts(), throwsA(isA<Exception>()));
  });
}
