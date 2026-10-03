import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/swipe_back.dart';

class ApplyLicensePage extends StatelessWidget {
  const ApplyLicensePage({super.key});

  static const Color primaryBlue = Color(0xFF00334D);

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
            'Apply for License',
            style: TextStyle(
              fontSize: 18,
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
              'To apply for a license or accreditation under the Cyber Security Authority, select the category that applies to you. All applications are processed through the CSA Nucleus Portal.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 28),

            // ===== Who Can Apply =====
            const Text(
              'Select Your Category',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 16),

            // ===== Service Provider =====
            _categoryCard(
              context,
              title: 'Cybersecurity Service Provider',
              subtitle: 'CSP',
              description:
                  'Entities providing cybersecurity services such as penetration testing, digital forensics, managed security services, governance and compliance, and cybersecurity training.',
              requirements: [
                'Certificate of Incorporation',
                'Tax Identification Number (TIN)',
                'Proof of cybersecurity services offered',
                'Staff qualifications and certifications',
              ],
              onTap: _openPortal,
            ),

            const SizedBox(height: 12),

            // ===== Professional =====
            _categoryCard(
              context,
              title: 'Cybersecurity Professional',
              subtitle: 'CP',
              description:
                  'Individuals with requisite qualifications and experience in cybersecurity services who wish to be formally accredited under Act 1038.',
              requirements: [
                'Ghana Card or Passport',
                'Curriculum Vitae (CV)',
                'Certificate in Cybersecurity',
                'Recommendation from employer',
              ],
              onTap: _openPortal,
            ),

            const SizedBox(height: 12),

            // ===== Establishment =====
            _categoryCard(
              context,
              title: 'Cybersecurity Establishment',
              subtitle: 'CE',
              description:
                  'Digital forensic laboratories and managed cybersecurity service facilities established to investigate cybercrimes and mitigate cybersecurity incidents.',
              requirements: [
                'Certificate of Incorporation',
                'Facility details and equipment list',
                'Staff qualifications',
                'Operational procedures',
              ],
              onTap: _openPortal,
            ),

            const SizedBox(height: 28),

            // ===== Note =====
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E6EB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline, size: 18, color: Colors.red),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tapping any of the buttons above will take you to the official CSA Nucleus Portal where you can create an account or log in to complete your application.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),


            const SizedBox(height: 32),
          ],
        ),
      ),
      ),
    );
  }

  Widget _categoryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String description,
    required List<String> requirements,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E6EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ===== Header =====
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryBlue.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE4E6EB)),

          // ===== Description =====
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Requirements:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 8),

                ...requirements.map(
                  (req) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: Colors.black38,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            req,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ===== Apply Button =====
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: onTap,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text(
                      'APPLY NOW',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.open_in_new, color: Colors.white, size: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
