import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:http/http.dart' as http;

import 'auth_storage.dart';
import 'connectivity_service.dart';

class ApiService {
  // Every request in this file uses this same timeout. A dead/very
  // poor connection previously hung indefinitely instead of failing
  // with a clear message.
  static const Duration _timeout = Duration(seconds: 15);
  static const Duration _uploadTimeout = Duration(minutes: 5);

  // What a citizen sees when a request itself fails (as opposed to the
  // server answering with its own message, e.g. "Invalid or expired
  // code", which is always passed through untouched). `kind` lets a
  // screen tell the cases apart without parsing the text.
  static const Map<String, dynamic> _offlineError = {
    'success': false,
    'kind': 'offline',
    'error':
        'No internet connection. Check your Wi-Fi or mobile data and try again.',
  };

  static const Map<String, dynamic> _timeoutError = {
    'success': false,
    'kind': 'timeout',
    'error':
        'This is taking longer than expected. Check your connection and try again.',
  };

  static const Map<String, dynamic> _serverError = {
    'success': false,
    'kind': 'server',
    'error':
        "We're having trouble reaching CSA right now. Please try again in a few minutes.",
  };

  static const Map<String, dynamic> _unknownError = {
    'success': false,
    'kind': 'unknown',
    'error': 'Something went wrong. Please try again.',
  };

  static bool _isNetworkError(Object error) =>
      error is SocketException ||
      error is http.ClientException ||
      error is TlsException;

  /// Maps an exception thrown by a request to the message shown to the
  /// user. A network-level failure is "offline" only if the phone really
  /// has no network; otherwise the problem is on CSA's side. An unreadable
  /// reply (e.g. an HTML error page from a proxy) is also CSA's side. A
  /// timeout is handled separately by the callers.
  @visibleForTesting
  static Map<String, dynamic> failureFor(
    Object error, {
    required bool offline,
  }) {
    if (_isNetworkError(error)) return offline ? _offlineError : _serverError;
    if (error is FormatException) return _serverError;
    return _unknownError;
  }

  static Future<Map<String, dynamic>> _failure(Object error) async {
    final offline = _isNetworkError(error) && await ConnectivityService.checkOffline();
    return failureFor(error, offline: offline);
  }

  // ===== NETWORK TARGET TOGGLE =====
  // Set this to true when testing on a REAL PHONE (e.g. installing the
  // APK for UAT) — uses the PC's local network/hotspot IP.
  // Set this to false when testing on the ANDROID EMULATOR — uses the
  // emulator's special loopback address to reach your PC's localhost.
  //
  // Just flip this one flag instead of hunting for the URL each time.
  static const bool _useRealDevice = true;

  // Update this if your PC's hotspot/network IP changes (check with
  // `ipconfig` on Windows or `ifconfig`/System Settings on Mac). Was
  // 172.20.10.4 (a stale hotspot address, no longer active) — this
  // machine's real current WiFi IP is 192.168.31.58, which already
  // matches csa_mobile_api/.env's ALLOWED_HOSTS entry for it.
  static const String _realDeviceIp = '192.168.31.58';

  // Points only at csa_mobile_api (citizen-facing process), never at
  // csa_admin_api. Port 8000 is unchanged from before the mobile/admin
  // split — csa_mobile_api kept the original port, csa_admin_api runs
  // separately on 8001. Every path this file calls (register/,
  // request-otp/, content/*, incidents/submit/, etc.) is a citizen
  // route that only exists on csa_mobile_api.
  // In a browser (flutter run -d chrome) the server is simply this PC's
  // localhost — the phone/emulator addresses above don't apply.
  static const String baseUrl = kIsWeb
      ? 'https://localhost:8000/api'
      : (_useRealDevice
          ? 'https://$_realDeviceIp:8000/api'
          : 'https://10.0.2.2:8000/api');

  // Domain for links put in shared text (WhatsApp, SMS, etc.) — separate
  // from baseUrl above, which is this PC's LAN address and would be
  // meaningless to anyone else. These links only work as real App
  // Links/Universal Links once csa.gov.gh is actually pointed at wherever
  // csa_mobile_api is deployed, and the app is signed with a key that
  // matches /.well-known/assetlinks.json served there (see
  // content/public_views.py in csa_mobile_api for that file).
  static const String publicWebBaseUrl = 'https://csa.gov.gh';

  // ===== AUTH-AWARE REQUEST WRAPPER =====

