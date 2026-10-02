import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/api_service.dart';
import '../services/auth_storage.dart';

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Bumped every time a push arrives (foreground) or is tapped into
  // from the background/tray, regardless of what it's about. Screens
  // that need to stay live — Reports, News and Advisories — listen to
  // this and re-fetch their own data whenever it changes, instead of
  // the user having to pull-to-refresh after a status change or a new
  // article lands. Not scoped by push "type" on purpose: the backend
  // doesn't tag pushes with a category today, and refreshing a screen
  // that wasn't actually affected costs nothing but one extra fetch.
  static final ValueNotifier<int> refreshSignal = ValueNotifier<int>(0);

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _localNotificationsInitialized = false;

  // Sent as plain `data` (not a `notification` block) by the backend
  // specifically so Android doesn't auto-build the notification itself
  // (using its own default icon, no large icon) before this code runs
  // — see csa_shared_models/accounts/push.py. This is what lets every
  // CSA push show the real logo as a large icon with the small star
  // badge, instead of a generic system icon.
  static const String _channelId = 'csa_notifications';
  static const String _channelName = 'CSA Notifications';
  static const String _smallIconName = 'ic_notification';
  static const String _largeIconName = 'csa_logo_large';

  static Future<void> initialize() async {
    // ===== Request permission =====
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Notification permission granted');
    }

    // iOS only (no-op on Android): without this, iOS silently drops a
    // push that arrives while the app is open. The OS itself shows it
    // (see the `apns` block in the backend's push.py), so the app does
    // not build a second local notification for it on iOS.
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _ensureLocalNotificationsInitialized();

    // ===== Get FCM token =====
    // Only actually reaches the backend if the user is already logged
    // in at app startup (see _saveTokenToBackend) — for a fresh login
    // (first install, or logging back in after being signed out),
    // syncTokenWithBackend() below is called right after sign-in
    // succeeds instead.
    String? token = await _getFcmToken();
    if (token != null) {
      print('FCM Token: $token');
      await _saveTokenToBackend(token);
    }

    // ===== Refresh token listener =====
    _messaging.onTokenRefresh.listen((newToken) async {
      await _saveTokenToBackend(newToken);
    });

    // ===== Handle foreground notifications =====
    // The app is open and on-screen when this fires, so Android never
    // auto-displays anything regardless of payload shape — we always
    // have to build it ourselves here if we want the user to see it.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground notification: ${message.data['title']}');
      showCsaNotification(message);
      refreshSignal.value++;
    });

    // ===== Handle background notification tap =====
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Notification tapped: ${message.data['title']}');
      refreshSignal.value++;
    });
  }

  /// Idempotent — safe to call from both the main isolate (via
  /// initialize() above) and the background handler in main.dart,
  /// which runs in its own isolate and can't share the main isolate's
  /// initialization state.
  static Future<void> _ensureLocalNotificationsInitialized() async {
    if (_localNotificationsInitialized) return;

    const AndroidInitializationSettings androidInit =
        AndroidInitializationSettings(_smallIconName);
    // Required on iOS — the plugin throws at initialize() if it's
    // missing. Permission is already requested through Firebase above,
    // so it is deliberately not asked for a second time here.
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const InitializationSettings initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );
    await _localNotifications.initialize(settings: initSettings);
    _localNotificationsInitialized = true;
  }

  /// Builds and shows the actual system notification: the real CSA
  /// logo as the large (left-side, circular) icon, with the small
  /// star badge Android requires stamped in its corner. Used for both
  /// foreground messages (this file) and background/killed-app
  /// messages (main.dart's background handler) so every push looks
  /// the same regardless of app state.
  static Future<void> showCsaNotification(RemoteMessage message) async {
    // On iOS the OS displays the push itself (alert in the backend's
    // `apns` block); building one here too would show it twice.
    if (defaultTargetPlatform == TargetPlatform.iOS) return;

    await _ensureLocalNotificationsInitialized();

    final title = message.data['title'] ?? 'CSA Ghana';
    final body = message.data['body'] ?? '';

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Breaking news, alerts, and account updates from the CSA app.',
      icon: _smallIconName,
      largeIcon: DrawableResourceAndroidBitmap(_largeIconName),
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);

    // Unique-ish ID so each push gets its own entry in the tray
    // instead of replacing the previous one.
    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

    await _localNotifications.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  static Future<void> _saveTokenToBackend(String token) async {
    try {
      final accessToken = await AuthStorage.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        await ApiService.saveDeviceToken(
          accessToken: accessToken,
          token: token,
        );
        print('Device token saved to backend');
      }
    } catch (e) {
      print('Error saving token: $e');
    }
  }

  /// On iOS the FCM token only exists once Apple has handed the app its
  /// APNs token, which can take a moment after launch — asking for it
  /// too early throws. [waitForApns] polls briefly for it; startup
  /// passes false so launching never stalls, and relies on
  /// onTokenRefresh (above) to deliver the token when it appears.
  static Future<String?> _getFcmToken({bool waitForApns = false}) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS && waitForApns) {
        for (var i = 0; i < 5; i++) {
          if (await _messaging.getAPNSToken() != null) break;
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      return await _messaging.getToken();
    } catch (e) {
      print('Could not get FCM token yet: $e');
      return null;
    }
  }

  static Future<String?> getToken() async {
    return await _getFcmToken(waitForApns: true);
  }

  /// Call this right after a successful login/registration (once
  /// AuthStorage has the new access token saved). initialize() in
  /// main.dart runs once at app startup, before the user has
  /// necessarily signed in yet, so its token save is a no-op for
  /// anyone logging in for the first time on a fresh install — this
  /// re-sends the already-fetched device token now that there's an
  /// access token to save it against, without re-requesting
  /// permission or re-registering the listeners set up in initialize().
  static Future<void> syncTokenWithBackend() async {
    final token = await _getFcmToken(waitForApns: true);
    if (token != null) {
      await _saveTokenToBackend(token);
    }
  }
}
