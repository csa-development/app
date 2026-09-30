import json
import os
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.contrib.auth.models import User
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from .models import Incident, Certificate
import google.auth.transport.requests
import google.oauth2.service_account
import requests as http_requests


def send_push_notification(token, title, body):
    try:
        SERVICE_ACCOUNT_FILE = r'C:\Users\user\Desktop\startiing-flutter\csa_backend\csa_project\firebase-adminsdk.json'

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


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def submit_report(request):
    data = request.data

    incident_type = data.get('incident_type', '').strip()
    description = data.get('description', '').strip()

    if not incident_type or not description:
        return Response(
            {'error': 'Incident type and description are required'},
            status=400
        )

    incident = Incident.objects.create(
        user=request.user,
        incident_type=incident_type,
        platform=data.get('platform', ''),
        description=description,
        date_of_incident=data.get('date_of_incident') or None,
        region=data.get('region', ''),
        reporter_name=data.get('reporter_name', ''),
        reporter_phone=data.get('reporter_phone', ''),
        reporting_for_someone=data.get('reporting_for_someone', False),
        relationship_to_victim=data.get('relationship_to_victim', ''),
        evidence_description=data.get('evidence_description', ''),
    )

    return Response({
        'message': 'Report submitted successfully',
        'reference_number': incident.reference_number,
        'status': incident.status,
        'created_at': incident.created_at.strftime('%B %d, %Y'),
    }, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def my_reports(request):
    incidents = Incident.objects.filter(
        user=request.user
    ).order_by('-created_at')

    data = [
        {
            'reference_number': i.reference_number,
            'incident_type': i.incident_type,
            'platform': i.platform,
            'description': i.description,
            'status': i.get_status_display(),
            'created_at': i.created_at.strftime('%B %d, %Y'),
        }
        for i in incidents
    ]

    return Response({'reports': data})


@api_view(['POST'])
def verify_certificate(request):
    certificate_number = request.data.get('certificate_number', '').strip()
    certificate_type = request.data.get('certificate_type', '').strip()

    if not certificate_number or not certificate_type:
        return Response(
            {'error': 'Certificate number and type are required'},
            status=400
        )

    type_map = {
        'Cybersecurity Service Provider (CSP)': 'CSP',
        'Cybersecurity Establishment (CE)': 'CE',
        'Cybersecurity Professional (CP)': 'CP',
    }

    mapped_type = type_map.get(certificate_type)

    if not mapped_type:
        return Response({'error': 'Invalid certificate type'}, status=400)

    try:
        cert = Certificate.objects.get(
            certificate_number=certificate_number,
            certificate_type=mapped_type,
            is_active=True,
        )

        return Response({
            'valid': True,
            'holder_name': cert.holder_name,
            'organisation': cert.organisation,
            'certificate_number': cert.certificate_number,
            'certificate_type': cert.get_certificate_type_display(),
            'issue_date': cert.issue_date.strftime('%B %d, %Y'),
            'expiry_date': cert.expiry_date.strftime('%B %d, %Y'),
        })

    except Certificate.DoesNotExist:
        return Response({'valid': False}, status=200)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def update_report_status(request, reference_number):
    try:
        incident = Incident.objects.get(reference_number=reference_number)
    except Incident.DoesNotExist:
        return Response({'error': 'Report not found'}, status=404)

    new_status = request.data.get('status', '').strip()

    valid_statuses = ['PENDING', 'UNDER_REVIEW', 'RESOLVED']
    if new_status not in valid_statuses:
        return Response({'error': 'Invalid status'}, status=400)

    incident.status = new_status
    incident.save()

    if incident.user:
        try:
            from accounts.models import DeviceToken
            device = DeviceToken.objects.filter(user=incident.user).first()
            if device:
                status_display = {
                    'PENDING': 'Pending',
                    'UNDER_REVIEW': 'Under Review',
                    'RESOLVED': 'Resolved',
                }
                send_push_notification(
                    token=device.token,
                    title='CSA Report Update',
                    body=f'Your report {incident.reference_number} has been updated to {status_display[new_status]}.',
                )
        except Exception as e:
            print(f'Notification error: {e}')

    return Response({
        'message': 'Status updated successfully',
        'reference_number': incident.reference_number,
        'status': incident.get_status_display(),
    })