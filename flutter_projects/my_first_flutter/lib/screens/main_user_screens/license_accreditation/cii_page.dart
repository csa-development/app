import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/swipe_back.dart';

class CiiPage extends StatelessWidget {
  const CiiPage({super.key});

  static const Color primaryBlue = Color(0xFF00334D);
  static const Color tileBg = Color(0xFFF3F6F9);

  // Same portal URL used by the CII card on the Apply page — no
  // module param has been assigned for this category yet.
  Future<void> _openPortal() async {
    final Uri url = Uri.parse('https://nucleus.csa.gov.gh/portal/auth/signup');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

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
            'Critical Information Infrastructure',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: SwipeBack(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Entities designated by the Cyber Security Authority as owners of Critical Information Infrastructure (CII) under Act 1038 are required to register with the CSA and comply with prescribed cybersecurity standards.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Registration under this category requires the following:',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 16),

            _serviceTile(
              '1. Certificate of Incorporation',
              'Proof of legal registration of the entity owning or operating the designated Critical Information Infrastructure.',
            ),
            _serviceTile(
              '2. CSA Designation Notice',
              'The official notice from the Cyber Security Authority designating the entity as an owner of Critical Information Infrastructure.',
            ),
            _serviceTile(
              '3. Cybersecurity Policy and Risk Assessment',
              'Documented cybersecurity policy together with a risk assessment covering the systems and networks that make up the designated infrastructure.',
            ),
            _serviceTile(
              '4. Incident Reporting Procedures',
              'Documented procedures for detecting, escalating, and reporting cybersecurity incidents affecting the designated infrastructure to the CSA.',
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _openPortal,
                child: const Text(
                  'REGISTER / LOGIN TO APPLY',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }

  Widget _serviceTile(String title, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tileBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
