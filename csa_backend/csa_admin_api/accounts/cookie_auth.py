"""Staff (CERT / LECO / COMMS / IT / SUPERADMIN) login for the admin web app.

The login tokens live in HttpOnly cookies, so JavaScript running on the
page — including anything an attacker manages to inject — can never read
them. That replaces keeping the token in localStorage, where a single
script-injection bug would hand over a staff account.

Cookies are sent automatically by the browser, so state-changing requests
must also carry the custom header below. A website on another origin
cannot add a custom header without a CORS preflight, and this API allows
no cross-origin requests — together with SameSite=Strict that closes the
cross-site request forgery door.
"""

from django.conf import settings
from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.decorators import (
    api_view, authentication_classes, permission_classes,
)
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.serializers import TokenRefreshSerializer
from rest_framework_simplejwt.tokens import RefreshToken

from .cookie_authentication import (
    ACCESS_COOKIE, REFRESH_COOKIE, has_request_header,
)

# The refresh cookie is only ever sent to the auth endpoints, never to the
# rest of the API.
ACCESS_COOKIE_PATH = '/api/'
REFRESH_COOKIE_PATH = '/api/admin/'


def _cookie_options():
    return {
        'httponly': True,
        'secure': not settings.DEBUG,
        'samesite': 'Strict',
    }


def set_auth_cookies(response, access=None, refresh=None):
    lifetimes = settings.SIMPLE_JWT
    if access:
        response.set_cookie(
            ACCESS_COOKIE, access,
            max_age=int(lifetimes['ACCESS_TOKEN_LIFETIME'].total_seconds()),
            path=ACCESS_COOKIE_PATH, **_cookie_options(),
        )
    if refresh:
        response.set_cookie(
            REFRESH_COOKIE, refresh,
            max_age=int(lifetimes['REFRESH_TOKEN_LIFETIME'].total_seconds()),
            path=REFRESH_COOKIE_PATH, **_cookie_options(),
        )


def clear_auth_cookies(response):
    response.delete_cookie(
        ACCESS_COOKIE, path=ACCESS_COOKIE_PATH, samesite='Strict')
    response.delete_cookie(
        REFRESH_COOKIE, path=REFRESH_COOKIE_PATH, samesite='Strict')


def _unauthorized(message):
    response = Response({'error': message}, status=status.HTTP_401_UNAUTHORIZED)
    clear_auth_cookies(response)
    return response


@api_view(['POST'])
@authentication_classes([])
@permission_classes([AllowAny])
def admin_refresh(request):
    """Swaps the refresh cookie for a fresh access cookie (and a new
    refresh cookie when rotation is on)."""
    if not has_request_header(request):
        return Response(
            {'error': 'Missing request header.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    raw_refresh = request.COOKIES.get(REFRESH_COOKIE)
    if not raw_refresh:
        return _unauthorized('Session expired. Please sign in again.')

    try:
        token = RefreshToken(raw_refresh)
        user = User.objects.filter(
            id=token['user_id'], is_active=True, is_staff=True).first()
        if user is None:
            return _unauthorized('Session expired. Please sign in again.')

        serializer = TokenRefreshSerializer(data={'refresh': raw_refresh})
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
    except Exception:
        # TokenError (expired / blacklisted / tampered) or a validation error.
        return _unauthorized('Session expired. Please sign in again.')

    response = Response({'message': 'Session refreshed.'})
    set_auth_cookies(response, access=data['access'], refresh=data.get('refresh'))
    return response


@api_view(['POST'])
@authentication_classes([])
@permission_classes([AllowAny])
def admin_logout(request):
    """Revokes the refresh token (when the blacklist is enabled) and
    clears both cookies."""
    if not has_request_header(request):
        return Response(
            {'error': 'Missing request header.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    raw_refresh = request.COOKIES.get(REFRESH_COOKIE)
    if raw_refresh:
        try:
            RefreshToken(raw_refresh).blacklist()
        except (TokenError, AttributeError):
            # Already invalid, or the blacklist app isn't installed.
            pass

    response = Response({'message': 'Signed out.'})
    clear_auth_cookies(response)
    return response
