import 'package:flutter/material.dart';

import '../../../widgets/swipe_back.dart';

// Words people use when they mean "price", so a search for any of them finds
// the fee cards even when the card itself says something else (e.g. "GHS").
// Stored on the pricing FAQs under the hidden key 'k'.
const String _priceWords =
    'fee fees price prices pricing cost costs how much pay payment payable '
    'charge charges amount rate rates cedi cedis ghs ghc gh₵ annual yearly '
    'per year money';

const Set<String> _ignoredSearchWords = {
  'a', 'an', 'the', 'of', 'is', 'are', 'to', 'for', 'in', 'on', 'and', 'or',
  'what', 'does', 'do', 'my', 'me', 'i', 'it', 'be', 'can', 'there',
};

// Lowercase, and "5,000" == "5000" so either way of typing a fee finds it.
String _normalise(String text) => text.toLowerCase().replaceAll(',', '');

/// Every typed word has to appear somewhere in the question, answer or hidden
/// search words (order doesn't matter), so "tier 1 fee" or "how much" work.
@visibleForTesting
bool faqMatches(Map<String, String> faq, String query) {
  final words = _normalise(query)
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return true;

  // Don't let filler words ("what is the…") rule everything out — unless
  // that is all that was typed.
  final meaningful = words.where((w) => !_ignoredSearchWords.contains(w)).toList();
  final needed = meaningful.isEmpty ? words : meaningful;

  final haystack = _normalise('${faq['q']} ${faq['a']} ${faq['k'] ?? ''}');
  // A plural also finds the singular ("providers" finds "Provider").
  bool found(String word) =>
      haystack.contains(word) ||
      (word.length > 3 &&
          word.endsWith('s') &&
          haystack.contains(word.substring(0, word.length - 1)));
  return needed.every(found);
}

class faqli extends StatefulWidget {
  const faqli({super.key});

  @override
  State<faqli> createState() => _faqliState();
}

class _faqliState extends State<faqli> {
  static const Color primaryBlue = Color(0xFF00334D);
  static const Color tileBg = Color(0xFFF3F6F9);

  int? _expandedIndex;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matches(Map<String, String> faq) => faqMatches(faq, _searchQuery);

