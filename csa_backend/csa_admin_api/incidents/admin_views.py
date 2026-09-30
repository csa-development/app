from datetime import timedelta

from django.db.models import Count, F
from django.db.models.functions import TruncDate
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from accounts.permissions import IsCERTOrSuperAdmin, IsLECOOrITOrSuperAdmin

from csa_shared_models.incidents.models import (
    Certificate, Incident, IncidentStatusOption, status_label, status_color,
)

TOP_BREAKDOWN_LIMIT = 5
TOP_LOCATION_LIMIT = 6


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


def serialize_incident(incident, request=None):
    evidence_url = None
    if incident.evidence_file:
        evidence_url = (
            request.build_absolute_uri(incident.evidence_file.url)
            if request else incident.evidence_file.url
        )
    return {
        'reference_number': incident.reference_number,
        'incident_type': incident.incident_type,
        'platform': 'MobApp-CSA',
        'description': incident.description,
        'date_of_incident': incident.date_of_incident.isoformat() if incident.date_of_incident else None,
        'location': incident.location,
        'latitude': float(incident.latitude) if incident.latitude is not None else None,
        'longitude': float(incident.longitude) if incident.longitude is not None else None,
        'reporter_name': incident.reporter_name,
        'reporter_phone': incident.reporter_phone,
        'status': incident.status,
        'status_display': status_label(incident.status),
        'status_color': status_color(incident.status),
        'reporting_for_someone': incident.reporting_for_someone,
        'relationship_to_victim': incident.relationship_to_victim,
        'evidence_description': incident.evidence_description,
        'evidence_url': evidence_url,
        'evidence_filename': (
            incident.evidence_file.name.rsplit('/', 1)[-1]
            if incident.evidence_file else None
        ),
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

    return Response({'reports': [serialize_incident(item, request) for item in incidents]})


@api_view(['GET', 'PATCH'])
@permission_classes([IsCERTOrSuperAdmin])
def admin_incident_status(request, reference_number):
    try:
        incident = Incident.objects.select_related('user').get(reference_number=reference_number)
    except Incident.DoesNotExist:
        return Response({'error': 'Report not found.'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        # Lets the admin web app open a single report on its own
        # dedicated detail page (or a refreshed/deep-linked URL) without
        # having to load the full reports list first.
        return Response({'report': serialize_incident(incident, request)})

    new_status = request.data.get('status', '').strip().upper()
    valid_statuses = set(
        IncidentStatusOption.objects.values_list('key', flat=True)
    )
    if new_status not in valid_statuses:
        return Response({'error': 'Invalid status.'}, status=status.HTTP_400_BAD_REQUEST)

    status_changed = incident.status != new_status
    incident.status = new_status
    incident.save()

    # Previously nothing notified the reporter at all when CERT
    # changed a report's status — this was the one missing piece
    # (a mobile-side version of this existed once, but it lived on the
    # since-removed citizen-facing status-write endpoint and was never
    # ported over when status changes became a CERT-only, admin-side
    # action). No-op, not an error, if the report has no linked user
    # (reported by someone not logged in) or no device token on file.
    if status_changed and incident.user:
        from csa_shared_models.accounts.push import send_push_to_user
        send_push_to_user(
            incident.user,
            title='CSA Report Update',
            body=f'Your report {incident.reference_number} has been updated to {status_label(new_status)}.',
        )

    return Response({'report': serialize_incident(incident, request)})


def serialize_status_option(option):
    return {
        'key': option.key,
        'label': option.label,
        'color': option.color,
        'position': option.position,
    }


@api_view(['GET', 'POST'])
@permission_classes([IsCERTOrSuperAdmin])
def admin_incident_statuses(request):
    """CERT-managed list of report statuses. GET returns them ordered
    for rendering a dropdown/timeline. POST adds a new one at a chosen
    position — `insert_after` names an existing status's key to place
    the new one right after (omit/blank to insert at the very start).
    Existing statuses are renumbered (not the new one squeezed into a
    fractional position) so `position` always stays a clean 0..n-1
    sequence — simpler to reason about than float-gap positioning."""
    if request.method == 'GET':
        options = IncidentStatusOption.objects.all()
        return Response({'statuses': [serialize_status_option(o) for o in options]})

    key = request.data.get('key', '').strip().upper().replace(' ', '_')
    label = request.data.get('label', '').strip()
    color = request.data.get('color', '').strip() or '#6B7280'
    insert_after = request.data.get('insert_after', '').strip().upper()

    if not key or not label:
        return Response({'error': 'key and label are required.'}, status=status.HTTP_400_BAD_REQUEST)

    if IncidentStatusOption.objects.filter(key=key).exists():
        return Response({'error': f'Status "{key}" already exists.'}, status=status.HTTP_400_BAD_REQUEST)

    existing = list(IncidentStatusOption.objects.all())
    existing_keys = [o.key for o in existing]

    if insert_after and insert_after not in existing_keys:
        return Response(
            {'error': f'"{insert_after}" is not an existing status to insert after.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    insert_index = (
        existing_keys.index(insert_after) + 1 if insert_after else 0
    )
    existing.insert(insert_index, None)  # placeholder for the new one

    new_option = None
    for position, option in enumerate(existing):
        if option is None:
            new_option = IncidentStatusOption.objects.create(
                key=key, label=label, color=color, position=position,
            )
        elif option.position != position:
            option.position = position
            option.save(update_fields=['position'])

    return Response({'status': serialize_status_option(new_option)}, status=status.HTTP_201_CREATED)


def serialize_certificate(item):
    return {
        'id': item.id,
        'certificate_number': item.certificate_number,
        'certificate_type': item.certificate_type,
        'certificate_type_display': item.get_certificate_type_display(),
        'holder_name': item.holder_name,
        'organisation': item.organisation,
        'holder_email': item.holder_email,
        'issue_date': item.issue_date.isoformat(),
        'expiry_date': item.expiry_date.isoformat(),
        'is_active': item.is_active,
    }


def _is_notify_worthy(certificate):
    """A certificate is worth notifying about once it's active and
    there's an email on file to resolve to a citizen account — most
    certificates today have neither a holder_email nor need one."""
    return certificate.is_active and bool(certificate.holder_email)


def notify_if_approved(certificate, was_notify_worthy):
    """Personal push only on the transition into notify-worthy (same
    pattern as the incident-status signal and the news broadcast
    trigger) — editing an already-active, already-linked certificate's
    organisation name must not re-notify the holder. Never raises."""
    if not _is_notify_worthy(certificate) or was_notify_worthy:
        return

    from django.contrib.auth.models import User
    from csa_shared_models.accounts.push import send_push_to_user

    user = User.objects.filter(email__iexact=certificate.holder_email).first()
    if not user:
        print(f'No account found for holder_email {certificate.holder_email}')
        return

    send_push_to_user(
        user,
        title='Certificate Ready',
        body=f'Your {certificate.get_certificate_type_display()} certificate has been approved.',
    )


@api_view(['GET', 'POST'])
@permission_classes([IsLECOOrITOrSuperAdmin])
def admin_certificates(request):
    if request.method == 'GET':
        items = Certificate.objects.all().order_by('-issue_date', '-id')
        return Response({'items': [serialize_certificate(item) for item in items]})

    item = Certificate.objects.create(
        certificate_number=request.data.get('certificate_number', '').strip(),
        certificate_type=request.data.get('certificate_type', '').strip().upper(),
        holder_name=request.data.get('holder_name', '').strip(),
        organisation=request.data.get('organisation', '').strip(),
        holder_email=request.data.get('holder_email', '').strip(),
        issue_date=request.data.get('issue_date'),
        expiry_date=request.data.get('expiry_date'),
        is_active=str(request.data.get('is_active', 'true')).lower() in ('1', 'true', 'yes', 'on'),
    )
    # Re-fetch from the database so issue_date/expiry_date come back as
    # real date objects (Django only converts them on read, not on the
    # in-memory instance right after .create()) — same fix already
    # applied to Event/Campaign in content/admin_views.py.
    item.refresh_from_db()
    notify_if_approved(item, was_notify_worthy=False)
    return Response({'item': serialize_certificate(item)}, status=status.HTTP_201_CREATED)


@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([IsLECOOrITOrSuperAdmin])
def admin_certificate_detail(request, certificate_id):
    try:
        item = Certificate.objects.get(pk=certificate_id)
    except Certificate.DoesNotExist:
        return Response({'error': 'Certificate not found.'}, status=status.HTTP_404_NOT_FOUND)

    if request.method == 'GET':
        return Response({'item': serialize_certificate(item)})

    if request.method == 'DELETE':
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    was_notify_worthy = _is_notify_worthy(item)

    for field in ['certificate_number', 'holder_name', 'organisation', 'holder_email']:
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
    # Same fix as create: re-fetch so issue_date/expiry_date come back
    # as real date objects instead of the raw strings just assigned.
    item.refresh_from_db()
    notify_if_approved(item, was_notify_worthy=was_notify_worthy)
    return Response({'item': serialize_certificate(item)})


@api_view(['GET'])
@permission_classes([IsLECOOrITOrSuperAdmin])
def admin_certificates_dashboard(request):
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
    location_counts = (
        Incident.objects.values(key=F('location'))
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
            'by_location': as_pie_slices(location_counts, TOP_LOCATION_LIMIT),
        },
    })
