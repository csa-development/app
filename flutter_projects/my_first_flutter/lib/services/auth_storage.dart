import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthStorage {
  // JWTs live in the OS keystore, not shared_preferences. Everything
  // else (display name, onboarding flag, profile image path) stays in
  // prefs — none of it is a credential.
  static const FlutterSecureStorage _secure = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  // Home, Profile, and Edit Profile each show the same avatar but
  // live in separate States (Home/Profile stay mounted side-by-side
  // in the bottom nav's IndexedStack, so one screen's setState never
  // reaches the other). Listening to this instead of local state
  // means whichever screen changes the picture, every other mounted
  // screen showing it updates immediately.
  static final ValueNotifier<String?> profileImageNotifier =
      ValueNotifier<String?>(null);

  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _usernameKey = 'username';
  static const String _fullNameKey = 'full_name';
  static const String _emailKey = 'email';
  static const String _phoneKey = 'phone';
  static const String _profileImageKey = 'profile_image_path';
  static const String _hasSeenOnboardingKey = 'has_seen_onboarding';

  static Future<void> saveSession({
    required String accessToken,
    String? refreshToken,
    required String username,
    required String fullName,
    required String email,
    String phone = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await _secure.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secure.write(key: _refreshTokenKey, value: refreshToken);
    }
    await prefs.setString(_usernameKey, username);
    await prefs.setString(_fullNameKey, fullName);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_phoneKey, phone);
  }

  static Future<String?> getAccessToken() async {
    return _secure.read(key: _accessTokenKey);
  }

  static Future<String?> getRefreshToken() async {
    return _secure.read(key: _refreshTokenKey);
  }

  /// Overwrites just the access token, e.g. after a successful token
  /// refresh. Everything else in the session stays the same.
  static Future<void> updateAccessToken(String accessToken) async {
    await _secure.write(key: _accessTokenKey, value: accessToken);
  }

  /// Saves a rotated token pair. The server issues a NEW refresh token on
  /// every refresh and invalidates the old one, so the new one must be
  /// stored or the next refresh would be rejected and log the user out.
  static Future<void> updateTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _secure.write(key: _accessTokenKey, value: accessToken);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _secure.write(key: _refreshTokenKey, value: refreshToken);
    }
  }

  static Future<String?> getUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_usernameKey);
  }

  static Future<String?> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fullNameKey);
  }


  static Future<String?> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey);
  }

  static Future<String?> getPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  static Future<bool> isLoggedIn() async {
    final token = await _secure.read(key: _accessTokenKey);
    return token != null && token.isNotEmpty;
  }

  // Scoped per-username (not a single global key) so that if a
  // different account ever logs in on the same device, they don't
  // inherit the previous account's cached photo — each account's
  // picture is kept separately and survives that account's own
  // logout/login cycles.
  static Future<String> _profileImageKeyForCurrentUser(
    SharedPreferences prefs,
  ) async {
    final username = prefs.getString(_usernameKey);
    return (username != null && username.isNotEmpty)
        ? '${_profileImageKey}_$username'
        : _profileImageKey;
  }

  static Future<void> saveProfileImage(String path) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _profileImageKeyForCurrentUser(prefs);
    await prefs.setString(key, path);
    profileImageNotifier.value = path;
  }

  static Future<String?> getProfileImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _profileImageKeyForCurrentUser(prefs);
    final path = prefs.getString(key);
    profileImageNotifier.value = path;
    return path;
  }

  /// Clears only the session-related keys. Deliberately NOT
  /// `prefs.clear()` — that would also wipe `has_seen_onboarding`,
  /// making the onboarding intro reappear after every logout instead
  /// of staying gone for good after the very first launch.
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await _secure.delete(key: _accessTokenKey);
    await _secure.delete(key: _refreshTokenKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_fullNameKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_phoneKey);
    // Deliberately NOT removing the profile image here — it's saved
    // under a per-username key (see _profileImageKeyForCurrentUser),
    // so it isn't tied to this session and should survive logging out
    // and back in as the same account. Only reset the in-memory
    // notifier, so nothing stale flashes before the next login loads
    // whichever account's own picture applies.
    profileImageNotifier.value = null;
  }

  static Future<bool> hasSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasSeenOnboardingKey) ?? false;
  }

  static Future<void> setSeenOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasSeenOnboardingKey, true);
  }
}