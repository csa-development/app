from rest_framework.permissions import BasePermission

SUPERADMIN = 'SUPERADMIN'
LECO = 'LECO'
CERT = 'CERT'
COMMS = 'COMMS'
IT = 'IT'

ALL_ROLES = [SUPERADMIN, LECO, CERT, COMMS, IT]


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


class IsLECOOrSuperAdmin(BasePermission):
    """Certificates/licensing domain."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_staff):
            return False
        return user_is_superadmin(user) or user_has_group(user, LECO)


class IsCERTOrSuperAdmin(BasePermission):
    """Incident response domain."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_staff):
            return False
        return user_is_superadmin(user) or user_has_group(user, CERT)


class IsCOMMSOrSuperAdmin(BasePermission):
    """News/alerts/events/campaigns/press releases/feedback/contact messages."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_staff):
            return False
        return user_is_superadmin(user) or user_has_group(user, COMMS)


class IsITOrSuperAdmin(BasePermission):
    """Citizen user account management."""

    def has_permission(self, request, view):
        user = request.user
        if not (user and user.is_staff):
            return False
        return user_is_superadmin(user) or user_has_group(user, IT)
