"""Shared FCM push-sending helpers, used by both csa_mobile_api and
csa_admin_api (via the `incidents` pre_save signal, and the admin-side
content/certificate triggers). Single source of truth for how a push
gets sent — see incidents/signals.py for the original mechanism this
was extracted from.

Uses the FCM HTTP v1 API directly (OAuth2 service-account credentials +
a plain HTTP POST), not the firebase-admin SDK — that SDK isn't a
project dependency, and introducing it here would be a second, parallel
way of sending pushes for no real benefit.
"""

import google.auth.transport.requests
import google.oauth2.service_account
import requests as http_requests
from django.conf import settings

from .models import DeviceToken

FCM_PROJECT_ID = 'ascmob-app'
FCM_SCOPES = ['https://www.googleapis.com/auth/firebase.messaging']


def _get_access_token():
    credentials = google.oauth2.service_account.Credentials.from_service_account_file(
        settings.FIREBASE_SERVICE_ACCOUNT_FILE,
        scopes=FCM_SCOPES,
    )
    request = google.auth.transport.requests.Request()
    credentials.refresh(request)
    return credentials.token


def send_push_to_token(token, title, body, access_token=None):
    """Sends one push to one device token. Never raises — a failed
    send (invalid/expired token, Firebase error, missing credentials
    file) must never break whatever admin action triggered it."""
    try:
        if access_token is None:
            access_token = _get_access_token()

        url = f'https://fcm.googleapis.com/v1/projects/{FCM_PROJECT_ID}/messages:send'
        headers = {
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json',
        }
        # data-only, not `notification` — a `notification` block makes
        # Android auto-build and display the system notification itself
        # (using its own default icon, no large icon), before the app's
        # own code ever runs. Sending plain data instead means the app
        # is the one deciding how to render it, via
        # NotificationService.showCsaNotification on the Flutter side,
        # which is what lets us set the real CSA logo as the large icon
        # and the star as the small icon. `data` values must all be
        # strings, which title/body already are.
        # The `apns` block is read only by iPhones and ignored by
        # Android. iOS can't build its own notification from a data-only
        # push the way the Android code does (it isn't allowed to run
        # when the app is in the background or closed), so on iOS the
        # alert has to come from this block and Apple displays it.
        payload = {
            'message': {
                'token': token,
                'data': {
                    'title': title,
                    'body': body,
                },
                'apns': {
                    'payload': {
                        'aps': {
                            'alert': {'title': title, 'body': body},
                            'sound': 'default',
                        },
                    },
                },
            }
        }

        response = http_requests.post(url, json=payload, headers=headers, timeout=10)
        print(f'FCM response: {response.status_code} {response.text}')
        return response.status_code == 200

    except Exception as e:
        print(f'Push notification error: {e}')
        return False


def send_push_to_user(user, title, body):
    """Personal push to one user's saved device, if any. Returns False
    (and logs) rather than raising when there's no device token on
    file — a missing token is an expected, non-error condition."""
    if not user:
        print('send_push_to_user called with no user')
        return False

    device = DeviceToken.objects.filter(user=user).first()
    if not device:
        print(f'No device token found for user {user.username}')
        return False

    print(f'Sending notification to token: {device.token[:20]}...')
    return send_push_to_token(device.token, title, body)


def send_push_broadcast(title, body):
    """Sends to every saved device token — used for breaking news /
    alert publishing, which is the only broadcast case in this app.

    The FCM HTTP v1 `messages:send` endpoint takes exactly one target
    (token, topic, or condition) per call — there's no server-side
    multicast in this API (that was a legacy-FCM-API feature, now
    deprecated). So this fetches one OAuth access token and reuses it
    across individual sends, rather than re-authenticating per
    recipient. One bad/expired token is caught and logged without
    stopping the rest of the batch.
    """
    tokens = list(
        DeviceToken.objects.exclude(token='').values_list('token', flat=True)
    )
    if not tokens:
        print('No device tokens registered — nothing to broadcast to.')
        return {'sent': 0, 'failed': 0, 'total': 0}

    try:
        access_token = _get_access_token()
    except Exception as e:
        print(f'Push broadcast error (could not get access token): {e}')
        return {'sent': 0, 'failed': len(tokens), 'total': len(tokens)}

    sent = 0
    failed = 0
    for token in tokens:
        if send_push_to_token(token, title, body, access_token=access_token):
            sent += 1
        else:
            failed += 1

    print(f'Broadcast complete: {sent} sent, {failed} failed, {len(tokens)} total')
    return {'sent': sent, 'failed': failed, 'total': len(tokens)}
