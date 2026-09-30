import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../widgets/legal_policy_dialog.dart';
import 'continue_login_flow.dart';
import 'registration_flow.dart';

class RegistrationScreen2 extends StatefulWidget {
  final TextEditingController firstNameController;
  final TextEditingController surnameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onBack;

  const RegistrationScreen2({
    super.key,
    required this.firstNameController,
    required this.surnameController,
    required this.emailController,
    required this.phoneController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onBack,
  });

  @override
  State<RegistrationScreen2> createState() => _RegistrationScreen2State();
}

class _RegistrationScreen2State extends State<RegistrationScreen2> {
  static const Color primaryBlue = Color(0xFF00334D);
  static const Color lightBg = Color(0xFFF3F6F9);
  static const double fieldRadius = 8;

  bool _agreeToTerms = false;
  bool _isLoading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  Future<void> _register() async {
    final password = widget.passwordController.text.trim();
    final confirmPassword = widget.confirmPasswordController.text.trim();

    if (password.isEmpty || confirmPassword.isEmpty) {
      showRegistrationTopError(context, 'Please fill in all fields');
      return;
    }

    if (password != confirmPassword) {
      showRegistrationTopError(context, 'Passwords do not match');
      return;
    }

    if (password.length < 8) {
      showRegistrationTopError(
        context,
        'Password must be at least 8 characters',
      );
      return;
    }

    setState(() => _isLoading = true);

    final firstName = widget.firstNameController.text.trim();
    final surname = widget.surnameController.text.trim();
    final fullName = '$firstName $surname'.trim();

    // NOTE: nationalId has been removed from this call. Your Django
    // backend's register_user view (accounts/views.py) currently
    // uses national_id as the account's username — that endpoint
    // will need to be updated separately, or registration will fail
    // server-side even though this screen now builds and runs fine.
    final result = await ApiService.register(
      fullName: fullName,
      email: widget.emailController.text.trim(),
      phone: widget.phoneController.text.trim(),
      password: password,
    );

    setState(() => _isLoading = false);

    if (!context.mounted) return;

    if (result['success']) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          title: const Text(
            'Registration Successful',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Your account has been created. Please login to continue.',
            style: TextStyle(color: Colors.black54),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const ContinueLoginFlow()),
                  (route) => false,
                );
              },
              child: const Text(
                'CANCEL',
                style: TextStyle(color: Colors.black45),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ContinueLoginFlow(initialPage: 1),
                  ),
                  (route) => false,
                );
              },
              child: const Text(
                'LOGIN',
                style: TextStyle(
                  color: primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      showRegistrationTopError(
        context,
        result['error'] ?? 'Registration failed',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              // Swipes back to Step 1 instead of popping — this
              // screen no longer has its own route to pop from,
              // since both steps share one PageView now.
              onTap: widget.onBack,
              child: Container(
                decoration: const BoxDecoration(
                  color: lightBg,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.arrow_back),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'STEP 2 OF 2',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryBlue,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'SECURITY DETAILS',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
            ),

            const SizedBox(height: 8),

            const Text(
              'Set up your password to secure your account',
              style: TextStyle(fontSize: 15, color: Colors.black54),
            ),

            const SizedBox(height: 32),

            _label('Password'),
            const SizedBox(height: 8),
            _passwordField(
              controller: widget.passwordController,
              hint: 'Create password',
              visible: _showPassword,
              onToggle: () => setState(() => _showPassword = !_showPassword),
            ),

            const SizedBox(height: 24),

            _label('Confirm Password'),
            const SizedBox(height: 8),
            _passwordField(
              controller: widget.confirmPasswordController,
              hint: 'Repeat password',
              visible: _showConfirmPassword,
              onToggle: () => setState(
                () => _showConfirmPassword = !_showConfirmPassword,
              ),
            ),

            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Checkbox(
                  value: _agreeToTerms,
                  activeColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (value) =>
                      setState(() => _agreeToTerms = value ?? false),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                        height: 1.5,
                      ),
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: const TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: primaryBlue,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => showLegalDocumentDialog(
                                  context,
                                  title: 'Terms of Use',
                                  sections: termsOfUseSections,
                                ),
                        ),
                        const TextSpan(text: ' and '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(
                            color: primaryBlue,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: primaryBlue,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => showLegalDocumentDialog(
                                  context,
                                  title: 'Privacy Policy',
                                  sections: privacyPolicySections,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(fieldRadius),
                  ),
                ),
                onPressed: _agreeToTerms && !_isLoading ? _register : null,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'REGISTER',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.black54,
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(fieldRadius),
        border: Border.all(color: const Color(0xFFE4E6EB)),
      ),
      child: TextField(
        controller: controller,
        obscureText: !visible,
        style: const TextStyle(fontSize: 15, color: Colors.black87),
        decoration: InputDecoration(
          suffixIcon: IconButton(
            icon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => RotationTransition(
                turns: animation,
                child: child,
              ),
              child: Icon(
                visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                key: ValueKey<bool>(visible),
                size: 20,
                color: Colors.black45,
              ),
            ),
            onPressed: onToggle,
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}