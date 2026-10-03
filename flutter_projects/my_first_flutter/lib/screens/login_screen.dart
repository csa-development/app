import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../services/api_service.dart';
import '../services/phone_format.dart';
import 'login_verification.dart';
import '../widgets/top_toast.dart';

enum IdentificationMethod { phone, email }

class LoginScreen extends StatefulWidget {
  final VoidCallback onBack;

  const LoginScreen({
    super.key,
    required this.onBack,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  IdentificationMethod? _selectedMethod;

  final TextEditingController _inputController =
      TextEditingController();

  static const Color lightBg = Color(0xFFF3F6F9);
  static const Color primaryBlue = Color(0xFF00334D);

  bool _isLoading = false;
  String _completePhoneNumber = '';

  // Faded 'xx xxx xxxx'-style placeholder for the selected country.
  String _phoneHint = phoneMaskForIso('GH');

  static const double fieldRadius = 8;

  final FocusNode _phoneFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();

  @override
  void dispose() {
    _inputController.dispose();
    _phoneFocusNode.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  String _getMethod() {
    switch (_selectedMethod) {
      case IdentificationMethod.phone:
        return 'phone';

      case IdentificationMethod.email:
        return 'email';

      default:
        return '';
    }
  }

  void _showTopError(String message) {
    showTopToast(context, message);
  }

  Future<void> _requestOtp() async {
    String identifier;

    if (_selectedMethod == IdentificationMethod.phone) {
      if (_completePhoneNumber.isEmpty) {
        _showTopError(
          'Please enter your phone number',
        );

        return;
      }

      identifier = _completePhoneNumber;
    } else {
      identifier = _inputController.text.trim();

      if (identifier.isEmpty) {
        _showTopError(
          'Please enter your email address',
        );

        return;
      }
    }

    setState(() => _isLoading = true);

    final result = await ApiService.requestOtp(
      identifier: identifier,
      method: _getMethod(),
    );

    setState(() => _isLoading = false);

    if (!context.mounted) return;

    if (result['success']) {
      final username =
          result['data']['username'];

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerificationScreen(
            username: username,
            identifier: identifier,
            method: _getMethod(),
            deliveredVia: result['data']['delivered_via'],
          ),
        ),
      );
    } else {
      _showTopError(
        result['error'] ??
            'Failed to send OTP',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Swipe-right-to-go-back is handled one level up, by
    // continue_login_flow.dart's own GestureDetector wrapping this
    // whole screen — this used to ALSO have its own identical
    // onHorizontalDragEnd handler here, and Flutter doesn't suppress
    // an ancestor GestureDetector from also firing for the same drag,
    // so both fired and both called animateToPage(0) back-to-back,
    // which visibly glitched (a flash in the wrong direction) as the
    // second call interrupted the first mid-animation.
    return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              // ==================================================
              // BACK BUTTON
              // ==================================================

              GestureDetector(
                onTap: widget.onBack,
                child: Container(
                  decoration:
                      const BoxDecoration(
                    color: lightBg,
                    shape: BoxShape.circle,
                  ),
                  padding:
                      const EdgeInsets.all(8),
                  child: const Icon(
                    Icons.arrow_back,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ==================================================
              // TITLE
              // ==================================================

              const Text(
                'WELCOME BACK',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Login here to securely access your account',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 32),

              // ==================================================
              // IDENTIFICATION METHOD
              // ==================================================

              const Text(
                'Select Identification Method',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),

              const SizedBox(height: 12),

              _buildMethodOption(
                IdentificationMethod.phone,
                'Phone Number',
                Icons.phone_outlined,
              ),

              _buildMethodOption(
                IdentificationMethod.email,
                'Email Address',
                Icons.mail_outline,
              ),

              if (_selectedMethod != null) ...[
                const SizedBox(height: 24),

                // ==================================================
                // PHONE NUMBER
                // ==================================================

                if (_selectedMethod ==
                    IdentificationMethod.phone) ...[
                  const Text(
                    'Phone Number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        fieldRadius,
                      ),
                      border: Border.all(
                        color: primaryBlue,
                      ),
                    ),
                    child: IntlPhoneField(
                      focusNode:
                          _phoneFocusNode,

                      initialCountryCode: 'GH',

                      // Same fix as registration_screen.dart — lets
                      // the package enforce each country's real
                      // number length instead of accepting unlimited
                      // digits regardless of country.
                      disableLengthCheck: false,

                      // Digits only, so the country's digit limit is the
                      // only thing that can be typed or pasted.
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],

                      invalidNumberMessage: '',

                      cursorColor:
                          Colors.black54,

                      decoration:
                          InputDecoration(
                        border:
                            InputBorder.none,
                        enabledBorder:
                            InputBorder.none,
                        disabledBorder:
                            InputBorder.none,
                        errorBorder:
                            InputBorder.none,
                        focusedErrorBorder:
                            InputBorder.none,
                        focusedBorder:
                            InputBorder.none,

                        counterText: '',
                        hintText: _phoneHint,
                        hintStyle: const TextStyle(
                          fontSize: 15,
                          color: Colors.black26,
                        ),

                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),

                        errorStyle:
                            const TextStyle(
                          height: 0,
                          fontSize: 0,
                        ),

                        suffixIcon:
                            _completePhoneNumber
                                    .isNotEmpty
                                ? const Padding(
                                    padding:
                                        EdgeInsets
                                            .only(
                                      right: 12,
                                    ),
                                    child:
                                        _RoundCheck(),
                                  )
                                : null,

                        suffixIconConstraints:
                            const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                      ),

                      style:
                          const TextStyle(
                        fontSize: 15,
                        color:
                            Colors.black87,
                      ),

                      dropdownTextStyle:
                          const TextStyle(
                        fontSize: 15,
                        color:
                            Colors.black87,
                      ),

                      flagsButtonPadding:
                          const EdgeInsets
                              .only(
                        left: 16,
                        right: 8,
                      ),

                      showDropdownIcon: true,

                      dropdownIcon:
                          const Icon(
                        Icons.arrow_drop_down,
                        color:
                            Colors.black45,
                      ),

                      onChanged: (phone) {
                        setState(() {
                          _completePhoneNumber =
                              phone
                                  .completeNumber;
                        });
                      },

                      onCountryChanged:
                          (country) {
                        setState(() {
                          _completePhoneNumber =
                              '';
                          _phoneHint =
                              phoneMaskFor(country);
                        });
                      },
                    ),
                  ),
                ]

                // ==================================================
                // EMAIL
                // ==================================================

                else ...[
                  const Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(
                        fieldRadius,
                      ),
                      border: Border.all(
                        color: primaryBlue,
                      ),
                    ),
                    child: TextField(
                      controller:
                          _inputController,

                      focusNode:
                          _emailFocusNode,

                      keyboardType:
                          TextInputType
                              .emailAddress,

                      cursorColor:
                          Colors.black54,

                      onChanged: (_) =>
                          setState(() {}),

                      decoration:
                          InputDecoration(
                        border:
                            InputBorder.none,
                        enabledBorder:
                            InputBorder.none,
                        disabledBorder:
                            InputBorder.none,
                        errorBorder:
                            InputBorder.none,
                        focusedErrorBorder:
                            InputBorder.none,
                        focusedBorder:
                            InputBorder.none,

                        contentPadding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),

                        hintText:
                            'Enter here',

                        hintStyle:
                            const TextStyle(
                          color:
                              Colors.black38,
                        ),

                        suffixIcon:
                            _inputController
                                    .text
                                    .trim()
                                    .isNotEmpty
                                ? const Padding(
                                    padding:
                                        EdgeInsets
                                            .only(
                                      right: 12,
                                    ),
                                    child:
                                        _RoundCheck(),
                                  )
                                : null,

                        suffixIconConstraints:
                            const BoxConstraints(
                          minWidth: 0,
                          minHeight: 0,
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ==================================================
                // CONTINUE BUTTON
                // ==================================================

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          primaryBlue,

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          fieldRadius,
                        ),
                      ),
                    ),

                    onPressed: _isLoading
                        ? null
                        : _requestOtp,

                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color:
                                Colors.white,
                          )
                        : const Text(
                            'CONTINUE',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 16,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
    );
  }

  // ============================================================
  // IDENTIFICATION OPTION
  // ============================================================

  Widget _buildMethodOption(
    IdentificationMethod method,
    String title,
    IconData icon,
  ) {
    final bool isSelected =
        _selectedMethod == method;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMethod = method;

          _inputController.clear();

          _completePhoneNumber = '';

          // The phone field is rebuilt showing Ghana again.
          _phoneHint = phoneMaskForIso('GH');
        });

        WidgetsBinding.instance
            .addPostFrameCallback((_) {
          if (!mounted) return;

          if (method ==
              IdentificationMethod.phone) {
            _phoneFocusNode
                .requestFocus();
          } else {
            _emailFocusNode
                .requestFocus();
          }
        });
      },

      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 12,
        ),

        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(
            fieldRadius,
          ),

          border: Border.all(
            color:
                const Color(0xFFE4E6EB),
            width: 1,
          ),
        ),

        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Colors.black45,
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,
                style:
                    const TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w400,
                  color: Colors.black87,
                ),
              ),
            ),

            Container(
              width: 18,
              height: 18,

              decoration: BoxDecoration(
                shape:
                    BoxShape.circle,

                color: isSelected
                    ? primaryBlue
                    : Colors.transparent,

                border: Border.all(
                  color: isSelected
                      ? primaryBlue
                      : Colors
                          .grey.shade400,
                ),
              ),

              child: isSelected
                  ? const Icon(
                      Icons.check,
                      size: 12,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ROUND CHECK
// ============================================================

class _RoundCheck extends StatelessWidget {
  const _RoundCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration:
          const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green,
      ),
      child: const Icon(
        Icons.check,
        size: 13,
        color: Colors.white,
      ),
    );
  }
}
