from rest_framework.permissions import BasePermission

SUPERADMIN = 'SUPERADMIN'
CERT = 'CERT'
IT = 'IT'
LECO = 'LECO'
COMMS = 'COMMS'

ALL_ROLES = [SUPERADMIN, CERT, IT, LECO, COMMS]


def user_has_group(user, group_name):
    if not user or not user.is_authenticated:
        return False
    return user.groups.filter(name=group_name).exists()


def user_is_superadmin(user):
    if not user or not user.is_authenticated:
        return False
    return user.is_superuser or user_has_group(user, SUPERADMIN)


class IsSuperAdmin(BasePermission):
    """Full access. Only role allowed to manage staff and assign roles."""

    def has_permission(self, request, view):
        return bool(request.user and request.user.is_staff) and user_is_superadmin(request.user)


class IsCERTOrSuperAdmin(BasePermission):
    """Incident response domain."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_staff):
            return False
        return user_is_superadmin(user) or user_has_group(user, CERT)


class IsITOrSuperAdmin(BasePermission):
    """Citizen user account management, plus every content and
    certificate domain — IT is a superset role that can also do
    everything LECO and COMMS can, in addition to users, campaigns,
    and site content which are IT-only."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_staff):
            return False
        return user_is_superadmin(user) or user_has_group(user, IT)


class IsLECOOrSuperAdmin(BasePermission):
    """Certificate issuance and the certificate registry."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_staff):
            return False
        return user_is_superadmin(user) or user_has_group(user, LECO)


class IsCOMMSOrSuperAdmin(BasePermission):
    """News, alerts, breaking news, events, NCSAM, and press releases."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_staff):
            return False
        return user_is_superadmin(user) or user_has_group(user, COMMS)


class IsLECOOrITOrSuperAdmin(BasePermission):
    """Certificate domain — LECO owns it, IT retains full access too."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_staff):
            return False
        return (
            user_is_superadmin(user)
            or user_has_group(user, IT)
            or user_has_group(user, LECO)
        )


class IsCOMMSOrITOrSuperAdmin(BasePermission):
    """News/alerts/events/NCSAM/press releases — COMMS owns it, IT
    retains full access too."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_staff):
            return False
        return (
            user_is_superadmin(user)
            or user_has_group(user, IT)
            or user_has_group(user, COMMS)
        )


class IsCERTOrITOrSuperAdmin(BasePermission):
    """Read access shared across CERT and IT. Currently unused — kept as
    a building block for any view that needs to be visible to both the
    incident-response (CERT) and IT domains. Views using this should
    still gate any write/mutation action to IT/SuperAdmin only."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_staff):
            return False
        return (
            user_is_superadmin(user)
            or user_has_group(user, IT)
            or user_has_group(user, CERT)
        )
