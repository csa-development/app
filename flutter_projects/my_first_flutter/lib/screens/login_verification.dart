import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/notification_service.dart';
import 'loggedin_user_pages/dashboard.dart';
import '../widgets/top_toast.dart';

class VerificationScreen extends StatefulWidget {
  final String username;
  final String identifier;
  final String method;
  // The channel the OTP was ACTUALLY delivered through, from the
  // request-otp response's `delivered_via` field — not necessarily the
  // same as `method`. A phone login falls back to email when SMS
  // fails (no SMS provider configured, network issue, etc.), and the
  // screen needs to say so honestly rather than always claiming
  // whatever the user originally chose. Null falls back to `method`
  // for safety (e.g. an older cached navigation without this field).
  final String? deliveredVia;

  const VerificationScreen({
    super.key,
    required this.username,
    required this.identifier,
    required this.method,
    this.deliveredVia,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  static const Color primaryBlue = Color(0xFF00334D);
  static const Color lightBg = Color(0xFFF3F6F9);

  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isResending = false;
  bool _isSigningIn = false;

  static const int _expirySeconds = 120;
  int _secondsUntilExpiry = _expirySeconds;
  bool _isExpired = false;
  Timer? _expiryTimer;

  // Starts from what the request-otp call actually reported; updated
  // again on resend, since a retry can land on a different channel
  // than the first attempt did.
  late String _deliveredVia;

  @override
  void initState() {
    super.initState();
    _deliveredVia = widget.deliveredVia ?? widget.method;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _otpFocusNode.requestFocus();
    });

    _startExpiryTimer();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _otpFocusNode.dispose();
    _expiryTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // RIGHT SWIPE = BACK TO LOGIN
  // LEFT SWIPE = NOTHING
  // ============================================================

  void _handleSwipe(DragEndDetails details) {
    if ((details.primaryVelocity ?? 0) > 300) {
      Navigator.pop(context);
    }
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();

    setState(() {
      _secondsUntilExpiry = _expirySeconds;
      _isExpired = false;
    });

    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsUntilExpiry <= 1) {
        timer.cancel();

        setState(() {
          _secondsUntilExpiry = 0;
          _isExpired = true;
        });
      } else {
        setState(() => _secondsUntilExpiry--);
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _showTopMessage(
    String message, {
    bool isError = true,
  }) {
    showTopToast(context, message, isError: isError);
  }

  Future<void> _verifyOtp() async {
    final otp = _otpController.text;

    if (otp.length < 6) {
      _showTopMessage('Please enter the complete 6 digit OTP');
      return;
    }

    if (_isExpired) {
      _showTopMessage(
        'This code has expired. Please resend a new one.',
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await ApiService.verifyOtp(
      username: widget.username,
      otp: otp,
    );

    setState(() => _isLoading = false);

    if (!context.mounted) return;

    if (result['success']) {
      setState(() => _isSigningIn = true);

      await AuthStorage.saveSession(
        accessToken: result['data']['access'] ?? '',
        refreshToken: result['data']['refresh'] ?? '',
        username: result['data']['user'] ?? '',
        fullName: result['data']['full_name'] ?? '',
        email: result['data']['email'] ?? '',
        phone: result['data']['phone'] ?? '',
      );

      // initialize() in main.dart runs before login, so it had no
      // access token to save the device token against yet — do it now
      // that AuthStorage actually has one.
      unawaited(NotificationService.syncTokenWithBackend());

      await Future.delayed(
        const Duration(milliseconds: 500),
      );

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoggedInDashboard(),
        ),
        (_) => false,
      );
    } else {
      _showTopMessage(
        result['error'] ?? 'Invalid OTP',
      );

      _otpController.clear();
      _otpFocusNode.requestFocus();
    }
  }

  Future<void> _resendOtp() async {
    // Only reachable once the current code has expired — the expiry
    // countdown itself is the cooldown, so no separate timer is needed
    // here.
    if (_isResending || !_isExpired) return;

    setState(() => _isResending = true);

    final result = await ApiService.requestOtp(
      identifier: widget.identifier,
      method: widget.method,
    );

    setState(() => _isResending = false);

    if (!context.mounted) return;

    if (result['success']) {
      setState(() {
        _deliveredVia = result['data']?['delivered_via'] ?? widget.method;
      });
      _showTopMessage(
        'A new code has been sent',
        isError: false,
      );

      _otpController.clear();
      _otpFocusNode.requestFocus();
      _startExpiryTimer();
    } else {
      _showTopMessage(
        result['error'] ?? 'Failed to resend code',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: _handleSwipe,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FB),
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
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
                      'VERIFICATION',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'Enter the 6 digit OTP sent to your '
                      '${_deliveredVia == 'email' ? 'email' : 'phone number'}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),

                    const SizedBox(height: 8),

                    GestureDetector(
                      onTap: (_isResending || !_isExpired)
                          ? null
                          : _resendOtp,
                      child: _isResending
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: primaryBlue,
                              ),
                            )
                          : Text(
                              _isExpired
                                  ? 'Resend Code'
                                  : 'Resend code in ${_formatTime(_secondsUntilExpiry)}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _isExpired
                                    ? primaryBlue
                                    : Colors.black45,
                                decoration: _isExpired
                                    ? TextDecoration.underline
                                    : TextDecoration.none,
                              ),
                            ),
                    ),

                    const SizedBox(height: 32),

                    _otpBoxes(),

                    const SizedBox(height: 40),

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
                        onPressed: _isLoading ? null : _verifyOtp,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'VERIFY CODE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (_isSigningIn)
              Positioned.fill(
                child: Container(
                  color: const Color(0xFFF8F9FB)
                      .withValues(alpha: 0.92),
                  child: const Center(
                    child: _BouncingDots(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _otpBoxes() {
    return Stack(
      children: [
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _otpController,
          builder: (_, value, _) {
            final digits = value.text;

            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (index) {
                final hasDigit = index < digits.length;
                final isActive = index == digits.length;

                return Container(
                  width: 48,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isActive
                          ? primaryBlue
                          : Colors.grey.shade300,
                      width: isActive ? 2 : 1,
                    ),
                  ),
                  child: hasDigit
                      ? Text(
                          digits[index],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : isActive
                          ? const _BlinkingCursor()
                          : null,
                );
              }),
            );
          },
        ),

        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _otpController,
              focusNode: _otpFocusNode,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              enabled: !_isExpired,
              showCursor: false,
              enableInteractiveSelection: false,
              inputFormatters: [
                _DigitsOnlyFormatter(
                  onInvalidChar: () =>
                      _showTopMessage('Only numbers are allowed'),
                ),
              ],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              onTap: () => _otpFocusNode.requestFocus(),
              onChanged: (value) {
                setState(() {});

                if (value.length == 6) {
                  FocusScope.of(context).unfocus();
                  _verifyOtp();
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _DigitsOnlyFormatter extends TextInputFormatter {
  final VoidCallback onInvalidChar;

  _DigitsOnlyFormatter({
    required this.onInvalidChar,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final filtered = newValue.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (filtered != newValue.text) {
      onInvalidChar();

      return TextEditingValue(
        text: filtered,
        selection: TextSelection.collapsed(
          offset: filtered.length,
        ),
      );
    }

    return newValue;
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() =>
      _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 26,
        color: _VerificationScreenState.primaryBlue,
      ),
    );
  }
}

class _BouncingDots extends StatefulWidget {
  const _BouncingDots();

  @override
  State<_BouncingDots> createState() =>
      _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final raw =
                (_controller.value - index * 0.2) % 1.0;

            final bounce = raw < 0 ? raw + 1 : raw;

            final offsetY = -8 *
                (bounce < 0.5
                    ? bounce * 2
                    : 1 - (bounce - 0.5) * 2);

            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 4),
              child: Transform.translate(
                offset: Offset(0, offsetY),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: _VerificationScreenState.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
