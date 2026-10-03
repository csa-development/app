import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../widgets/swipe_back.dart';
import '../../../widgets/top_toast.dart';
import 'verified_failed.dart';
import 'verify_success.dart';

class Verifyli extends StatefulWidget {
  const Verifyli({super.key});

  @override
  State<Verifyli> createState() => _VerifyliState();
}

class _VerifyliState extends State<Verifyli> {
  static const Color primaryBlue = Color(0xFF00334D);

  String? _selectedType;
  bool _isLoading = false;
  final TextEditingController _certificateController =
      TextEditingController();

  final List<String> certificateTypes = [
    'Cybersecurity Service Provider (CSP)',
    'Cybersecurity Establishment (CE)',
    'Cybersecurity Professional (CP)',
  ];

  @override
  void dispose() {
    _certificateController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_certificateController.text.trim().isEmpty) {
      showTopToast(context, 'Please enter a certificate number');
      return;
    }

    if (_selectedType == null) {
      showTopToast(context, 'Please select a certificate type');
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.verifyCertificate(
      certificateNumber: _certificateController.text.trim(),
      certificateType: _selectedType!,
    );

    setState(() => _isLoading = false);

    if (!context.mounted) return;

    if (result['success'] && result['data']['valid'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerifySuccess(
            holderName: result['data']['holder_name'] ?? '',
            organisation: result['data']['organisation'] ?? '',
            certificateNumber:
                result['data']['certificate_number'] ?? '',
            certificateType: result['data']['certificate_type'] ?? '',
            issueDate: result['data']['issue_date'] ?? '',
            expiryDate: result['data']['expiry_date'] ?? '',
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const VerifyFailed()),
      );
    }
  }

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
            'Verify Certificate',
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
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the certificate number to verify its validity.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 28),

            _label('Certificate Number'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E6EB)),
              ),
              child: TextField(
                controller: _certificateController,
                style: const TextStyle(
                    fontSize: 15, color: Colors.black87),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  hintText: 'Enter certificate number',
                  hintStyle: TextStyle(
                      color: Colors.black45, fontSize: 15),
                ),
              ),
            ),

            const SizedBox(height: 20),

            _label('Certificate Type'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E6EB)),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedType,
                isExpanded: true,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
                  hintText: 'Select certificate type',
                  hintStyle: TextStyle(
                      color: Colors.black45, fontSize: 15),
                ),
                style: const TextStyle(
                    fontSize: 15, color: Colors.black87),
                items: certificateTypes.map((type) {
                  return DropdownMenuItem<String>(
                    value: type,
                    child: Text(type,
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedType = value);
                },
              ),
            ),

            const SizedBox(height: 32),

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
                onPressed: _isLoading ? null : _verify,
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white)
                    : const Text(
                        'VERIFY',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
      ),
    );
  }

  Widget _label(String text) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
        children: const [
          TextSpan(
            text: ' *',
            style: TextStyle(color: Colors.red),
          ),
        ],
      ),
    );
  }
}