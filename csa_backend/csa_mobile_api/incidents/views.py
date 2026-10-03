from django_ratelimit.decorators import ratelimit
from rest_framework.decorators import api_view, permission_classes, parser_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from csa_shared_models.incidents.models import (
    Incident, Certificate, IncidentStatusOption, status_label, status_color,
)

from .evidence import vet_evidence_file

# 100MB — a phone video of a minute or so is routinely 30-80MB, so a
# smaller cap would reject most real video evidence. Still a firm cap so
# one upload can't fill the shared media disk. The app
# (report_incident_2.dart) checks the same limit right after the file
# is picked; this is the server-side backstop.
MAX_EVIDENCE_FILE_BYTES = 100 * 1024 * 1024

# NOTE: incident status changes are a CERT action only, done through the
# admin API (permission-gated). The mobile app has no status-write
# endpoint — a citizen setting their own report to "Resolved" is not a
# feature. The old update_report_status view (and its broken,
# hardcoded-path push helper) lived here and was removed.


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def submit_report(request):
    data = request.data

    incident_type = data.get('incident_type', '').strip()
    description = data.get('description', '').strip()

    if not incident_type or not description:
        return Response(
            {'error': 'Incident type and description are required'},
            status=400
        )

    def _parse_coordinate(value):
        try:
            return float(value) if value not in (None, '') else None
        except (TypeError, ValueError):
            return None

    def _parse_bool(value):
        # A plain JSON body hands this a real bool already; a
        # multipart body (now used whenever there's an evidence file)
        # hands every field back as a string — 'false' is still
        # truthy in Python, so it must be checked by value, not just
        # existence.
        if isinstance(value, bool):
            return value
        return str(value).strip().lower() in ('1', 'true', 'yes', 'on')

    # Optional — a plain JSON submission (no attachment) never has
    # request.FILES populated at all, so this stays None for those.
    evidence_file = request.FILES.get('evidence_file')
    if evidence_file and evidence_file.size > MAX_EVIDENCE_FILE_BYTES:
        return Response(
            {'error': 'Evidence file is too large (100MB max).'},
            status=400,
        )
    if evidence_file:
        evidence_file, evidence_error = vet_evidence_file(evidence_file)
        if evidence_error:
            return Response({'error': evidence_error}, status=400)

    incident = Incident.objects.create(
        user=request.user,
        incident_type=incident_type,
        platform=data.get('platform', ''),
        description=description,
        date_of_incident=data.get('date_of_incident') or None,
        # Accept the old key too so an older installed APK keeps working.
        location=data.get('location', data.get('region', '')),
        latitude=_parse_coordinate(data.get('latitude')),
        longitude=_parse_coordinate(data.get('longitude')),
        reporter_name=data.get('reporter_name', ''),
        reporter_phone=data.get('reporter_phone', ''),
        reporting_for_someone=_parse_bool(data.get('reporting_for_someone', False)),
        relationship_to_victim=data.get('relationship_to_victim', ''),
        evidence_description=data.get('evidence_description', ''),
        evidence_file=evidence_file,
    )

    return Response({
        'message': 'Report submitted successfully',
        'reference_number': incident.reference_number,
        'status': incident.status,
        'created_at': incident.created_at.strftime('%B %d, %Y'),
    }, status=201)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def list_statuses(request):
    # Read-only for the mobile app — CERT manages this list from the
    # admin web app. Ordered by `position` (model Meta.ordering) so the
    # app can render a timeline/filter chips in the same order CERT set,
    # including any status added since the app was last updated.
    options = IncidentStatusOption.objects.all()
    return Response({
        'statuses': [
            {'key': o.key, 'label': o.label, 'color': o.color}
            for o in options
        ]
    })


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
            'status': status_label(i.status),
            'status_key': i.status,
            'status_color': status_color(i.status),
            'created_at': i.created_at.strftime('%B %d, %Y'),
            'date_of_incident': (
                i.date_of_incident.strftime('%B %d, %Y')
                if i.date_of_incident else None
            ),
            'location': i.location,
            'region': i.location,  # legacy alias for older app builds
            'latitude': float(i.latitude) if i.latitude is not None else None,
            'longitude': float(i.longitude) if i.longitude is not None else None,
            'reporter_name': i.reporter_name,
            'reporter_phone': i.reporter_phone,
        }
        for i in incidents
    ]

    return Response({'reports': data})


@ratelimit(key='ip', rate='15/3m', method='POST', block=False)
@api_view(['POST'])
def verify_certificate(request):
    if getattr(request, 'limited', False):
        return Response(
            {'error': 'Too many attempts. Please wait a moment and try again.'},
            status=429,
        )

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


