from django.apps import AppConfig


class AccountsConfig(AppConfig):
    # Deliberately no default_auto_field here, matching the original
    # csa_project/accounts/apps.py exactly (it didn't set one either) —
    # setting one explicitly, even to Django's own implicit default,
    # triggered a spurious "unmigrated change" on every model's `id`
    # field (an AutoField serialization quirk in Django's migration
    # autodetector), which the original project doesn't show.
    #
    # Explicit name/label so the app_label (and therefore table names
    # like accounts_userprofile, and django_migrations rows) match
    # exactly what the original csa_project already created in csa_db,
    # regardless of this package's dotted import path.
    name = 'csa_shared_models.accounts'
    label = 'accounts'
