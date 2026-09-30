from django.apps import AppConfig


class ContentConfig(AppConfig):
    # No default_auto_field, matching original content/apps.py exactly —
    # see the comment in accounts/apps.py for why.
    name = 'csa_shared_models.content'
    label = 'content'
