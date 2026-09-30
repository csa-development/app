from datetime import timedelta

from django.contrib.auth import authenticate
from django.contrib.auth.models import Group, User
from django.db.models import Count
from django.db.models.functions import TruncDate
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import api_view, parser_classes, permission_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken

from content.models import Campaign, Event, NewsArticle, PressRelease
from incidents.models import Incident

from .models import ContactMessage, Feedback, LoginActivity, UserProfile
from .permissions import (
    ALL_ROLES,
    IsCOMMSOrSuperAdmin,
    IsITOrSuperAdmin,
    IsSuperAdmin,
    SUPERADMIN,
)

# Priority order used to pick a single "primary_role" for redirecting a
# user straight to their landing dashboard right after login.
ROLE_REDIRECT_PRIORITY = ALL_ROLES  # [SUPERADMIN, LECO, CERT, COMMS, IT]


def resolve_roles(user):
    roles = list(user.groups.filter(name__in=ALL_ROLES).values_list('name', flat=True))
    if user.is_superuser and SUPERADMIN not in roles:
        roles.append(SUPERADMIN)

    primary_role = next(
        (role for role in ROLE_REDIRECT_PRIORITY if role in roles),
        None,
    )
    return roles, primary_role


def get_client_ip(request):
    forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if forwarded_for:
        return forwarded_for.split(',')[0].strip()
    return request.META.get('REMOTE_ADDR')


def record_login_activity(user, source, identifier, request):
    LoginActivity.objects.create(
        user=user,
        source=source,
        identifier=identifier,
        ip_address=get_client_ip(request),
    )


def serialize_user(user):
    profile = UserProfile.objects.filter(user=user).first()
    latest_login = user.login_activities.first()
    full_name = f"{user.first_name} {user.last_name}".strip() or user.username
    return {
        'id': user.id,
        'username': user.username,
        'name': full_name,
        'email': user.email,
        'phone': profile.phone if profile else '',
        'national_id': profile.national_id if profile else '',
        'date_joined': user.date_joined.isoformat(),
        'last_login_at': latest_login.created_at.isoformat() if latest_login else None,
        'last_login_source': latest_login.get_source_display() if latest_login else None,
        'incident_count': user.incidents.count(),
        'feedback_count': user.feedback.count(),
        'is_staff': user.is_staff,
        'is_active': user.is_active,
    }


def serialize_user_detail(user):
    profile = UserProfile.objects.filter(user=user).first()
    return {
        **serialize_user(user),
        'device_tokens': [
            {
                'id': token.id,
                'token': token.token,
                'created_at': token.created_at.isoformat(),
            }
            for token in user.device_tokens.all().order_by('-created_at')[:5]
        ],
        'recent_logins': [
            {
                'id': activity.id,
                'source': activity.get_source_display(),
                'identifier': activity.identifier,
                'ip_address': activity.ip_address,
                'created_at': activity.created_at.isoformat(),
            }
            for activity in user.login_activities.all()[:8]
        ],
        'recent_feedback': [
            {
                'id': item.id,
                'category': item.category,
                'category_display': item.get_category_display(),
                'message': item.message,
                'created_at': item.created_at.isoformat(),
            }
            for item in user.feedback.all().order_by('-created_at')[:8]
        ],
        'verification_history': [
            {
                'id': code.id,
                'purpose': code.purpose,
                'code': code.code,
                'is_used': code.is_used,
                'created_at': code.created_at.isoformat(),
                'expires_at': code.expires_at.isoformat(),
            }
            for code in user.verification_codes.all().order_by('-created_at')[:8]
        ],
        'profile': {
            'phone': profile.phone if profile else '',
            'national_id': profile.national_id if profile else '',
            'date_joined': user.date_joined.isoformat(),
            'first_name': user.first_name,
            'last_name': user.last_name,
        },
        'incident_summaries': [
            {
                'reference_number': incident.reference_number,
                'incident_type': incident.incident_type,
                'status': incident.status,
                'status_display': incident.get_status_display(),
                'created_at': incident.created_at.isoformat(),
            }
            for incident in user.incidents.all().order_by('-created_at')[:8]
        ],
    }


