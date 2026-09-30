import 'package:flutter/material.dart';

import '../../widgets/swipe_back.dart';

class ReportNotSuccessfulScreen extends StatelessWidget {
  final String? errorMessage;

  const ReportNotSuccessfulScreen({super.key, this.errorMessage});

  static const Color primaryBlue = Color(0xFF00334D);
  static const Color lightRed = Color(0xFFFDECEA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        // Back arrow stays HERE (unlike the success screen) — the point
        // of this screen is to send the reporter back to fix + resubmit.
        iconTheme: const IconThemeData(color: Colors.black),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: const Text(
            'Report Incident',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 20,
              color: Colors.black,
            ),
          ),
        ),
      ),
      body: SwipeBack(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFF8F9FB),
                  border: Border.all(color: Colors.red, width: 4),
                ),
                child: const Center(
                  child: Icon(Icons.close, size: 50, color: Colors.red),
                ),
              ),

              const SizedBox(height: 24),

              const Text(
                'Submission Failed',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 12),

              Text(
                errorMessage?.trim().isNotEmpty == true
                    ? errorMessage!
                    : 'Your report could not be submitted. Check your internet connection and try again.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: lightRed),
                child: const Text(
                  'Nothing was sent. Go back, review your report, and submit '
                  'again. If it keeps failing, try later or contact CSA support.',
                  style: TextStyle(fontSize: 13, height: 1.5),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'BACK TO REPORT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
