import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../services/phone_format.dart';
import 'registration_flow.dart';

class RegistrationScreen extends StatefulWidget {
  final TextEditingController firstNameController;
  final TextEditingController surnameController;
  final TextEditingController emailController;
  final TextEditingController phoneController;
  final VoidCallback onNext;

  const RegistrationScreen({
    super.key,
    required this.firstNameController,
    required this.surnameController,
    required this.emailController,
    required this.phoneController,
    required this.onNext,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  static const Color primaryBlue = Color(0xFF00334D);
  static const Color lightBg = Color(0xFFF3F6F9);
  static const double fieldRadius = 8;

  // Faded 'xx xxx xxxx'-style placeholder for the selected country.
  String _phoneHint = phoneMaskForIso('GH');

  final FocusNode _firstNameFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    widget.firstNameController.addListener(_onFieldChanged);
    widget.surnameController.addListener(_onFieldChanged);
    widget.emailController.addListener(_onFieldChanged);
    widget.phoneController.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _firstNameFocusNode.requestFocus();
      }
    });
  }

  void _onFieldChanged() => setState(() {});

  @override
  void dispose() {
    widget.firstNameController.removeListener(_onFieldChanged);
    widget.surnameController.removeListener(_onFieldChanged);
    widget.emailController.removeListener(_onFieldChanged);
    widget.phoneController.removeListener(_onFieldChanged);

    _firstNameFocusNode.dispose();
    super.dispose();
  }

  void _handleNext() {
    final firstName = widget.firstNameController.text.trim();
    final surname = widget.surnameController.text.trim();
    final email = widget.emailController.text.trim();
    final phone = widget.phoneController.text.trim();

    if (firstName.isEmpty) {
      showRegistrationTopError(
        context,
        'Please enter your first name',
      );
      return;
    }

    if (surname.isEmpty) {
      showRegistrationTopError(
        context,
        'Please enter your surname',
      );
      return;
    }

    if (email.isEmpty) {
      showRegistrationTopError(
        context,
        'Please enter your email address',
      );
      return;
    }

    if (phone.isEmpty) {
      showRegistrationTopError(
        context,
        'Please enter your phone number',
      );
      return;
    }

    widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: 28,
          vertical: 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: lightBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'STEP 1 OF 2',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: primaryBlue,
                letterSpacing: 1.2,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'CREATE AN ACCOUNT',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Enter your personal details to get started',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 32),

            _label('First Name'),
            _inputField(
              controller: widget.firstNameController,
              hint: 'Enter first name',
              icon: Icons.person_outline,
              focusNode: _firstNameFocusNode,
            ),

            _label('Surname'),
            _inputField(
              controller: widget.surnameController,
              hint: 'Enter surname',
              icon: Icons.person_outline,
            ),

            _label('Email Address'),
            _inputField(
              controller: widget.emailController,
              hint: 'Enter your email address',
              icon: Icons.mail_outline,
              keyboardType: TextInputType.emailAddress,
            ),

            _label('Phone Number'),

            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(fieldRadius),
                border: Border.all(
                  color: const Color(0xFFE4E6EB),
                ),
              ),
              child: IntlPhoneField(
                initialCountryCode: 'GH',
                // Re-enabled: the package already knows each country's
                // real number length (Ghana 9 digits, US 10, etc.) and
                // stops accepting more input past it automatically —
                // this was previously turned off, which let anyone
                // type an arbitrary number of digits regardless of
                // the selected country.
                disableLengthCheck: false,
                // Digits only, so the country's digit limit is the only
                // thing that can be typed or pasted.
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                invalidNumberMessage: '',
                cursorColor: primaryBlue,

                decoration: InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  counterText: '',
                  hintText: _phoneHint,
                  hintStyle: const TextStyle(
                    fontSize: 15,
                    color: Colors.black26,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  errorStyle: const TextStyle(
                    height: 0,
                    fontSize: 0,
                  ),
                  suffixIcon:
                      widget.phoneController.text.trim().isNotEmpty
                          ? const Padding(
                              padding: EdgeInsets.only(right: 12),
                              child: _RoundCheck(),
                            )
                          : null,
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 0,
                    minHeight: 0,
                  ),
                ),

                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),

                dropdownTextStyle: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                ),

                flagsButtonPadding: const EdgeInsets.only(
                  left: 16,
                  right: 8,
                ),

                showDropdownIcon: true,

                dropdownIcon: const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.black45,
                ),

                onChanged: (phone) {
                  widget.phoneController.text = phone.completeNumber;
                },

                onCountryChanged: (country) {
                  widget.phoneController.clear();
                  setState(() => _phoneHint = phoneMaskFor(country));
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
                    borderRadius: BorderRadius.circular(fieldRadius),
                  ),
                ),
                onPressed: _handleNext,
                child: const Text(
                  'NEXT',
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.black54,
        ),
      ),
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? focusNode,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(fieldRadius),
        border: Border.all(
          color: const Color(0xFFE4E6EB),
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            size: 20,
            color: Colors.black45,
          ),
          hintText: hint,
          hintStyle: const TextStyle(
            color: Colors.black38,
            fontSize: 14,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: controller.text.trim().isNotEmpty
              ? const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: _RoundCheck(),
                )
              : null,
          suffixIconConstraints: const BoxConstraints(
            minWidth: 0,
            minHeight: 0,
          ),
        ),
      ),
    );
  }
}

class _RoundCheck extends StatelessWidget {
  const _RoundCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check,
        size: 13,
        color: Colors.white,
      ),
    );
  }
}