import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../../services/auth_storage.dart';
import '../../../widgets/swipe_back.dart';
import '../../../widgets/top_toast.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (_currentController.text.trim().isEmpty ||
        _newController.text.trim().isEmpty ||
        _confirmController.text.trim().isEmpty) {
      showTopToast(context, 'Please fill in all fields');
      return;
    }

    if (_newController.text.trim() != _confirmController.text.trim()) {
      showTopToast(context, 'New passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    final accessToken = await AuthStorage.getAccessToken() ?? '';

    final result = await ApiService.changePassword(
      accessToken: accessToken,
      currentPassword: _currentController.text.trim(),
      newPassword: _newController.text.trim(),
      confirmPassword: _confirmController.text.trim(),
    );

    setState(() => _isLoading = false);

    if (!context.mounted) return;

    if (result['success']) {
      showTopToast(context, 'Password changed successfully', isError: false);
      Navigator.pop(context);
    } else {
      showTopToast(context, result['error'] ?? 'Failed to change password');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FB),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Change Password',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: SwipeBack(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE4E6EB)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 18, color: Color(0xFFE53935)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your password must be at least 8 characters and include a number and a special character.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            const Text(
              'CURRENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black38,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 12),

            _passwordTile(
              controller: _currentController,
              hint: 'Current password',
              icon: Icons.lock_outline,
              visible: _showCurrent,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
            ),

            const SizedBox(height: 24),

            const Text(
              'NEW',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.black38,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 12),

            _passwordTile(
              controller: _newController,
              hint: 'New password',
              icon: Icons.lock_outline,
              visible: _showNew,
              onToggle: () => setState(() => _showNew = !_showNew),
            ),

            const SizedBox(height: 12),

            _passwordTile(
              controller: _confirmController,
              hint: 'Confirm new password',
              icon: Icons.lock_outline,
              visible: _showConfirm,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00334D),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                onPressed: _isLoading ? null : _changePassword,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'UPDATE PASSWORD',
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
      ),
    );
  }

  Widget _passwordTile({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool visible,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E6EB)),
      ),
      child: TextField(
        controller: controller,
        obscureText: !visible,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20, color: Colors.black45), 
          suffixIcon: IconButton(
            icon: Icon(
              visible
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: Colors.black38,
            ),
            onPressed: onToggle,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
        ),
      ),
    );
  }
}
