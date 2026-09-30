import 'package:flutter/material.dart';

class LegalSection {
  final String title;
  final String body;

  const LegalSection(this.title, this.body);
}

// Same wording as the logged-in profile's Privacy Policy page
// (screens/loggedin_user_pages/profile_pages/privacy_policy.dart).
const List<LegalSection> privacyPolicySections = [
  LegalSection(
    '1. Introduction',
    'The Cyber Security Authority ("CSA," "we," or "We") is committed to protecting your personal information. This Privacy Policy explains how we collect, use, store and protect your data when you use the CSA mobile application ("the Application"). This Privacy Policy and our Terms of Use together make up an agreement between you (the "User") and us. By accessing our Services, you accept and agree to this agreement, and to the collection, use and disclosure of your personal data as described in this Privacy Policy.\n\n'
    'We value the privacy of all persons who access our Application, our website, and all related services and tools (collectively, our "Services"). This Privacy Policy applies to information we collect in connection with our Services.\n\n'
    'Should you disagree to abide by our Terms of Use, or if you revoke your consent to the processing of your personal data, your account will no longer be able to access or interact with the Services.',
  ),
  LegalSection(
    '2. Information We Collect',
    'Generally, we collect personal information you provide directly, including:\n\n'
    '• Personal identification information, including your full name, email address, and phone number.\n'
    '• Photographs you choose to upload or capture through the Application, including as evidence when reporting an incident or when updating your profile picture.\n'
    '• Communications data, including feedback and contact messages you submit to us through the Application.\n'
    '• Aggregate Usage Data. We may compile aggregated, anonymised statistics about Application usage — such as the total number of incident reports, event registrations, or certificates processed — for internal reporting and service improvement purposes. This data is not used in a manner that would identify you personally.\n'
    '• Technical connection information, including your IP address and a device identifier used solely to deliver push notifications to your device.\n'
    '• Information you submit when reporting incidents.\n'
    '• Any other personal information that you choose to send to us.',
  ),
  LegalSection(
    '3. How We Use Your Information',
    'We use the information we collect to:\n\n'
    '• Verify User identity;\n'
    '• Enable you to access and use the Service;\n'
    '• Process incident reports;\n'
    '• Respond to your comments, and send you security alerts and advisories;\n'
    '• Deal with enquiries and complaints made by or about you relating to our Services;\n'
    '• Verify compliance with the terms and conditions governing the use of our Services;\n'
    '• Comply with and enforce applicable legal requirements, relevant industry standards, and our policies;\n'
    '• Send communications, such as providing you with information about services, features, and events, and sending updates;\n'
    '• Monitor and analyse trends, usage, and activity in connection with the Service for administrative, analytical, and service-improvement purposes, including internal reporting on incident volumes, certificate processing, and content engagement. IP addresses are also used for systems administration and troubleshooting purposes;\n'
    '• Improve our services.\n\n'
    'We do not sell User data to third parties.',
  ),
  LegalSection(
    '4. Data Storage and Security',
    'User data is stored on secure servers, with access restricted to authorised personnel. We use encryption and other appropriate security measures to protect User information from unauthorised access, loss, or misuse.',
  ),
  LegalSection(
    '5. Sharing of Information',
    'User information may be shared with relevant law enforcement agencies and government bodies when required by law or in the course of investigating a reported incident.',
  ),
  LegalSection(
    '6. Third-Party Service Providers',
    'We use trusted third-party service providers to help operate the Application, including cloud messaging and notification services, email delivery services, and SMS delivery services. These providers process limited User information (such as email address, phone number, or a device identifier) solely to deliver the relevant service on our behalf, and are contractually and/or technically restricted from using User information for any other purpose.\n\n'
    'As part of our service provision, we may rely on third-party servers and databases co-located with hosting providers resident in foreign jurisdictions, which constitutes a transfer of your personal data to computers or servers in foreign countries.\n\n'
    "These countries may have data protection laws that differ from Ghana's data protection regime, and in some cases may not provide the same level of data protection.\n\n"
    'As required under applicable law, third parties are required to use appropriate safeguards to protect personal information, and may only access the personal information necessary for performing their specific tasks.\n\n'
    'We take steps designed to ensure that data collected under this Privacy Policy is processed and protected according to the provisions of this Policy and applicable law, wherever the data is located.\n\n'
    'Where personal data is transferred to a country outside Ghana, the CSA shall put adequate measures in place to ensure the security of such personal information, in accordance with the relevant data protection laws, including the use of contractual terms to ensure protection of the data.',
  ),
  LegalSection(
    '7. Data Retention',
    "We retain User account information for as long as the User account remains active. Incident report data is retained for a period necessary to support investigation and follow-up, and as prescribed by relevant applicable legal or regulatory requirements. Where a User requests deletion of their account, such requests may be submitted to privacy@csa.gov.gh, and we will delete or anonymise the User's personal data within a reasonable period, except where retention is required by law or is necessary to complete an ongoing investigation.",
  ),
  LegalSection(
    '8. Legal Basis for Processing',
    'We process User personal data on the basis of: User consent, given at the point of registration and when submitting an incident report; the performance of our public mandate under the Cybersecurity Act, 2020 (Act 1038); and, where applicable, our legitimate interest in maintaining the security and integrity of the Application and in protecting the safety of Users and the public.',
  ),
  LegalSection(
    '9. Changes to This Privacy Policy',
    'We may update this Privacy Policy from time to time. The updated version will be indicated by an updated "Revised" date and will be effective as soon as it is accessible. If we make material changes, we may notify you either by prominently posting a notice of such changes, by directly notifying you, or as otherwise required by law. We encourage you to review this Privacy Policy periodically. Your continued use of our Services after any update constitutes your acceptance of the Policy as updated.',
  ),
  LegalSection(
    "10. Children's Privacy",
    'The Application is intended for general audiences and not for use by individuals under the age of 18. If we become aware that we have collected "personal information" (as defined by the Children\'s Act, 1998 (Act 560)) from a person under the age of 18 without legally valid parental consent, we will take reasonable steps to delete it as soon as possible. We also comply with other age restrictions and requirements under applicable Ghanaian law. Where a User reports an incident on behalf of a minor, we collect only the information reasonably necessary to process that report. We do not knowingly collect personal data directly from children for the purpose of creating an account.',
  ),
  LegalSection(
    '11. Users from Other Jurisdictions',
    "This Service is intended for use by citizens, residents, and stakeholders of Ghana in connection with the Cyber Security Authority's public mandate. If you access or use the Service from outside Ghana, you do so on your own initiative and are responsible for ensuring compliance with any applicable local laws.",
  ),
  LegalSection(
    '12. International Data Transfers',
    'Where any of our third-party service providers, including cloud messaging and notification services, email delivery services, and SMS delivery services, process User data outside Ghana, we take reasonable steps to ensure such data continues to receive an appropriate level of protection consistent with the Data Protection Act, 2012 (Act 843).',
  ),
  LegalSection(
    '13. Data Breach Notification',
    'In the event of a data breach that poses a risk to User rights and freedoms, we will notify affected Users and the Data Protection Commission without undue delay, in accordance with our obligations under the Data Protection Act, 2012 (Act 843).',
  ),
  LegalSection(
    '14. User Rights',
    'Users have the right to access, correct, request deletion of, or object to the processing of their personal data. These rights are subject to the exemptions provided for in the Data Protection Act, 2012 (Act 843). To exercise these rights, contact us at privacy@csa.gov.gh.',
  ),
  LegalSection(
    '15. Complaints',
    'If a User is not satisfied with how we have handled their personal data, the User may lodge a complaint with the Data Protection Commission, in addition to contacting the CSA.',
  ),
  LegalSection(
    '16. Contact Us',
    'If you have questions or feedback, or wish to report a violation regarding this Privacy Policy, you may contact the Cyber Security Authority at privacy@csa.gov.gh, or send a letter to 3rd Floor NCA Tower, KIA 6 Airport By-Pass Rd, Accra Digital Address GL-126-7029, Accra, Ghana.',
  ),
];

