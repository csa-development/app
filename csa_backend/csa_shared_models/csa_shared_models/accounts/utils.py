"""Small helpers shared between csa_mobile_api and csa_admin_api.

Extracted from the original accounts/admin_views.py, where mobile-facing
code (accounts/views.py's verify_otp) depended on a function physically
defined in the staff-facing file. Kept here as a single source of truth
so both processes call the same login-activity recording logic.
"""

from .models import LoginActivity


def get_client_ip(request):
    forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if forwarded_for:
        return forwarded_for.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')


def record_login_activity(user, source, identifier, request):
    LoginActivity.objects.create(
        user=user,
        source=source,
        identifier=identifier,
        ip_address=get_client_ip(request),
    )


def revoke_all_tokens(user):
    """Blacklist every refresh token ever issued to `user`, so none of
    them can be exchanged for a new access token again.

    Used on password change and when an admin disables an account. A
    no-op (returns 0) when rest_framework_simplejwt.token_blacklist isn't
    installed, so callers never need to know whether it is.

    Note this only stops REFRESHING. An access token already in hand
    stays valid until it expires (30 min) — except for disabled accounts,
    which simplejwt already rejects on every request (CHECK_USER_IS_ACTIVE).
    """
    from django.apps import apps

    if not apps.is_installed('rest_framework_simplejwt.token_blacklist'):
        return 0

    from rest_framework_simplejwt.token_blacklist.models import (
        BlacklistedToken,
        OutstandingToken,
    )

    revoked = 0
    for outstanding in OutstandingToken.objects.filter(user=user):
        _, created = BlacklistedToken.objects.get_or_create(token=outstanding)
        revoked += int(created)
    return revoked
