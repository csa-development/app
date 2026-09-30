import 'dart:io';

import 'package:flutter/material.dart';

import '../../../services/api_service.dart';
import '../../../services/auth_storage.dart';
import '../../../widgets/profile_image_picker.dart';
import '../../../widgets/swipe_back.dart';
import '../../../widgets/top_toast.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  static const Color primaryBlue = Color(0xFF00334D);

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  String _originalPhone = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    AuthStorage.getProfileImagePath();
  }

  Future<void> _pickImage() => showProfileImagePicker(context);

  Future<void> _loadUserData() async {
    final fullName = await AuthStorage.getFullName();
    final email = await AuthStorage.getEmail();
    final phone = await AuthStorage.getPhone();
    setState(() {
      _fullNameController.text = fullName ?? '';
      _emailController.text = email ?? '';
      _phoneController.text = phone ?? '';
      _originalPhone = phone ?? '';
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (_fullNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      showTopToast(context, 'Full name and email are required');
      return;
    }

    setState(() => _isLoading = true);

    final accessToken = await AuthStorage.getAccessToken() ?? '';
    final newPhone = _phoneController.text.trim();
    final phoneChanged = newPhone != _originalPhone;

    // Name/email save immediately, same as before. Phone number
    // changes are handled separately below — a new number has to be
    // verified (a code sent to it, entered back correctly) before
    // it's ever saved, so it's never sent to this call.
    final result = await ApiService.updateProfile(
      accessToken: accessToken,
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _originalPhone,
    );

    if (!result['success']) {
      if (!context.mounted) return;
      showTopToast(context, result['error'] ?? 'Failed to update profile');
      setState(() => _isLoading = false);
      return;
    }

    await AuthStorage.saveSession(
      accessToken: accessToken,
      username: await AuthStorage.getUsername() ?? '',
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _originalPhone,
    );

    if (phoneChanged && newPhone.isNotEmpty) {
      setState(() => _isLoading = false);
      if (!context.mounted) return;
      final verified = await _verifyAndSaveNewPhone(newPhone);
      if (!verified) {
        // Not confirmed (cancelled, wrong code too many times, etc.)
        // — put the field back to what's actually saved so the
        // screen doesn't show an unverified number as if it took.
        setState(() => _phoneController.text = _originalPhone);
      }
      if (!context.mounted) return;
      Navigator.pop(context);
      return;
    }

    if (!context.mounted) return;
    showTopToast(context, 'Profile updated successfully', isError: false);
    Navigator.pop(context);
    setState(() => _isLoading = false);
  }

  // Sends a verification code to `newPhone`, shows a dialog for the
  // user to enter it, and only saves the number to the profile once
  // it's confirmed. Returns whether it was actually saved.
  Future<bool> _verifyAndSaveNewPhone(String newPhone) async {
    final accessToken = await AuthStorage.getAccessToken() ?? '';

    final requestResult = await ApiService.requestPhoneChange(
      accessToken: accessToken,
      phone: newPhone,
    );

    if (!requestResult['success']) {
      if (!context.mounted) return false;
      showTopToast(
        context,
        requestResult['error'] ?? 'Failed to send verification code',
      );
      return false;
    }

    if (!context.mounted) return false;
    showTopToast(context, 'A code was sent to $newPhone', isError: false);

    return _showVerifyPhoneDialog(newPhone);
  }

  Future<bool> _showVerifyPhoneDialog(String newPhone) async {
    final codeController = TextEditingController();
    bool isVerifying = false;
    String? errorText;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              title: const Text(
                'Verify New Number',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter the 6-digit code sent to $newPhone to confirm '
                    "it's yours.",
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Enter code',
                      counterText: '',
                      errorText: errorText,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('CANCEL',
                      style: TextStyle(color: Colors.black45)),
                ),
                TextButton(
                  onPressed: isVerifying
                      ? null
                      : () async {
                          final code = codeController.text.trim();
                          if (code.length < 6) {
                            setDialogState(
                                () => errorText = 'Enter the full 6-digit code');
                            return;
                          }

                          setDialogState(() {
                            isVerifying = true;
                            errorText = null;
                          });

                          final accessToken =
                              await AuthStorage.getAccessToken() ?? '';
                          final result = await ApiService.confirmPhoneChange(
                            accessToken: accessToken,
                            code: code,
                          );

                          if (result['success']) {
                            await AuthStorage.saveSession(
                              accessToken: accessToken,
                              username: await AuthStorage.getUsername() ?? '',
                              fullName: await AuthStorage.getFullName() ?? '',
                              email: await AuthStorage.getEmail() ?? '',
                              phone: newPhone,
                            );
                            setState(() => _originalPhone = newPhone);
                            if (!dialogContext.mounted) return;
                            Navigator.pop(dialogContext, true);
                          } else {
                            setDialogState(() {
                              isVerifying = false;
                              errorText =
                                  result['error'] ?? 'Invalid or expired code';
                            });
                          }
                        },
                  child: isVerifying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('CONFIRM',
                          style: TextStyle(
                              color: primaryBlue, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true) {
      if (context.mounted) {
        showTopToast(context, 'Phone number updated successfully',
            isError: false);
      }
      return true;
    }
    return false;
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
          'Edit Profile',
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
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EEF8),
                        shape: BoxShape.circle,
                        border:
                            Border.all(color: Colors.grey.shade200, width: 2),
                      ),
                      child: ClipOval(
                        child: ValueListenableBuilder<String?>(
                          valueListenable: AuthStorage.profileImageNotifier,
                          builder: (context, path, _) {
                            return path != null
                                ? Image.file(
                                    File(path),
                                    fit: BoxFit.cover,
                                    width: 90,
                                    height: 90,
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: primaryBlue,
                                  );
                          },
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            GestureDetector(
              onTap: _pickImage,
              child: const Center(
                child: Text(
                  'Change photo',
                  style: TextStyle(
                    fontSize: 13,
                    color: primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            _fieldLabel('Full Name'),
            _inputField(_fullNameController, 'Full Name', Icons.person_outline),

            const SizedBox(height: 16),

            _fieldLabel('Email Address'),
            _inputField(_emailController, 'Email Address', Icons.mail_outline),

            const SizedBox(height: 16),

            _fieldLabel('Phone Number'),
            _inputField(_phoneController, 'Phone Number', Icons.phone_outlined),

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
                onPressed: _isLoading ? null : _saveChanges,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'SAVE CHANGES',
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

  Widget _fieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _inputField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE4E6EB)),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: readOnly ? Colors.black38 : Colors.black87,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 20, color: Colors.black45),
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
