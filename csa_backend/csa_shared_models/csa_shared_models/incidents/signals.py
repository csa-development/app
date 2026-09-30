from django.db.models.signals import pre_save
from django.dispatch import receiver
from .models import Incident


@receiver(pre_save, sender=Incident)
def notify_on_status_change(sender, instance, **kwargs):
    print('Signal fired')

    if not instance.pk:
        return

    try:
        old_instance = Incident.objects.get(pk=instance.pk)
    except Incident.DoesNotExist:
        return

    print(f'Old status: {old_instance.status} New status: {instance.status}')

    if old_instance.status == instance.status:
        return

    if not instance.user:
        print('No user attached to incident')
        return

    from csa_shared_models.accounts.push import send_push_to_user

    status_display = {
        'PENDING': 'Pending',
        'UNDER_REVIEW': 'Under Review',
        'RESOLVED': 'Resolved',
    }

    new_status = status_display.get(instance.status, instance.status)

    result = send_push_to_user(
        instance.user,
        title='CSA Report Update',
        body=f'Your report {instance.reference_number} has been updated to {new_status}.',
    )

    print(f'Notification sent: {result}')
