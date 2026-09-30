import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/swipe_back.dart';

class CspPage extends StatelessWidget {
  const CspPage({super.key});

  static const Color primaryBlue = Color(0xFF00334D);
  static const Color tileBg = Color(0xFFF3F6F9);

  Future<void> _openPortal() async {
    final Uri url = Uri.parse(
        'https://nucleus.csa.gov.gh/portal/auth/signup?module=1002&next_step=account');
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
            'Cybersecurity Service Providers',
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
              'This licensing regime applies to existing and new CSPs. A CSP is an entity licensed under Act 1038 to provide a cybersecurity service. A cybersecurity service is a service for reward that is intended primarily for or aimed at ensuring or safeguarding the cybersecurity of a computer or computer system belonging to a person, and includes the services enumerated in the First Schedule of Act 1038.',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Under this regulatory activity, licensing will consider service providers implementing the following responsibilities:',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 16),

            _serviceTile(
              '1. Vulnerability Assessment and Penetration Testing',
              'Services that assess, test, or evaluate the cybersecurity of a computer or computer system by searching for vulnerabilities and probing through identified vulnerabilities to determine the best mitigation technique.',
            ),
            _serviceTile(
              '2. Digital Forensics Services',
              'Services that focus on the identification, acquisition, preservation, processing, analysis and reporting on data stored in electronic format or evidence to support legal proceedings.',
            ),
            _serviceTile(
              '3. Managed Cybersecurity Services',
              'Entail the provision of security services, including threat monitoring, detection, prevention, mitigation, response, and security advisory. Computer Emergency Response Teams (CERT) and Security Operation Centre (SOC) are considered Managed Security Services.',
            ),
            _serviceTile(
              '4. Cybersecurity Governance, Risk and Compliance',
              'Services which address cybersecurity governance issues, cybersecurity risk management advisory as well as compliance related management practices.',
            ),
            _serviceTile(
              '5. Cybersecurity Training',
              'This service entails training in any of the areas specified under the First Schedule of Act 1038.',
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