import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart'; // provides `navigatorKey`
import '../screens/continue_login_flow.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import 'top_toast.dart';

// ============================================================
// DORMANCY / IDLE LOGOUT
//
// Wraps the whole app (see main.dart's MaterialApp.builder) so it sees
// every tap/drag anywhere in the app without every screen needing to
// know about it. If a logged-in user leaves the app untouched — either
// sitting on a screen doing nothing, or backgrounded — for
// `_kickoutDuration`, the session is cleared and they're dropped back
// on the Continue page, same as tapping LOGOUT manually.
//
// Guests (no active session) are left alone — there's nothing to log
// them out of.
// ============================================================

class InactivityWatcher extends StatefulWidget {
  final Widget child;

  const InactivityWatcher({super.key, required this.child});

  @override
  State<InactivityWatcher> createState() => _InactivityWatcherState();
}

class _InactivityWatcherState extends State<InactivityWatcher>
    with WidgetsBindingObserver {
  static const Duration _kickoutDuration = Duration(minutes: 5);

  Timer? _idleTimer;
  DateTime? _pausedAt;
  bool _isHandlingTimeout = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[InactivityWatcher] initState — starting timer');
    _resetTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _idleTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('[InactivityWatcher] lifecycle state -> $state');
    if (state == AppLifecycleState.paused) {
      // Dart timers aren't reliable while the app is suspended in the
      // background, so track the actual wall-clock time instead and
      // check the real gap when the app comes back.
      _pausedAt = DateTime.now();
      _idleTimer?.cancel();
    } else if (state == AppLifecycleState.resumed) {
      final pausedAt = _pausedAt;
      _pausedAt = null;

      if (pausedAt != null &&
          DateTime.now().difference(pausedAt) >= _kickoutDuration) {
        debugPrint('[InactivityWatcher] resumed after >= kickout duration '
            '(paused at $pausedAt) — timing out now');
        _handleTimeout();
      } else {
        debugPrint('[InactivityWatcher] resumed (paused at $pausedAt) — '
            'restarting timer');
        _resetTimer();
      }
    }
  }

  void _resetTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_kickoutDuration, () {
      debugPrint('[InactivityWatcher] ${_kickoutDuration.inMinutes}min '
          'timer fired at ${DateTime.now()}');
      _handleTimeout();
    });
  }

  Future<void> _handleTimeout() async {
    if (_isHandlingTimeout) {
      debugPrint('[InactivityWatcher] _handleTimeout re-entered, ignoring');
      return;
    }

    final accessToken = await AuthStorage.getAccessToken();
    debugPrint('[InactivityWatcher] accessToken present: '
        '${accessToken != null}');
    if (accessToken == null) {
      // Nobody's logged in — nothing to kick out. Just keep watching.
      _resetTimer();
      return;
    }

    _isHandlingTimeout = true;
    debugPrint('[InactivityWatcher] logging out due to inactivity now');

    await ApiService.logout();
    await AuthStorage.clearSession();

    final navContext = navigatorKey.currentContext;
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ContinueLoginFlow()),
      (route) => false,
    );

    if (navContext != null && navContext.mounted) {
      showTopToast(
        navContext,
        "You've been logged out due to inactivity",
        isError: false,
        backgroundColor: Colors.black54,
        icon: Icons.timer_outlined,
      );
    }

    _isHandlingTimeout = false;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        debugPrint('[InactivityWatcher] pointer down — resetting timer');
        _resetTimer();
      },
      onPointerSignal: (_) {
        debugPrint('[InactivityWatcher] pointer signal — resetting timer');
        _resetTimer();
      },
      child: widget.child,
    );
  }
}
