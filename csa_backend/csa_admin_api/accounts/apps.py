from django.apps import AppConfig


class AccountsAdminConfig(AppConfig):
    default_auto_field = 'django.db.models.AutoField'
    name = 'accounts'
    # Distinct label from the shared "accounts" app (which owns the real
    # accounts_* tables/migrations) — this local app only contributes
    # admin.py (Django's built-in staff CMS registrations) and the
    # create_admin_groups management command, it owns no models of its
    # own, so there's no label collision.
    label = 'accounts_admin'
