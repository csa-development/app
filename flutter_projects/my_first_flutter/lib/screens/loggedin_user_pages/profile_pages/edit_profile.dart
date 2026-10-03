import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/phone_number.dart';

import '../../../services/api_service.dart';
import '../../../services/auth_storage.dart';
import '../../../services/phone_format.dart';
import '../../../widgets/local_image.dart';
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

  bool _isLoading = false;
  String _originalPhone = '';

  // The flag phone field reads its starting value once, so it is only
  // built after the saved number has been loaded and split (null until
  // then). `_phone` is what the user has typed since; `_phoneEdited`
  // stays false until they touch the field, so merely opening this
  // screen can never be mistaken for a number change.
  SplitPhone? _initialPhone;
  PhoneNumber? _phone;
  bool _phoneEdited = false;

  // Faded 'xx xxx xxxx'-style placeholder for the selected country.
  String _phoneHint = phoneMaskForIso('GH');

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
      _originalPhone = phone ?? '';
      _initialPhone = splitStoredPhone(_originalPhone);
      _phoneHint = phoneMaskForIso(_initialPhone!.isoCode);
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// The full international number the user has typed ('+233244123456'),
  /// or '' if they haven't touched the field or have cleared it.
  String get _typedPhone {
    final phone = _phone;
    if (!_phoneEdited || phone == null || phone.number.isEmpty) return '';
    return phone.completeNumber;
  }

  bool get _typedPhoneIsValid {
    final phone = _phone;
    if (phone == null) return true;
    try {
      return phone.isValidNumber();
    } catch (_) {
      // Too short, too long, or an unknown country code.
      return false;
    }
  }

  Future<void> _saveChanges() async {
    if (_fullNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      showTopToast(context, 'Full name and email are required');
      return;
    }

    // Compared as numbers, not text, so a number saved long ago as
    // '0244123456' isn't "changed" just because the flag field shows it
    // as +233 244123456.
    final newPhone = _typedPhone;
    final phoneChanged = newPhone.isNotEmpty &&
        canonicalPhone(newPhone) != canonicalPhone(_originalPhone);

    // Checked before anything is saved or any code is sent, so a half-typed
    // number never triggers a verification SMS.
    if (phoneChanged && !_typedPhoneIsValid) {
      showTopToast(context, 'Enter a valid phone number');
      return;
    }

    setState(() => _isLoading = true);

    final accessToken = await AuthStorage.getAccessToken() ?? '';

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

    if (phoneChanged) {
      setState(() => _isLoading = false);
      if (!context.mounted) return;
      // If the code isn't confirmed (cancelled, wrong, expired) the new
      // number is simply never saved; the screen closes either way.
      await _verifyAndSaveNewPhone(newPhone);
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
                                ? localImage(
                                    path,
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
            _phoneField(),

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

  // Same flag + country-code field as the login and registration screens,
  // styled to match the other fields on this page.
  Widget _phoneField() {
    final initial = _initialPhone;

    final box = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFE4E6EB)),
    );

    if (initial == null) {
      // Holds the field's place while the saved number loads.
      return Container(height: 56, decoration: box);
    }

    const textStyle = TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      color: Colors.black87,
    );

    return Container(
      decoration: box,
      child: IntlPhoneField(
        initialCountryCode: initial.isoCode,
        initialValue: initial.national,
        // Lets the package enforce each country's real number length.
        disableLengthCheck: false,
        // Digits only, so the country's digit limit is the only thing that
        // can be typed or pasted.
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        invalidNumberMessage: '',
        cursorColor: Colors.black54,
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          counterText: '',
          hintText: _phoneHint,
          hintStyle: const TextStyle(fontSize: 15, color: Colors.black26),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
        style: textStyle,
        dropdownTextStyle: textStyle,
        flagsButtonPadding: const EdgeInsets.only(left: 16, right: 8),
        showDropdownIcon: true,
        dropdownIcon: const Icon(Icons.arrow_drop_down, color: Colors.black45),
        onChanged: (phone) {
          _phone = phone;
          _phoneEdited = true;
        },
        onCountryChanged: (country) {
          // The digits stay in the box when only the country changes, and
          // onChanged doesn't fire for that, so rebuild the number here.
          _phone = PhoneNumber(
            countryISOCode: country.code,
            countryCode: '+${country.fullCountryCode}',
            number: _phone?.number ?? initial.national,
          );
          _phoneEdited = true;
          setState(() => _phoneHint = phoneMaskFor(country));
        },
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
