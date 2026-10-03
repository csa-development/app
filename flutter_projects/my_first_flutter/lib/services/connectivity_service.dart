import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the phone has any network at all (Wi-Fi, mobile data,
/// ethernet or VPN). This can't prove the internet itself works — a
/// Wi-Fi network with no data behind it still counts as "connected" —
/// so it is only used to tell "you're offline" apart from "we couldn't
/// reach CSA", not to predict whether a request will succeed.
class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();
  static StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// True while the phone has no network. Drives the app-wide offline strip.
  static final ValueNotifier<bool> isOffline = ValueNotifier<bool>(false);

  static bool _hasNoNetwork(List<ConnectivityResult> results) =>
      results.isEmpty || results.every((r) => r == ConnectivityResult.none);

  static Future<void> initialize() async {
    await checkOffline();
    _subscription ??= _connectivity.onConnectivityChanged.listen((results) {
      isOffline.value = _hasNoNetwork(results);
    });
  }

  /// Re-checks right now and updates [isOffline]. Falls back to "online"
  /// if the platform can't answer, so a plugin hiccup never shows a false
  /// offline warning.
  static Future<bool> checkOffline() async {
    try {
      final offline = _hasNoNetwork(await _connectivity.checkConnectivity());
      isOffline.value = offline;
      return offline;
    } catch (_) {
      return false;
    }
  }
}
