import 'package:flutter/material.dart';

import 'dart:async';

import '../services/auth_storage.dart';
import '../services/notification_service.dart';
import 'loggedin_user_pages/dashboard.dart';

class VerifiedScreen extends StatefulWidget {
  final String fullName;
  final String accessToken;
  final String refreshToken;
  final String username;
  final String email;
  final String phone;

  const VerifiedScreen({
    super.key,
    required this.fullName,
    required this.accessToken,
    this.refreshToken = '',
    required this.username,
    required this.email,
    required this.phone,
  });

  @override
  State<VerifiedScreen> createState() => _VerifiedScreenState();
}

class _VerifiedScreenState extends State<VerifiedScreen> {
  static const Color primaryBlue = Color(0xFF00334D);

  @override
  void initState() {
    super.initState();
    _saveSession();
  }

  Future<void> _saveSession() async {
    await AuthStorage.saveSession(
      accessToken: widget.accessToken,
      refreshToken: widget.refreshToken,
      username: widget.username,
      fullName: widget.fullName,
      email: widget.email,
      phone: widget.phone,
    );

    // initialize() in main.dart runs before login, so it had no access
    // token to save the device token against yet — do it now that
    // AuthStorage actually has one.
    unawaited(NotificationService.syncTokenWithBackend());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Center(
                child: Icon(Icons.check_circle, size: 120, color: Colors.green),
              ),
              const SizedBox(height: 32),
              const Text(
                'Login Successful',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Text(
                'Welcome back, ${widget.fullName}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 48),
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
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoggedInDashboard(),
                      ),
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'CONTINUE',
                    style: TextStyle(color: Colors.white, fontSize: 16),
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