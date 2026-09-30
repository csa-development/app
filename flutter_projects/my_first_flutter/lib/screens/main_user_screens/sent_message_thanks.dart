import 'package:flutter/material.dart';
import '../main_user.dart';
import '../../widgets/swipe_back.dart';

class SentMessageThanksPage extends StatelessWidget {
  const SentMessageThanksPage({super.key});

  static const Color primaryBlue = Color(0xFF00334D);

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double padding = screenSize.width * 0.04;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
         centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: const Text(
            'Thank You',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      body: SwipeBack(
        child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text(
              'WE WILL GET BACK TO YOU SOON. THANK YOU.',
              style: TextStyle(fontSize: 50, fontWeight: FontWeight.w700),
            ),

             const SizedBox(height: 230),
            SizedBox(height: screenSize.height * 0.05),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const MainUserScreen()),
                    (route) => false,
                  );
                },
                child: const Text(
                  'HOME',
                  style: TextStyle(fontSize: 16,color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
