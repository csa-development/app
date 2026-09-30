import 'package:flutter/material.dart';

import '../../widgets/swipe_back.dart';
import 'license_accreditation/apply.dart';
import 'license_accreditation/faq.dart';
import 'license_accreditation/overview.dart';
import 'license_accreditation/verify.dart';

// ============================================================
// OPTION 2 — Numbered circle
// A filled navy circle with the step number (1, 2, 3, 4)
// instead of an icon — reads as a sequence.
// ============================================================

class LicenseAccreditationScreen extends StatelessWidget {
  const LicenseAccreditationScreen({super.key});

  static const Color primaryBlue = Color(0xFF00334D);
  static const Color cardColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: const Text(
            'Licensing and Accreditation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: SwipeBack(
        child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            const Text(
              'Licensing and accreditation of cybersecurity service providers, establishments, and professionals.',
              style: TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),
            _menuTile(
              context,
              number: 1,
              title: 'Overview',
              destination: const overviewli(),
            ),
            _menuTile(
              context,
              number: 2,
              title: 'Apply for License & Accreditation',
              destination: const ApplyLicensePage(),
            ),
            _menuTile(
              context,
              number: 3,
              title: 'Verify Certificate',
              destination: const Verifyli(),
            ),
            _menuTile(
              context,
              number: 4,
              title: 'Frequently Asked Questions',
              destination: const faqli(),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _menuTile(
    BuildContext context, {
    required int number,
    required String title,
    required Widget destination,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => destination),
            );
          },
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7EAF0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF20202F),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black38,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}