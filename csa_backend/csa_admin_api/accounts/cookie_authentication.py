"""The authentication class for staff logins kept in HttpOnly cookies.

Deliberately its own tiny module: Django REST imports this class while it
is still setting up its own views, so this file must not import anything
that itself needs REST's views (that causes a circular import). The login,
refresh and logout views live in cookie_auth.py. See that file for the
full explanation of the cookie design.
"""

from rest_framework.exceptions import PermissionDenied
from rest_framework_simplejwt.authentication import JWTAuthentication

ACCESS_COOKIE = 'csa_admin_access'
REFRESH_COOKIE = 'csa_admin_refresh'
REQUEST_HEADER = 'X-CSA-Admin'

SAFE_METHODS = ('GET', 'HEAD', 'OPTIONS')


def has_request_header(request):
    return request.headers.get(REQUEST_HEADER) == '1'


class CookieJWTAuthentication(JWTAuthentication):
    """An explicit `Authorization: Bearer` header still works (API tools,
    scripts). Otherwise the HttpOnly access cookie is used, and anything
    that changes data must also carry the custom request header."""

    def authenticate(self, request):
        if self.get_header(request) is not None:
            return super().authenticate(request)

        raw_token = request.COOKIES.get(ACCESS_COOKIE)
        if not raw_token:
            return None

        validated = self.get_validated_token(raw_token)
        if request.method not in SAFE_METHODS and not has_request_header(request):
            raise PermissionDenied('Missing request header.')
        return self.get_user(validated), validated
