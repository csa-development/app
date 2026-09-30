import 'package:flutter/material.dart';

import '../../../widgets/swipe_back.dart';

class TermsOfUsePage extends StatelessWidget {
  const TermsOfUsePage({super.key});

  static const Color primaryBlue = Color(0xFF00334D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Terms of Use',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SwipeBack(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _section(
              '1. Acceptance of Terms',
              'By downloading and using the CSA mobile application, you agree to be bound by these Terms of Use. If you do not agree, please do not use the Application.',
            ),

            _section(
              '2. Permitted Use',
              'This Application is intended for use by citizens, residents, and stakeholders of Ghana, including licensed and accredited professionals and entities engaging with the Cyber Security Authority, to access cybersecurity services, report incidents, and receive security information from the Cyber Security Authority.',
            ),

            _section(
              '3. User Responsibilities',
              'You are responsible for maintaining the confidentiality of your User account credentials. You agree not to submit false or misleading incident reports. Misuse of this Application may result in legal action.',
            ),

            _section(
              '4. Prohibited Conduct',
              'In addition to the responsibilities above, Users agree not to:\n\n'
              "• Attempt to gain unauthorised access to the Application, its servers, or any connected system;\n"
              "• Interfere with or disrupt the Application's operation;\n"
              '• Upload any file containing malicious code as part of an incident report or evidence submission;\n'
              '• Impersonate any person or entity; or\n'
              '• Use automated means to access, scrape, or extract data from the Application.',
            ),

            _section(
              '5. Accuracy of Information',
              'The CSA makes every effort to ensure that information on this Application is accurate and up to date. However, we do not guarantee the completeness or accuracy of all content.',
            ),

            _section(
              '6. Intellectual Property',
              'All content, logos, and materials on this Application are the property of the Cyber Security Authority and are protected under Ghanaian law. Unauthorised reproduction is prohibited.',
            ),

            _section(
              '7. Account Suspension and Termination',
              'The CSA may suspend or terminate User access to the Application, without prior notice, where we reasonably believe a User has violated these Terms of Use, submitted fraudulent or malicious reports, or engaged in conduct that threatens the security of the Application or other Users.',
            ),

            _section(
              '8. Limitation of Liability',
              "The CSA shall not be liable for any direct or indirect damages arising from your use of this Application. Use of this Application is at the User's own risk.",
            ),

            _section(
              '9. Indemnification',
              'You agree to indemnify and hold harmless the CSA, its officers, and employees from any claim, loss, or damage, including reasonable legal costs, arising from User misuse of the Application or violation of these Terms of Use.',
            ),

            _section(
              '10. Force Majeure',
              'The CSA shall not be liable for any failure or delay in performance resulting from causes beyond our reasonable control, including but not limited to power outages, network failures, natural disasters, or acts of government.',
            ),

            _section(
              '11. Changes to These Terms',
              'The CSA reserves the right to update these Terms of Use at any time. Continued use of the Application following any changes constitutes your acceptance of the new terms.',
            ),

            _section(
              '12. Dispute Resolution',
              'Any dispute arising from your use of this Application shall first be referred to the CSA for amicable resolution. Where a dispute cannot be resolved amicably, it shall be subject to the exclusive jurisdiction of the courts of Ghana.',
            ),

            _section(
              '13. Severability',
              'If any provision of these Terms of Use is found to be invalid or unenforceable, the remaining provisions shall continue in full force and effect.',
            ),

            _section(
              '14. Governing Law',
              'These Terms of Use are governed by the relevant laws of Ghana, including the Cybersecurity Act, 2020 (Act 1038) and the Data Protection Act, 2012 (Act 843).',
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              height: 1.7,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}