  /// Sends an authenticated request, and if it comes back 401 (expired
  /// access token), silently uses the stored refresh token to get a new
  /// access token, saves it, and retries the request ONCE with the new
  /// token. If the refresh itself fails (refresh token also expired or
  /// missing), the original 401 response is returned as-is, and the
  /// calling screen's normal error handling takes over (the same as
  /// before this existed — nothing breaks if refresh isn't possible).
  ///
  /// [requestBuilder] takes the access token to use and returns the
  /// http.Response for that attempt. Pass the token given to your public
  /// method initially — this wrapper handles getting a fresh one if
  /// needed and retrying with it.
  static Future<http.Response> _sendWithAutoRefresh(
    String initialToken,
    Future<http.Response> Function(String token) requestBuilder,
  ) async {
    http.Response response =
        await requestBuilder(initialToken).timeout(_timeout);

    if (response.statusCode == 401) {
      final newAccessToken = await _refreshSession();
      if (newAccessToken != null) {
        response = await requestBuilder(newAccessToken).timeout(_timeout);
      }
    }

    return response;
  }

  // The server rotates refresh tokens: each refresh returns a NEW one and
  // invalidates the old. Several requests hitting 401 at the same moment
  // (a screen loading news + alerts + events) must therefore share ONE
  // refresh call - a second call with the already-used token would be
  // rejected and look like an expired session.
  static Future<String?>? _refreshInFlight;