  @override
  Widget build(BuildContext context) {
    final cspResults = _cspFaqs.where(_matches).toList();
    final ceResults = _ceFaqs.where(_matches).toList();
    final cpResults = _cpFaqs.where(_matches).toList();
    final hasResults =
        cspResults.isNotEmpty || ceResults.isNotEmpty || cpResults.isNotEmpty;
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
            'FAQs',
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
            // ===== Search =====
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E6EB)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) =>
                    setState(() => _searchQuery = value.trim()),
                style: const TextStyle(
                    fontSize: 15, color: Colors.black87),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  hintText: 'Search FAQs',
                  hintStyle: const TextStyle(
                      color: Colors.black45, fontSize: 15),
                  prefixIcon: const Icon(Icons.search,
                      color: Colors.black45, size: 20),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              color: Colors.black45, size: 18),
                          onPressed: () => setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          }),
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 24),

            if (!hasResults)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.search_off,
                          size: 40, color: Colors.black26),
                      const SizedBox(height: 12),
                      Text(
                        'No FAQs found for "$_searchQuery"',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, color: Colors.black45),
                      ),
                    ],
                  ),
                ),
              ),

            // ===== CSP Section =====
            if (cspResults.isNotEmpty) ...[
              const Text(
                'Cybersecurity Service Providers',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...List.generate(cspResults.length, (index) {
                return _faqTile(
                  index,
                  cspResults[index]['q']!,
                  cspResults[index]['a']!,
                  0,
                );
              }),
              const SizedBox(height: 24),
            ],

            // ===== CE Section =====
            if (ceResults.isNotEmpty) ...[
              const Text(
                'Cybersecurity Establishments',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...List.generate(ceResults.length, (index) {
                return _faqTile(
                  index,
                  ceResults[index]['q']!,
                  ceResults[index]['a']!,
                  1,
                );
              }),
              const SizedBox(height: 24),
            ],

            // ===== CP Section =====
            if (cpResults.isNotEmpty) ...[
              const Text(
                'Cybersecurity Professionals',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              ...List.generate(cpResults.length, (index) {
                return _faqTile(
                  index,
                  cpResults[index]['q']!,
                  cpResults[index]['a']!,
                  2,
                );
              }),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _faqTile(
      int index, String question, String answer, int section) {
    final uniqueIndex = section * 100 + index;
    final isExpanded = _expandedIndex == uniqueIndex;

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedIndex = isExpanded ? null : uniqueIndex;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: tileBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    question,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: primaryBlue,
                ),
              ],
            ),
            if (isExpanded) ...[
              const SizedBox(height: 12),
              Text(
                answer,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Colors.black87,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const List<Map<String, String>> _cspFaqs = [
  // ===== Fees come first =====
  {
    'q': 'How much does a CSP licence cost?',
    'a':
        'The annual licence fee for a Cybersecurity Service Provider depends on its tier:\n\n'
        '• Tier 1: GHS 20,000 per year\n'
        '• Tier 2: GHS 15,000 per year\n'
        '• Tier 3: GHS 10,000 per year',
    'k': _priceWords,
  },
  {
    'q': 'What is the licence fee for a Tier 1 Service Provider?',
    'a': 'The licence fee for a Tier 1 Cybersecurity Service Provider is GHS 20,000 per year.',
    'k': _priceWords,
  },
  {
    'q': 'What is the licence fee for a Tier 2 Service Provider?',
    'a': 'The licence fee for a Tier 2 Cybersecurity Service Provider is GHS 15,000 per year.',
    'k': _priceWords,
  },
  {
    'q': 'What is the licence fee for a Tier 3 Service Provider?',
    'a': 'The licence fee for a Tier 3 Cybersecurity Service Provider is GHS 10,000 per year.',
    'k': _priceWords,
  },
  {
    'q': 'Who is a Cybersecurity Service Provider (CSP)?',
    'a':
        'A CSP is a person or entity licensed under Act 1038 to provide cybersecurity services aimed at ensuring or safeguarding the cybersecurity of a computer or computer system.',
  },
  {
    'q': 'What services are covered under the licensing regime?',
    'a':
        'Services covered include Vulnerability Assessment and Penetration Testing, Digital Forensics, Managed Cybersecurity Services, Governance Risk and Compliance, and Cybersecurity Training.',
  },
  {
    'q': 'What are the requirements to obtain a licence as a CSP?',
    'a':
        'Requirements include completing an online application, describing services offered, validating accreditation of employed professionals, submitting business registration and tax clearance, and providing cybersecurity insurance coverage.',
  },
  {
    'q': 'What is the turnaround time for a licence application?',
    'a':
        'The CSA will inform the applicant of its decision within 30 days of receiving a complete application via email or the online portal.',
  },
  {
    'q': 'Can a CSP licence be revoked?',
    'a':
        'Yes. A licence may be revoked if obtained by fraud, if the licensee ceases operations, is convicted of an offence, or no longer meets the requirements for holding the licence.',
  },
  {
    'q': 'What are the consequences of operating without a licence?',
    'a':
        'Operating without a licence is an offence under section 49 of Act 1038, punishable by a penalty equivalent to the cost of damage caused and financial gain made.',
  },
  {
    'q': 'How can a foreign CSP apply for a licence?',
    'a':
        'A foreign CSP must register with the Registrar-General of Ghana. If they cannot meet local requirements, they must partner with a licensed Ghanaian CSP before providing services.',
  },
  {
    'q': 'What is the validity period of a CSP licence?',
    'a':
        'A licence is valid for two years. Renewal must be applied for at least one month before expiry.',
  },
];

const List<Map<String, String>> _ceFaqs = [
  // ===== Fees come first =====
  {
    'q': 'How much does CE accreditation cost?',
    'a':
        'The accreditation fee for a Cybersecurity Establishment (CE) is GHS 5,000 per year.',
    'k': _priceWords,
  },
  {
    'q': 'What is a Cybersecurity Establishment (CE)?',
    'a':
        'A CE is any establishment set up within an organisation to investigate cybercrimes and mitigate cybersecurity incidents, including Digital Forensic Laboratories and Managed Cybersecurity Service Facilities.',
  },
  {
    'q': 'What types of CEs are to be accredited?',
    'a':
        'The two types are Digital Forensic Facilities and Managed Cybersecurity Service Facilities.',
  },
  {
    'q': 'What are the requirements for accreditation of a CE?',
    'a':
        'Requirements include completing an online application, describing services and technology setup, submitting standard operating procedures, validating employed professionals, and submitting business registration documents.',
  },
  {
    'q': 'What is the turnaround time for a CE accreditation?',
    'a':
        'The CSA will inform the applicant of its decision within 30 days of receiving a complete application.',
  },
  {
    'q': 'What is the validity period of a CE accreditation?',
    'a':
        'An accreditation certificate is valid for two years. Renewal must be applied for at least one month before expiry.',
  },
  {
    'q': 'Can a CE accreditation be suspended or revoked?',
    'a':
        'Yes. A CE accreditation may be suspended for up to six months or revoked if obtained by fraud, if the CE ceases operations, or if the holder no longer meets accreditation requirements.',
  },
];

const List<Map<String, String>> _cpFaqs = [
  // ===== Fees come first =====
  {
    'q': 'How much does CP accreditation cost?',
    'a':
        'The annual accreditation fee for a Cybersecurity Professional depends on the tier:\n\n'
        '• Tier 1: GHS 5,000 per year\n'
        '• Tier 2: GHS 3,000 per year\n'
        '• Tier 3: GHS 2,000 per year\n'
        '• Generals: GHS 500 per year',
    'k': _priceWords,
  },
  {
    'q': 'What is the accreditation fee for a Tier 1 Professional?',
    'a': 'The accreditation fee for a Tier 1 Cybersecurity Professional is GHS 5,000 per year.',
    'k': _priceWords,
  },
  {
    'q': 'What is the accreditation fee for a Tier 2 Professional?',
    'a': 'The accreditation fee for a Tier 2 Cybersecurity Professional is GHS 3,000 per year.',
    'k': _priceWords,
  },
  {
    'q': 'What is the accreditation fee for a Tier 3 Professional?',
    'a': 'The accreditation fee for a Tier 3 Cybersecurity Professional is GHS 2,000 per year.',
    'k': _priceWords,
  },
  {
    'q': 'What is the accreditation fee for a General Professional?',
    'a': 'The accreditation fee for a General (Generals) Cybersecurity Professional is GHS 500 per year.',
    'k': _priceWords,
  },
  {
    'q': 'Who is a Cybersecurity Professional (CP)?',
    'a':
        'A CP is a person accredited under Act 1038 to perform a cybersecurity-related professional function.',
  },
  {
    'q': 'What are the requirements for accreditation of a CP?',
    'a':
        'Requirements include completing an online application, submitting a national ID, a CV showing relevant cybersecurity experience, a recommendation or reference, and an undertaking to undergo background checks.',
  },
  {
    'q': 'What are the requirements for foreign CPs?',
    'a':
        'Foreign CPs must submit a background check report, a valid travel document, evidence of a job or consultancy offer in Ghana, relevant qualifications and certifications, and insurance cover where applicable.',
  },
  {
    'q': 'What is the turnaround time for CP accreditation?',
    'a':
        'The CSA will inform the applicant of its decision within 30 days of receiving a complete application.',
  },
  {
    'q': 'What is the validity period of a CP accreditation?',
    'a':
        'An accreditation certificate is valid for two years. Renewal must be applied for at least one month before expiry.',
  },
  {
    'q': 'Can a CP accreditation be suspended or revoked?',
    'a':
        'Yes. A CP accreditation may be suspended for up to six months or revoked if obtained by fraud, if the holder ceases operations, or no longer meets the accreditation requirements.',
  },
  {
    'q': 'Can an accreditation be transferred to another CP?',
    'a':
        'No. An accreditation certificate cannot be transferred to another CP.',
  },
];