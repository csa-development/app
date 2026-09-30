from datetime import timedelta

from django.db.models import Count, F
from django.db.models.functions import TruncDate
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from accounts.permissions import IsCERTOrSuperAdmin, IsLECOOrSuperAdmin

from .models import Certificate, Incident

TOP_BREAKDOWN_LIMIT = 5
TOP_REGION_LIMIT = 6


def as_pie_slices(counted, limit, other_label='Other'):
    """Turns a values().annotate(count=Count(...)) queryset into up to
    `limit` label/value/percentage slices, folding the remainder into
    a single 'Other' slice so pie charts stay readable."""
    counted = list(counted)
    total = sum(row['count'] for row in counted)
    top = counted[:limit]
    rest = sum(row['count'] for row in counted[limit:])

    slices = [
        {
            'label': row['key'] or 'Unspecified',
            'value': row['count'],
            'percentage': round((row['count'] / total) * 100, 1) if total else 0,
        }
        for row in top
    ]
    if rest:
        slices.append({
            'label': other_label,
            'value': rest,
            'percentage': round((rest / total) * 100, 1) if total else 0,
        })
    return slices


def serialize_incident(incident):
    return {
        'reference_number': incident.reference_number,
        'incident_type': incident.incident_type,
        'platform': incident.platform,
        'description': incident.description,
        'date_of_incident': incident.date_of_incident.isoformat() if incident.date_of_incident else None,
        'region': incident.region,
        'reporter_name': incident.reporter_name,
        'reporter_phone': incident.reporter_phone,
        'status': incident.status,
        'status_display': incident.get_status_display(),
        'reporting_for_someone': incident.reporting_for_someone,
        'relationship_to_victim': incident.relationship_to_victim,
        'evidence_description': incident.evidence_description,
        'created_at': incident.created_at.isoformat(),
        'updated_at': incident.updated_at.isoformat(),
        'user': {
            'id': incident.user.id,
            'username': incident.user.username,
            'email': incident.user.email,
            'name': f"{incident.user.first_name} {incident.user.last_name}".strip() or incident.user.username,
        } if incident.user else None,
    }


@api_view(['GET'])
@permission_classes([IsCERTOrSuperAdmin])
def admin_incidents(request):
    incidents = Incident.objects.select_related('user').all().order_by('-created_at')

    status_filter = request.query_params.get('status')
    if status_filter:
        incidents = incidents.filter(status=status_filter.upper())

    return Response({'reports': [serialize_incident(item) for item in incidents]})


@api_view(['PATCH'])
@permission_classes([IsCERTOrSuperAdmin])
def admin_incident_status(request, reference_number):
    try:
        incident = Incident.objects.select_related('user').get(reference_number=reference_number)
    except Incident.DoesNotExist:
        return Response({'error': 'Report not found.'}, status=status.HTTP_404_NOT_FOUND)

    new_status = request.data.get('status', '').strip().upper()
    valid_statuses = ['PENDING', 'UNDER_REVIEW', 'RESOLVED']
    if new_status not in valid_statuses:
        return Response({'error': 'Invalid status.'}, status=status.HTTP_400_BAD_REQUEST)

    incident.status = new_status
    incident.save()
    return Response({'report': serialize_incident(incident)})


def serialize_certificate(item):
    return {
        'id': item.id,
        'certificate_number': item.certificate_number,
        'certificate_type': item.certificate_type,
        'certificate_type_display': item.get_certificate_type_display(),
        'holder_name': item.holder_name,
        'organisation': item.organisation,
        'issue_date': item.issue_date.isoformat(),
        'expiry_date': item.expiry_date.isoformat(),
        'is_active': item.is_active,
    }


@api_view(['GET', 'POST'])
@permission_classes([IsLECOOrSuperAdmin])
def admin_certificates(request):
    if request.method == 'GET':
        items = Certificate.objects.all().order_by('-issue_date', '-id')
        return Response({'items': [serialize_certificate(item) for item in items]})

    item = Certificate.objects.create(
        certificate_number=request.data.get('certificate_number', '').strip(),
        certificate_type=request.data.get('certificate_type', '').strip().upper(),
        holder_name=request.data.get('holder_name', '').strip(),
        organisation=request.data.get('organisation', '').strip(),
        issue_date=request.data.get('issue_date'),
        expiry_date=request.data.get('expiry_date'),
        is_active=str(request.data.get('is_active', 'true')).lower() in ('1', 'true', 'yes', 'on'),
    )
    return Response({'item': serialize_certificate(item)}, status=status.HTTP_201_CREATED)