  static Future<String?> _refreshSession() {
    return _refreshInFlight ??= _doRefreshSession().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  static Future<String?> _doRefreshSession() async {
    final refreshToken = await AuthStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    final result = await refreshAccessToken(refreshToken: refreshToken);
    if (result['success'] != true) return null;

    final access = result['access'] as String;
    // `refresh` is only present when the server rotates tokens.
    await AuthStorage.updateTokens(
      accessToken: access,
      refreshToken: result['refresh'] as String?,
    );
    return access;
  }

  // ===== AUTH =====

  // NOTE: nationalId removed — it's no longer collected on the
  // Flutter registration screens. Your Django accounts/views.py
  // register_user still expects `national_id` in the POST body
  // (and uses it as the account's username), so this endpoint will
  // reject requests from this app until that view is updated too.
  static Future<Map<String, dynamic>> register({
    required String fullName,
    required String email,
    required String phone,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': fullName,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Registration failed',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> requestOtp({
    required String identifier,
    required String method,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/request-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identifier': identifier, 'method': method}),
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to send OTP',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> verifyOtp({
    required String username,
    required String otp,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'otp': otp}),
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'OTP verification failed',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  // ===== PROFILE =====

  static Future<Map<String, dynamic>> updateProfile({
    required String accessToken,
    required String fullName,
    required String email,
    required String phone,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.put(
          Uri.parse('$baseUrl/profile/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'first_name': fullName.split(' ').first,
            'last_name': fullName.split(' ').length > 1
                ? fullName.split(' ').sublist(1).join(' ')
                : '',
            'email': email,
            'phone': phone,
          }),
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to update profile',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  // Step 1 of changing your phone number: sends a verification code
  // to the NEW number. Nothing is saved to the profile yet.
  static Future<Map<String, dynamic>> requestPhoneChange({
    required String accessToken,
    required String phone,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.post(
          Uri.parse('$baseUrl/profile/request-phone-change/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'phone': phone}),
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to send verification code',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  // Step 2: verify the code sent to the new number — only then is it
  // actually saved to the profile.
  static Future<Map<String, dynamic>> confirmPhoneChange({
    required String accessToken,
    required String code,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.post(
          Uri.parse('$baseUrl/profile/confirm-phone-change/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({'code': code}),
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Invalid or expired code',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> changePassword({
    required String accessToken,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.post(
          Uri.parse('$baseUrl/change-password/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'current_password': currentPassword,
            'new_password': newPassword,
            'confirm_password': confirmPassword,
          }),
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // The server just revoked every other session for this account and
        // returned a fresh token pair for this device - keep it, or the next
        // refresh would fail and log the user out.
        final newAccess = data['access'];
        if (newAccess is String && newAccess.isNotEmpty) {
          await AuthStorage.updateTokens(
            accessToken: newAccess,
            refreshToken: data['refresh'] as String?,
          );
        }
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to change password',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> saveDeviceToken({
    required String accessToken,
    required String token,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (accToken) {
        return http.post(
          Uri.parse('$baseUrl/save-device-token/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accToken',
          },
          body: jsonEncode({'token': token}),
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to save token',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> sendFeedback({
    required String accessToken,
    required String category,
    required String message,
    int? rating,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.post(
          Uri.parse('$baseUrl/feedback/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'category': category,
            'message': message,
            if (rating != null) 'rating': rating,
          }),
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to send feedback',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> sendContactMessage({
    required String name,
    required String phone,
    required String email,
    required String message,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/contact/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'phone': phone,
          'email': email,
          'message': message,
        }),
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to send message',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  // ===== INCIDENTS =====

  static Future<Map<String, dynamic>> submitReport({
    required String accessToken,
    required String incidentType,
    required String platform,
    required String description,
    required String dateOfIncident,
    required String location,
    required String reporterName,
    required String reporterPhone,
    required bool reportingForSomeone,
    String relationshipToVictim = '',
    String evidenceDescription = '',
    double? latitude,
    double? longitude,
    // The actual picked photo/video, if any. Previously only the
    // file's *name* was ever sent (as evidenceDescription) — the file
    // itself never left the phone, so CERT had no way to see it. When
    // this is set, the request goes as multipart/form-data instead of
    // plain JSON so the file bytes actually get uploaded.
    File? evidenceFile,
    // Browser builds can't read a file from disk, so the file's bytes
    // (and name) are passed instead. Phones keep using evidenceFile.
    Uint8List? evidenceBytes,
    String evidenceFilename = 'evidence',
  }) async {
    final fields = {
      'incident_type': incidentType,
      'platform': platform,
      'description': description,
      'date_of_incident': dateOfIncident,
      'location': location,
      'reporter_name': reporterName,
      'reporter_phone': reporterPhone,
      'reporting_for_someone': reportingForSomeone.toString(),
      'relationship_to_victim': relationshipToVictim,
      'evidence_description': evidenceDescription,
      if (latitude != null) 'latitude': latitude.toString(),
      if (longitude != null) 'longitude': longitude.toString(),
    };

    try {
      final http.Response response;
      if (evidenceFile != null || evidenceBytes != null) {
        response = await _sendMultipartWithAutoRefresh(
          accessToken,
          (token) async {
            final request = http.MultipartRequest(
              'POST',
              Uri.parse('$baseUrl/incidents/submit/'),
            );
            request.headers['Authorization'] = 'Bearer $token';
            request.fields.addAll(fields);
            request.files.add(
              evidenceBytes != null
                  ? http.MultipartFile.fromBytes(
                      'evidence_file',
                      evidenceBytes,
                      filename: evidenceFilename,
                    )
                  : await http.MultipartFile.fromPath(
                      'evidence_file',
                      evidenceFile!.path,
                    ),
            );
            // Far longer than the 15s every other call gets: this has
            // to cover pushing the whole file up (a video can be tens
            // of MB on mobile data) before the server answers at all.
            final streamed = await request.send().timeout(_uploadTimeout);
            return http.Response.fromStream(streamed);
          },
        );
      } else {
        response = await _sendWithAutoRefresh(accessToken, (token) {
          return http.post(
            Uri.parse('$baseUrl/incidents/submit/'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'incident_type': incidentType,
              'platform': platform,
              'description': description,
              'date_of_incident': dateOfIncident,
              'location': location,
              'reporter_name': reporterName,
              'reporter_phone': reporterPhone,
              'reporting_for_someone': reportingForSomeone,
              'relationship_to_victim': relationshipToVictim,
              'evidence_description': evidenceDescription,
              if (latitude != null) 'latitude': latitude,
              if (longitude != null) 'longitude': longitude,
            }),
          );
        });
      }
      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Submission failed',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  /// Same auto-refresh-on-401 behaviour as _sendWithAutoRefresh, but for
  /// a multipart request builder — MultipartRequest can only be sent
  /// (and its file stream read) once, so a fresh one has to be built
  /// per attempt rather than reusing the same request object.
  static Future<http.Response> _sendMultipartWithAutoRefresh(
    String initialToken,
    Future<http.Response> Function(String token) requestBuilder,
  ) async {
    http.Response response = await requestBuilder(initialToken);

    if (response.statusCode == 401) {
      final newAccessToken = await _refreshSession();
      if (newAccessToken != null) {
        response = await requestBuilder(newAccessToken);
      }
    }

    return response;
  }

  static Future<Map<String, dynamic>> getMyReports({
    required String accessToken,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.get(
          Uri.parse('$baseUrl/incidents/my-reports/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load reports',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  // Position-ordered list of report statuses (Pending, Under Review,
  // Resolved, plus anything CERT has added since the app was last
  // updated) — lets the reports screens render whatever's actually
  // configured instead of a hardcoded 3-status list baked into the app.
  static Future<Map<String, dynamic>> getIncidentStatuses({
    required String accessToken,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.get(
          Uri.parse('$baseUrl/incidents/statuses/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load statuses',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> verifyCertificate({
    required String certificateNumber,
    required String certificateType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/incidents/verify-certificate/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'certificate_number': certificateNumber,
          'certificate_type': certificateType,
        }),
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Verification failed',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  // ===== NEWS =====

  static Future<Map<String, dynamic>> getNews({
    int page = 1,
    int pageSize = 10,
    String? category,
  }) async {
    try {
      String url =
          '$baseUrl/content/news/?page=$page&page_size=$pageSize';
      if (category != null && category.isNotEmpty) {
        url += '&category=$category';
      }
      final response = await http
          .get(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': 'Failed to load news'};
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> getNewsDetail({
    required int newsId,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/content/news/$newsId/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load article',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> getAlerts() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/content/alerts/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': 'Failed to load alerts'};
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> getBreakingNews() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/content/breaking-news/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': 'Failed to load breaking news',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  // ===== EVENTS AND CAMPAIGNS =====

  static Future<Map<String, dynamic>> getEvents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/content/events/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': 'Failed to load events'};
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> getEventDetail({
    required int eventId,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/content/events/$eventId/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load event',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> getCampaigns() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/content/campaigns/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': 'Failed to load campaigns'};
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> getCampaignDetail({
    required int campaignId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/content/campaigns/$campaignId/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load campaign details',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> getPressReleases() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/content/press-releases/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': 'Failed to load press releases',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> getPressReleaseDetail({
    required int releaseId,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/content/press-releases/$releaseId/'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load press release',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> getAboutPage() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/content/about/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': 'Failed to load page content'};
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> getContactPage() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/content/contact/'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {'success': false, 'error': 'Failed to load page content'};
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  // ===== EVENT REGISTRATION =====

  static Future<Map<String, dynamic>> registerEventInterest({
    required String accessToken,
    required int eventId,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.post(
          Uri.parse('$baseUrl/content/events/$eventId/register/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to register interest',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> unregisterEventInterest({
    required String accessToken,
    required int eventId,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.delete(
          Uri.parse('$baseUrl/content/events/$eventId/unregister/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to unregister',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> checkEventRegistration({
    required String accessToken,
    required int eventId,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.get(
          Uri.parse(
              '$baseUrl/content/events/$eventId/check-registration/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to check registration',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  // NOTE: backend endpoint '/content/events/my-registrations/' does not
  // exist yet — needs to be added to content/views.py + urls.py.
  // Expected response shape:
  // { "registrations": [
  //     { "event_id": 4, "event_title": "...", "event_date": "2026-08-01",
  //       "check_in_code": "CSA-4829", "checked_in": false }
  // ] }
  static Future<Map<String, dynamic>> getMyEventRegistrations({
    required String accessToken,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.get(
          Uri.parse('$baseUrl/content/events/my-registrations/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to load your event registrations',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> registerCampaignInterest({
    required String accessToken,
    required int campaignId,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.post(
          Uri.parse('$baseUrl/content/campaigns/$campaignId/register/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to register interest',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> unregisterCampaignInterest({
    required String accessToken,
    required int campaignId,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.delete(
          Uri.parse('$baseUrl/content/campaigns/$campaignId/unregister/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to unregister',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> checkCampaignRegistration({
    required String accessToken,
    required int campaignId,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.get(
          Uri.parse(
              '$baseUrl/content/campaigns/$campaignId/check-registration/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Failed to check registration',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  static Future<Map<String, dynamic>> getMyCampaignRegistrations({
    required String accessToken,
  }) async {
    try {
      final response = await _sendWithAutoRefresh(accessToken, (token) {
        return http.get(
          Uri.parse('$baseUrl/content/campaigns/my-registrations/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );
      });
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'data': data};
      } else {
        return {
          'success': false,
          'error':
              data['error'] ?? 'Failed to load your campaign registrations',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }

  // ===== LOGOUT =====

  /// Tells the server to kill this device's refresh token, so a copy of it
  /// (stolen phone, backup, intercepted request) stops working. Best-effort:
  /// being offline or the server being down must never stop the user from
  /// logging out locally, so errors are swallowed and the wait is short.
  static Future<void> logout() async {
    final refreshToken = await AuthStorage.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return;
    try {
      await http
          .post(
            Uri.parse('$baseUrl/logout/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refreshToken}),
          )
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      // Ignored on purpose - see above.
    }
  }

  // ===== TOKEN REFRESH =====

  /// Exchanges a still-valid refresh token for a brand new access token.
  /// Call this when a request comes back 401 — if this succeeds, retry
  /// the original request with the new access token. If it fails, the
  /// refresh token itself has expired (or is missing) and the user needs
  /// to log in again.
  static Future<Map<String, dynamic>> refreshAccessToken({
    required String refreshToken,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/token/refresh/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh': refreshToken}),
      ).timeout(_timeout);
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'access': data['access'],
          'refresh': data['refresh'],
        };
      } else {
        return {
          'success': false,
          'error': data['detail'] ?? 'Session expired, please log in again',
        };
      }
    } on TimeoutException {
      return _timeoutError;
    } catch (e) {
      return _failure(e);
    }
  }
}