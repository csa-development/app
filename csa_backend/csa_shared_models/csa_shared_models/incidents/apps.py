from django.apps import AppConfig


class IncidentsConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'csa_shared_models.incidents'
    label = 'incidents'

    def ready(self):
        # Registers the pre_save signal that fires an FCM push notification
        # whenever Incident.status changes. Because this app is installed
        # in BOTH csa_mobile_api and csa_admin_api, the signal fires no
        # matter which process performs the status update.
        import csa_shared_models.incidents.signals  # noqa: F401