@api_view(['PUT', 'DELETE'])
@permission_classes([IsLECOOrSuperAdmin])
def admin_certificate_detail(request, certificate_id):
    try:
        item = Certificate.objects.get(pk=certificate_id)
    except Certificate.DoesNotExist:
        return Response({'error': 'Certificate not found.'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'DELETE':
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    for field in ['certificate_number', 'holder_name', 'organisation']:
        if field in request.data:
            setattr(item, field, request.data.get(field, '').strip())
    if 'certificate_type' in request.data:
        item.certificate_type = request.data.get('certificate_type', item.certificate_type).strip().upper()
    if 'issue_date' in request.data:
        item.issue_date = request.data.get('issue_date') or item.issue_date
    if 'expiry_date' in request.data:
        item.expiry_date = request.data.get('expiry_date') or item.expiry_date
    if 'is_active' in request.data:
        item.is_active = str(request.data.get('is_active')).lower() in ('1', 'true', 'yes', 'on')
    item.save()
    return Response({'item': serialize_certificate(item)})


@api_view(['GET'])
@permission_classes([IsLECOOrSuperAdmin])
def admin_leco_dashboard(request):
    now = timezone.now()
    today = now.date()
    expiry_horizon = today + timedelta(days=30)

    type_counts = (
        Certificate.objects.values(key=F('certificate_type'))
        .annotate(count=Count('id'))
        .order_by('-count')
    )

    recent_certificates = Certificate.objects.all().order_by('-issue_date', '-id')[:8]

    return Response({
        'stats': {
            'total_certificates': Certificate.objects.count(),
            'active_certificates': Certificate.objects.filter(is_active=True).count(),
            'inactive_certificates': Certificate.objects.filter(is_active=False).count(),
            'expiring_soon_count': Certificate.objects.filter(
                is_active=True,
                expiry_date__gte=today,
                expiry_date__lte=expiry_horizon,
            ).count(),
        },
        'charts': {
            'by_type': [
                {'label': row['key'], 'value': row['count']}
                for row in type_counts
            ],
            'type_pie': as_pie_slices(type_counts, TOP_BREAKDOWN_LIMIT),
        },
        'recent_certificates': [
            serialize_certificate(item) for item in recent_certificates
        ],
    })


@api_view(['GET'])
@permission_classes([IsCERTOrSuperAdmin])
def admin_cert_dashboard(request):
    now = timezone.now()
    last_fourteen_days = (now - timedelta(days=13)).date()

    status_counts = (
        Incident.objects.values(key=F('status'))
        .annotate(count=Count('id'))
        .order_by('-count')
    )
    type_counts = (
        Incident.objects.values(key=F('incident_type'))
        .annotate(count=Count('id'))
        .order_by('-count')
    )
    region_counts = (
        Incident.objects.values(key=F('region'))
        .annotate(count=Count('id'))
        .order_by('-count')
    )
    trend = (
        Incident.objects.filter(created_at__date__gte=last_fourteen_days)
        .annotate(day=TruncDate('created_at'))
        .values('day')
        .annotate(count=Count('id'))
        .order_by('day')
    )

    return Response({
        'stats': {
            'total_incidents': Incident.objects.count(),
            'pending': Incident.objects.filter(status='PENDING').count(),
            'under_review': Incident.objects.filter(status='UNDER_REVIEW').count(),
            'resolved': Incident.objects.filter(status='RESOLVED').count(),
        },
        'charts': {
            'by_status': [
                {'label': row['key'], 'value': row['count']}
                for row in status_counts
            ],
            'status_pie': as_pie_slices(status_counts, len(status_counts)),
            'by_type': [
                {'label': row['key'], 'value': row['count']}
                for row in type_counts[:TOP_BREAKDOWN_LIMIT]
            ],
            'type_pie': as_pie_slices(type_counts, TOP_BREAKDOWN_LIMIT),
            'trend_per_day': [
                {'label': row['day'].strftime('%b %d'), 'value': row['count']}
                for row in trend
            ],
            'by_region': as_pie_slices(region_counts, TOP_REGION_LIMIT),
        },
    })
