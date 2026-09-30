from django.db.models.signals import pre_save
from django.dispatch import receiver
from .models import Incident
import google.auth.transport.requests
import google.oauth2.service_account
import requests as http_requests


def send_notification(token, title, body):
    try:
        SERVICE_ACCOUNT_FILE = 'C:/Users/user/Desktop/startiing-flutter/csa_backend/csa_project/firebase-adminsdk.json'

        SCOPES = ['https://www.googleapis.com/auth/firebase.messaging']

        credentials = google.oauth2.service_account.Credentials.from_service_account_file(
            SERVICE_ACCOUNT_FILE,
            scopes=SCOPES
        )

        request = google.auth.transport.requests.Request()
        credentials.refresh(request)
        access_token = credentials.token

        url = 'https://fcm.googleapis.com/v1/projects/ascmob-app/messages:send'

        headers = {
            'Authorization': f'Bearer {access_token}',
            'Content-Type': 'application/json',
        }

        payload = {
            'message': {
                'token': token,
                'notification': {
                    'title': title,
                    'body': body,
                },
            }
        }

        response = http_requests.post(url, json=payload, headers=headers)
        print(f'FCM response: {response.status_code} {response.text}')
        return response.status_code == 200

    except Exception as e:
        print(f'Push notification error: {e}')
        return False


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

    try:
        from accounts.models import DeviceToken

        device = DeviceToken.objects.filter(user=instance.user).first()
        if not device:
            print('No device token found for user')
            return

        print(f'Sending notification to token: {device.token[:20]}...')

        status_display = {
            'PENDING': 'Pending',
            'UNDER_REVIEW': 'Under Review',
            'RESOLVED': 'Resolved',
        }

        new_status = status_display.get(instance.status, instance.status)

        result = send_notification(
            token=device.token,
            title='CSA Report Update',
            body=f'Your report {instance.reference_number} has been updated to {new_status}.',
        )

        print(f'Notification sent: {result}')

    except Exception as e:
        print(f'Signal notification error: {e}')