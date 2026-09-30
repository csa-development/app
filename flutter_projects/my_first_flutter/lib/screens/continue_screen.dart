import 'package:flutter/material.dart';

import 'main_user.dart';
import 'registration_flow.dart';

class ContinueScreen extends StatelessWidget {
  final VoidCallback onGoToLogin;

  const ContinueScreen({super.key, required this.onGoToLogin});

  static const Color primaryBlue = Color(0xFF00334D);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(flex: 3),

            const Text(
              'NEXT STEP',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black45,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'How would you like to continue?',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 14),

            const Text(
              'You can log in to your existing account, create a new account to access more features, or continue without an account for now.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.6,
              ),
            ),

            const Spacer(flex: 3),

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
                // Swipes to the login page instead of pushing a
                // new route — Login is now a sibling page in the
                // same PageView, not a separate stack entry.
                onPressed: onGoToLogin,
                child: const Text(
                  'LOGIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primaryBlue),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistrationFlow(),
                    ),
                  );
                },
                child: const Text(
                  'CREATE ACCOUNT',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            GestureDetector(
              onTap: () {
                // push (not pushReplacement) so ContinueLoginFlow stays
                // underneath — a right-swipe / back on the guest home
                // then slides back here, same as Login and Create
                // Account do.
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MainUserScreen()),
                );
              },
              child: const Center(
                child: Text(
                  'Continue without an account',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}