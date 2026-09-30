import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/shimmer.dart';
import '../../widgets/swipe_back.dart';

class AboutCsa extends StatefulWidget {
  const AboutCsa({super.key});

  static const Color primaryBlue = Color(0xFF00334D);
  static const Color tileBg = Color(0xFFF3F6F9);

  @override
  State<AboutCsa> createState() => _AboutCsaState();
}

class _AboutCsaState extends State<AboutCsa> {
  bool _isLoading = true;
  Map<String, dynamic>? _about;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    final result = await ApiService.getAboutPage();
    if (!mounted) return;

    setState(() {
      _about = result['success'] == true
          ? result['data']['about'] as Map<String, dynamic>?
          : null;
      _isLoading = false;
    });
  }

  // Falls back to the bundled copy so the page never renders blank —
  // e.g. before an admin has edited a field for the first time, or if
  // the request fails.
  String _text(String key, String fallback) {
    final value = _about?[key];
    return (value is String && value.isNotEmpty) ? value : fallback;
  }

  List<dynamic> get _coreValues =>
      (_about?['core_values'] as List<dynamic>?) ?? const [];

  static const List<IconData> _valueIcons = [
    Icons.lock_outline,
    Icons.verified_outlined,
    Icons.people_outline,
    Icons.handshake_outlined,
    Icons.balance_outlined,
    Icons.workspace_premium_outlined,
  ];

  static const List<Map<String, String>> _fallbackValues = [
    {
      'title': 'Confidentiality',
      'description':
          'We value the classification of national and personal information since it underpins our course to build a resilient cyber ecosystem.',
    },
    {
      'title': 'Reliability',
      'description':
          'We inspire confidence among Ghanaians with our dependability by encouraging reporting of cyber incidents.',
    },
    {
      'title': 'Inclusiveness',
      'description':
          'We value diverse views and perspectives exhibited by our multi-stakeholder engagements in decision making to build a robust cyber ecosystem.',
    },
    {
      'title': 'Commitment',
      'description':
          'We are committed to ensuring that the cyber ecosystem of Ghana is protected for a Safer Digital Ghana.',
    },
    {
      'title': 'Integrity',
      'description':
          'We approach our duties with seriousness and operate with high moral values in a cordial working environment. Honesty is a value we hold with high esteem.',
    },
    {
      'title': 'Professionalism',
      'description':
          'We execute our mandate with professional competence. We take pride in the mission bestowed upon us to operate in a culture of trust and integrity with one another and the citizenry.',
    },
  ];

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
            'About CSA',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: SwipeBack(
        child: _isLoading
            ? _buildSkeleton()
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(
                        'intro_paragraph_1',
                        'The Cyber Security Authority (CSA) has been established by the Cybersecurity Act, 2020 (Act 1038) to regulate cybersecurity activities in the country; to promote the development of cybersecurity in the country and to provide for related matters.',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      _text(
                        'intro_paragraph_2',
                        'The CSA started operations on 1st October, 2021; starting as the National Cyber Security Secretariat (NCSS) with the appointment of the National Cybersecurity Advisor in 2017 and later transitioned into the National Cyber Security Centre (NCSC) in 2018 as an agency under the then Ministry of Communications.',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ===== Image — same position/size, source now
                    // comes from the backend when set, falling back to
                    // the bundled asset otherwise. =====
                    ClipRRect(
                      borderRadius: BorderRadius.circular(0),
                      child: _about?['image'] != null
                          ? Image.network(
                              _about!['image'],
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Image.asset(
                                'assets/main_user_images/im1.jpg',
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              'assets/main_user_images/im1.jpg',
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                    ),

                    const SizedBox(height: 32),

                    // ===== Our Mandate =====
                    const Text(
                      'Our Mandate',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),

                    const SizedBox(height: 12),

                    Text(
                      _text(
                        'mandate_text',
                        'The Cyber Security Authority (CSA) has been established by the Cybersecurity Act, 2020 (Act 1038) to regulate cybersecurity activities in the country; to promote the development of cybersecurity in the country and to provide for related matters.',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ===== Mission =====
                    _sectionHeader(Icons.flag_outlined, 'Mission'),

                    const SizedBox(height: 12),

                    Text(
                      _text(
                        'mission_text',
                        'To build a Resilient Digital Ecosystem, Secure Digital Infrastructure, Develop National Capacity, Deter Cybercrime, and Strengthen Cybersecurity Cooperation.',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ===== Vision =====
                    _sectionHeader(Icons.visibility_outlined, 'Vision'),

                    const SizedBox(height: 12),

                    Text(
                      _text('vision_text', 'A Secure and Resilient Digital Ghana.'),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.7,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ===== Core Values =====
                    const Text(
                      'Core Values',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),

                    const SizedBox(height: 16),

                    for (var i = 0; i < 6; i++)
                      _valueRow(
                        _valueIcons[i],
                        i < _coreValues.length &&
                                (_coreValues[i]['title'] as String?)
                                        ?.isNotEmpty ==
                                    true
                            ? _coreValues[i]['title']
                            : _fallbackValues[i]['title']!,
                        i < _coreValues.length &&
                                (_coreValues[i]['description'] as String?)
                                        ?.isNotEmpty ==
                                    true
                            ? _coreValues[i]['description']
                            : _fallbackValues[i]['description']!,
                      ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Shimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SkeletonBox(height: 14, width: double.infinity),
            const SizedBox(height: 8),
            const SkeletonBox(height: 14, width: double.infinity),
            const SizedBox(height: 8),
            SkeletonBox(height: 14, width: MediaQuery.of(context).size.width * 0.6),
            const SizedBox(height: 20),
            const SkeletonBox(height: 200, width: double.infinity, radius: 0),
            const SizedBox(height: 32),
            const SkeletonBox(height: 20, width: 140),
            const SizedBox(height: 12),
            const SkeletonBox(height: 14, width: double.infinity),
            const SizedBox(height: 8),
            SkeletonBox(height: 14, width: MediaQuery.of(context).size.width * 0.7),
            const SizedBox(height: 32),
            const SkeletonBox(height: 20, width: 100),
            const SizedBox(height: 12),
            const SkeletonBox(height: 14, width: double.infinity),
            const SizedBox(height: 32),
            const SkeletonBox(height: 20, width: 100),
            const SizedBox(height: 12),
            const SkeletonBox(height: 14, width: 220),
            const SizedBox(height: 32),
            const SkeletonBox(height: 20, width: 130),
            const SizedBox(height: 16),
            for (var i = 0; i < 6; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SkeletonBox(height: 22, width: 22, radius: 11),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SkeletonBox(height: 15, width: 120),
                          const SizedBox(height: 8),
                          const SkeletonBox(height: 13, width: double.infinity),
                          const SizedBox(height: 4),
                          SkeletonBox(
                            height: 13,
                            width: MediaQuery.of(context).size.width * 0.5,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.black, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _valueRow(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color.fromARGB(255, 10, 77, 162),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