// Same wording as the logged-in profile's Terms of Use page
// (screens/loggedin_user_pages/profile_pages/termsandconditions.dart).
const List<LegalSection> termsOfUseSections = [
  LegalSection(
    '1. Acceptance of Terms',
    'By downloading and using the CSA mobile application, you agree to be bound by these Terms of Use. If you do not agree, please do not use the Application.',
  ),
  LegalSection(
    '2. Permitted Use',
    'This Application is intended for use by citizens, residents, and stakeholders of Ghana, including licensed and accredited professionals and entities engaging with the Cyber Security Authority, to access cybersecurity services, report incidents, and receive security information from the Cyber Security Authority.',
  ),
  LegalSection(
    '3. User Responsibilities',
    'You are responsible for maintaining the confidentiality of your User account credentials. You agree not to submit false or misleading incident reports. Misuse of this Application may result in legal action.',
  ),
  LegalSection(
    '4. Prohibited Conduct',
    'In addition to the responsibilities above, Users agree not to:\n\n'
    "• Attempt to gain unauthorised access to the Application, its servers, or any connected system;\n"
    "• Interfere with or disrupt the Application's operation;\n"
    '• Upload any file containing malicious code as part of an incident report or evidence submission;\n'
    '• Impersonate any person or entity; or\n'
    '• Use automated means to access, scrape, or extract data from the Application.',
  ),
  LegalSection(
    '5. Accuracy of Information',
    'The CSA makes every effort to ensure that information on this Application is accurate and up to date. However, we do not guarantee the completeness or accuracy of all content.',
  ),
  LegalSection(
    '6. Intellectual Property',
    'All content, logos, and materials on this Application are the property of the Cyber Security Authority and are protected under Ghanaian law. Unauthorised reproduction is prohibited.',
  ),
  LegalSection(
    '7. Account Suspension and Termination',
    'The CSA may suspend or terminate User access to the Application, without prior notice, where we reasonably believe a User has violated these Terms of Use, submitted fraudulent or malicious reports, or engaged in conduct that threatens the security of the Application or other Users.',
  ),
  LegalSection(
    '8. Limitation of Liability',
    "The CSA shall not be liable for any direct or indirect damages arising from your use of this Application. Use of this Application is at the User's own risk.",
  ),
  LegalSection(
    '9. Indemnification',
    'You agree to indemnify and hold harmless the CSA, its officers, and employees from any claim, loss, or damage, including reasonable legal costs, arising from User misuse of the Application or violation of these Terms of Use.',
  ),
  LegalSection(
    '10. Force Majeure',
    'The CSA shall not be liable for any failure or delay in performance resulting from causes beyond our reasonable control, including but not limited to power outages, network failures, natural disasters, or acts of government.',
  ),
  LegalSection(
    '11. Changes to These Terms',
    'The CSA reserves the right to update these Terms of Use at any time. Continued use of the Application following any changes constitutes your acceptance of the new terms.',
  ),
  LegalSection(
    '12. Dispute Resolution',
    'Any dispute arising from your use of this Application shall first be referred to the CSA for amicable resolution. Where a dispute cannot be resolved amicably, it shall be subject to the exclusive jurisdiction of the courts of Ghana.',
  ),
  LegalSection(
    '13. Severability',
    'If any provision of these Terms of Use is found to be invalid or unenforceable, the remaining provisions shall continue in full force and effect.',
  ),
  LegalSection(
    '14. Governing Law',
    'These Terms of Use are governed by the relevant laws of Ghana, including the Cybersecurity Act, 2020 (Act 1038) and the Data Protection Act, 2012 (Act 843).',
  ),
];

/// Shows the given legal document as a scrollable popup, styled to match
/// the app's own legal pages (same section headings/body style), with a
/// single "Done" button to dismiss.
Future<void> showLegalDocumentDialog(
  BuildContext context, {
  required String title,
  required List<LegalSection> sections,
}) {
  const primaryBlue = Color(0xFF00334D);

  return showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final section in sections)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              section.body,
                              style: const TextStyle(
                                fontSize: 13.5,
                                height: 1.6,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Done',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
