import 'package:flutter/material.dart';

import '../../../widgets/swipe_back.dart';

class VerifySuccess extends StatelessWidget {
  final String holderName;
  final String organisation;
  final String certificateNumber;
  final String certificateType;
  final String issueDate;
  final String expiryDate;

  const VerifySuccess({
    super.key,
    required this.holderName,
    required this.organisation,
    required this.certificateNumber,
    required this.certificateType,
    required this.issueDate,
    required this.expiryDate,
  });

  static const Color primaryBlue = Color(0xFF00334D);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SwipeBack(
        child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.shade50,
                  ),
                  child: Icon(Icons.verified,
                      size: 72, color: Colors.green.shade600),
                ),
              ),

              const SizedBox(height: 32),

              const Text(
                'Certificate Verified!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),

              const SizedBox(height: 12),

              const Text(
                'This certificate is valid and active.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),

              const SizedBox(height: 48),

              _detailRow('Name', holderName),
              if (organisation.isNotEmpty)
                _detailRow('Organisation', organisation),
              _detailRow('Certificate No.', certificateNumber),
              _detailRow('Type', certificateType),
              _detailRow('Status', 'Active'),
              _detailRow('Issue Date', issueDate),
              _detailRow('Expiry Date', expiryDate),

              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryBlue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text(
                    'BACK TO HOME',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