@api_view(['POST'])
def admin_login(request):
    identifier = request.data.get('identifier', '').strip()
    password = request.data.get('password', '').strip()

    if not identifier or not password:
        return Response(
            {'error': 'Username or email and password are required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    username = identifier
    if '@' in identifier:
        user = User.objects.filter(email__iexact=identifier).first()
        username = user.username if user else identifier

    user = authenticate(request, username=username, password=password)
    if not user:
        return Response(
            {'error': 'Invalid admin credentials.'},
            status=status.HTTP_401_UNAUTHORIZED,
        )

    if not user.is_staff:
        return Response(
            {'error': 'This account does not have admin access.'},
            status=status.HTTP_403_FORBIDDEN,
        )

    refresh = RefreshToken.for_user(user)
    record_login_activity(user, 'ADMIN_WEB', identifier, request)

    roles, primary_role = resolve_roles(user)

    return Response({
        'message': 'Admin login successful.',
        'access': str(refresh.access_token),
        'refresh': str(refresh),
        'admin': {
            'id': user.id,
            'username': user.username,
            'name': f"{user.first_name} {user.last_name}".strip() or user.username,
            'email': user.email,
            'roles': roles,
            'primary_role': primary_role,
        }
    })


@api_view(['GET'])
@permission_classes([IsSuperAdmin])
def admin_dashboard(request):
    now = timezone.now()
    last_seven_days = now - timedelta(days=6)

    login_series = (
        LoginActivity.objects.filter(created_at__date__gte=last_seven_days.date())
        .annotate(day=TruncDate('created_at'))
        .values('day')
        .annotate(total=Count('id'))
        .order_by('day')
    )

    incident_series = (
        Incident.objects.filter(created_at__date__gte=last_seven_days.date())
        .annotate(day=TruncDate('created_at'))
        .values('day')
        .annotate(total=Count('id'))
        .order_by('day')
    )

    content_mix = (
        NewsArticle.objects.values('category')
        .annotate(total=Count('id'))
        .order_by('category')
    )

    recent_activity = [
        {
            'id': activity.id,
            'user': f"{activity.user.first_name} {activity.user.last_name}".strip() or activity.user.username,
            'source': activity.get_source_display(),
            'created_at': activity.created_at.isoformat(),
        }
        for activity in LoginActivity.objects.select_related('user')[:8]
    ]

    return Response({
        'stats': {
            'total_users': User.objects.count(),
            'mobile_logins': LoginActivity.objects.filter(source='MOBILE').count(),
            'admin_logins': LoginActivity.objects.filter(source='ADMIN_WEB').count(),
            'total_feedback': Feedback.objects.count(),
            'alerts_count': NewsArticle.objects.filter(category='ALERT').count(),
            'breaking_news_count': NewsArticle.objects.filter(is_breaking=True).count(),
            'published_articles_count': NewsArticle.objects.filter(is_published=True).count(),
            'events_count': Event.objects.count(),
            'campaigns_count': Campaign.objects.count(),
            'press_releases_count': PressRelease.objects.count(),
            'reports_total': Incident.objects.count(),
            'reports_pending': Incident.objects.filter(status='PENDING').count(),
            'reports_under_review': Incident.objects.filter(status='UNDER_REVIEW').count(),
            'reports_resolved': Incident.objects.filter(status='RESOLVED').count(),
            'contact_messages_total': ContactMessage.objects.count(),
        },
        'charts': {
            'logins_per_day': [
                {'label': item['day'].strftime('%b %d'), 'value': item['total']}
                for item in login_series
            ],
            'reports_per_day': [
                {'label': item['day'].strftime('%b %d'), 'value': item['total']}
                for item in incident_series
            ],
            'content_mix': [
                {'label': item['category'], 'value': item['total']}
                for item in content_mix
            ],
        },
        'recent_activity': recent_activity,
    })


@api_view(['GET'])
@permission_classes([IsITOrSuperAdmin])
def admin_users(request):
    users = User.objects.all().order_by('-date_joined')
    return Response({'users': [serialize_user(user) for user in users]})


@api_view(['GET', 'PUT', 'PATCH'])
@permission_classes([IsITOrSuperAdmin])
def admin_user_detail(request, user_id):
    try:
        user = User.objects.get(pk=user_id)
    except User.DoesNotExist:
        return Response({'error': 'User not found.'}, status=status.HTTP_404_NOT_FOUND)

    if request.method in ['PUT', 'PATCH']:
        profile = UserProfile.objects.filter(user=user).first()
        if not profile:
            profile = UserProfile.objects.create(user=user, national_id=user.username)

        for field in ['first_name', 'last_name', 'email']:
            if field in request.data:
                setattr(user, field, request.data.get(field, '').strip())

        if 'is_staff' in request.data:
            user.is_staff = str(request.data.get('is_staff')).lower() in ('1', 'true', 'yes', 'on')
        if 'is_active' in request.data:
            user.is_active = str(request.data.get('is_active')).lower() in ('1', 'true', 'yes', 'on')

        profile.phone = request.data.get('phone', profile.phone).strip()
        profile.national_id = request.data.get('national_id', profile.national_id).strip()

        user.save()
        profile.save()

    return Response({'user': serialize_user_detail(user)})


@api_view(['GET', 'PATCH'])
@permission_classes([IsCOMMSOrSuperAdmin])
def admin_feedback(request):
    if request.method == 'PATCH':
        feedback_id = request.data.get('id')
        if not feedback_id:
            return Response({'error': 'Feedback id is required.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            item = Feedback.objects.get(pk=feedback_id)
        except Feedback.DoesNotExist:
            return Response({'error': 'Feedback item not found.'}, status=status.HTTP_404_NOT_FOUND)

        if 'status' in request.data:
            item.status = request.data.get('status', item.status).strip().upper()
        if 'admin_notes' in request.data:
            item.admin_notes = request.data.get('admin_notes', '')
        item.save()

    items = Feedback.objects.select_related('user').all().order_by('-created_at')
    status_filter = request.query_params.get('status')
    category_filter = request.query_params.get('category')
    if status_filter:
      items = items.filter(status=status_filter.upper())
    if category_filter:
      items = items.filter(category=category_filter.upper())

    return Response({
        'feedback': [
            {
                'id': item.id,
                'category': item.category,
                'category_display': item.get_category_display(),
                'message': item.message,
                'status': item.status,
                'status_display': item.get_status_display(),
                'admin_notes': item.admin_notes,
                'created_at': item.created_at.isoformat(),
                'user': {
                    'id': item.user.id,
                    'name': f"{item.user.first_name} {item.user.last_name}".strip() or item.user.username,
                    'email': item.user.email,
                    'username': item.user.username,
                } if item.user else None,
            }
            for item in items
        ]
    })


@api_view(['GET', 'PATCH'])
@permission_classes([IsCOMMSOrSuperAdmin])
def admin_contact_messages(request):
    if request.method == 'PATCH':
        message_id = request.data.get('id')
        if not message_id:
            return Response({'error': 'Message id is required.'}, status=status.HTTP_400_BAD_REQUEST)
        try:
            item = ContactMessage.objects.get(pk=message_id)
        except ContactMessage.DoesNotExist:
            return Response({'error': 'Message not found.'}, status=status.HTTP_404_NOT_FOUND)

        if 'status' in request.data:
            item.status = request.data.get('status', item.status).strip().upper()
        if 'admin_notes' in request.data:
            item.admin_notes = request.data.get('admin_notes', '')
        item.save()

    items = ContactMessage.objects.all().order_by('-created_at')
    status_filter = request.query_params.get('status')
    if status_filter:
        items = items.filter(status=status_filter.upper())

    return Response({
        'messages': [
            {
                'id': item.id,
                'name': item.name,
                'email': item.email,
                'phone': item.phone,
                'message': item.message,
                'status': item.status,
                'status_display': item.get_status_display(),
                'admin_notes': item.admin_notes,
                'created_at': item.created_at.isoformat(),
            }
            for item in items
        ]
    })


@api_view(['GET'])
@permission_classes([IsITOrSuperAdmin])
def admin_it_dashboard(request):
    now = timezone.now()
    last_seven_days = now - timedelta(days=6)

    signup_series = (
        User.objects.filter(date_joined__date__gte=last_seven_days.date())
        .annotate(day=TruncDate('date_joined'))
        .values('day')
        .annotate(count=Count('id'))
        .order_by('day')
    )

    total_users = User.objects.count()
    active_users = User.objects.filter(is_active=True).count()
    disabled_users = User.objects.filter(is_active=False).count()

    return Response({
        'stats': {
            'total_users': total_users,
            'active_users': active_users,
            'disabled_users': disabled_users,
            'recent_signups_count': User.objects.filter(
                date_joined__date__gte=last_seven_days.date()
            ).count(),
        },
        'charts': {
            'signups_per_day': [
                {'label': row['day'].strftime('%b %d'), 'value': row['count']}
                for row in signup_series
            ],
            'status_mix': [
                {'label': 'Active', 'value': active_users},
                {'label': 'Disabled', 'value': disabled_users},
            ],
            'status_pie': [
                {
                    'label': 'Active',
                    'value': active_users,
                    'percentage': round((active_users / total_users) * 100, 1) if total_users else 0,
                },
                {
                    'label': 'Disabled',
                    'value': disabled_users,
                    'percentage': round((disabled_users / total_users) * 100, 1) if total_users else 0,
                },
            ],
        },
    })


def serialize_staff(user):
    roles, primary_role = resolve_roles(user)
    return {
        'id': user.id,
        'username': user.username,
        'name': f"{user.first_name} {user.last_name}".strip() or user.username,
        'email': user.email,
        'is_active': user.is_active,
        'is_superuser': user.is_superuser,
        'roles': roles,
        'primary_role': primary_role,
        'date_joined': user.date_joined.isoformat(),
    }


@api_view(['GET', 'POST'])
@permission_classes([IsSuperAdmin])
def admin_staff_collection(request):
    if request.method == 'GET':
        staff = User.objects.filter(is_staff=True).order_by('-date_joined')
        return Response({'items': [serialize_staff(user) for user in staff]})

    email = request.data.get('email', '').strip()
    password = request.data.get('password', '').strip()
    roles = request.data.get('roles') or []

    if not email or not password:
        return Response(
            {'error': 'Email and password are required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    invalid_roles = [role for role in roles if role not in ALL_ROLES]
    if invalid_roles:
        return Response(
            {'error': f"Unknown role(s): {', '.join(invalid_roles)}"},
            status=status.HTTP_400_BAD_REQUEST,
        )

    if User.objects.filter(email=email).exists():
        return Response(
            {'error': 'Email already registered.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    user = User.objects.create_user(
        username=email,
        email=email,
        password=password,
        first_name=request.data.get('first_name', '').strip(),
        last_name=request.data.get('last_name', '').strip(),
        is_staff=True,
    )

    if SUPERADMIN in roles:
        user.is_superuser = True
        user.save(update_fields=['is_superuser'])

    if roles:
        groups = Group.objects.filter(name__in=roles)
        user.groups.set(groups)

    return Response(
        {'item': serialize_staff(user)}, status=status.HTTP_201_CREATED
    )


@api_view(['GET', 'PATCH'])
@permission_classes([IsSuperAdmin])
def admin_staff_detail(request, user_id):
    try:
        user = User.objects.get(pk=user_id, is_staff=True)
    except User.DoesNotExist:
        return Response(
            {'error': 'Staff account not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if request.method == 'PATCH':
        for field in ['first_name', 'last_name', 'email']:
            if field in request.data:
                setattr(user, field, request.data.get(field, '').strip())

        if 'is_active' in request.data:
            user.is_active = str(request.data.get('is_active')).lower() in ('1', 'true', 'yes', 'on')

        if 'roles' in request.data:
            roles = request.data.get('roles') or []
            invalid_roles = [role for role in roles if role not in ALL_ROLES]
            if invalid_roles:
                return Response(
                    {'error': f"Unknown role(s): {', '.join(invalid_roles)}"},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user.is_superuser = SUPERADMIN in roles
            user.groups.set(Group.objects.filter(name__in=roles))

        user.save()

    return Response({'item': serialize_staff(user)})
