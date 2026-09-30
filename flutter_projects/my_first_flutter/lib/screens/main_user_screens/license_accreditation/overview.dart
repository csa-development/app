import 'package:flutter/material.dart';

import '../../../widgets/swipe_back.dart';
import 'ce_page.dart';
import 'cii_page.dart';
import 'cp_page.dart';
import 'csp_page.dart';

class overviewli extends StatelessWidget {
  const overviewli({super.key});

  static const Color primaryBlue = Color(0xFF00334D);

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
            'Overview',
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
              'Licensed Categories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 16),

            _categoryTile(
              context,
              '1. Cybersecurity Service Providers (CSPs)',
              const CspPage(),
            ),
            _categoryTile(
              context,
              '2. Cybersecurity Establishments (CEs)',
              const CePage(),
            ),
            _categoryTile(
              context,
              '3. Cybersecurity Professionals (CPs)',
              const CpPage(),
            ),
            _categoryTile(
              context,
              '4. Critical Information Infrastructure (CII)',
              const CiiPage(),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }

  Widget _categoryTile(
      BuildContext context, String title, Widget destination) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => destination),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: primaryBlue.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryBlue.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF20202F),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right_rounded,
                color: primaryBlue, size: 24),
          ],
        ),
      ),
    );
  }
}