import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../screens/loggedin_user_pages/campaign_details.dart';
import '../screens/loggedin_user_pages/event_detail.dart';
import '../screens/loggedin_user_pages/news_detail.dart';
import '../screens/loggedin_user_pages/press_release_detail.dart';
import 'api_service.dart';

/// Handles a link like https://csa.gov.gh/news/482/ being opened while
/// this app is installed (Android App Link / iOS Universal Link), by
/// pushing straight to that article/event/campaign's detail page.
///
/// This ONLY fires when the OS actually hands the link to the app —
/// that requires csa.gov.gh to serve /.well-known/assetlinks.json (see
/// csa_mobile_api's content/public_views.py) and the app to be signed
/// with the matching key. Until that's live, tapping a shared link just
/// opens the plain web fallback page instead, which is expected.
class DeepLinkService {
  static final AppLinks _appLinks = AppLinks();

  static Future<void> initialize() async {
    // Cold start: the app was opened *by* tapping a link. The splash
    // screen still needs its ~1.2s minimum to decide whether to land on the
    // dashboard or the login flow first — this waits for that to settle
    // so the deep-linked page pushes on top of the right home screen,
    // not whatever's still on screen mid-splash.
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      Future.delayed(const Duration(milliseconds: 2000), () {
        _handleUri(initialUri);
      });
    }

    // Warm/background: app already running, link tapped while it's
    // open in the background. The navigator is already live, so this
    // handles it immediately.
    _appLinks.uriLinkStream.listen(_handleUri);
  }

  static Future<void> _handleUri(Uri uri) async {
    final segments = uri.pathSegments;
    if (segments.length < 2) return;

    final type = segments[0];
    final id = int.tryParse(segments[1]);
    if (id == null) return;

    final context = navigatorKey.currentContext;
    if (context == null) return;

    switch (type) {
      case 'news':
        final result = await ApiService.getNewsDetail(newsId: id);
        if (result['success'] == true && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NewsDetailPage(
                article: result['data']['article'],
              ),
            ),
          );
        }
        break;

      case 'events':
        final result = await ApiService.getEventDetail(eventId: id);
        if (result['success'] == true && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventDetailPage(
                event: result['data']['event'],
              ),
            ),
          );
        }
        break;

      case 'campaigns':
        final result = await ApiService.getCampaignDetail(campaignId: id);
        if (result['success'] == true && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CampaignDetailPage(
                campaign: result['data']['campaign'],
              ),
            ),
          );
        }
        break;

      case 'press':
        final result = await ApiService.getPressReleaseDetail(releaseId: id);
        if (result['success'] == true && context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PressReleaseDetailPage(
                pressRelease: result['data']['press_release'],
              ),
            ),
          );
        }
        break;

      default:
        debugPrint('DeepLinkService: unrecognized link path "$uri"');
    }
  }
}
