import 'package:flutter/material.dart';

class AgonaAwareness extends StatelessWidget {
  const AgonaAwareness({super.key});

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
            'Awareness Creation',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== Title =====
            const Text(
              'CYBER HYGIENE AWARENESS IN AGONA WEST MUNICIPALITY',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 16),

            // ===== Image =====
            ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: Image.asset(
                'assets/main_user_images/im6.jpg',
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
              ),
            ),

            const SizedBox(height: 20),

            // ===== Body Text =====
            const Text(
              'On Monday, 8th September 2025, the Cyber Security Authority (CSA) of Ghana, in collaboration with the Office of the Head of the Local Government Service, held a comprehensive cyber hygiene sensitisation programme for staff and citizens of the Agona West Municipality. This initiative aims to enhance public awareness of cyber threats and promote safe digital practices as part of Ghana\'s broader agenda to bolster national cyber resilience.',
              style: TextStyle(
                fontSize: 15,
                height: 1.8,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
