import random
import json
import requests as sms_requests
from datetime import timedelta

from django.http import JsonResponse
from django.contrib.auth.models import User
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.conf import settings
from django.core.mail import send_mail

from django_ratelimit.decorators import ratelimit

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

from .models import (
    VerificationCode,
    UserProfile,
    DeviceToken,
    Feedback,
    ContactMessage,
    NotificationPreference,
)
from .admin_views import record_login_activity


def _rate_limited_response():
    """Consistent JSON response when a rate limit is hit, instead
    of Django's default blank 403 page."""
    return JsonResponse(
        {"error": "Too many attempts. Please wait a moment and try again."},
        status=429,
    )


def send_sms_otp(phone, otp):
    try:
        api_key = 'Q1NBIE1vYmlsZSBBcHA6TnVjbGV1cy1DU0E6MjEyOkFQSWtkczAxNDI0Nzg1NDU='
        sender_id = 'CSA'
        message = f'Your CSA login OTP is: {otp}. It expires in 2 minutes. Do not share this code.'

        if phone.startswith('0'):
            phone = '233' + phone[1:]
        elif phone.startswith('+'):
            phone = phone[1:]

        payload = {
            'apiKey': api_key,
            'contacts': [phone],
            'message': message,
            'senderId': sender_id,
            'scheduled': False,
            'hasPlaceholders': False,
        }

        # NOTE: Rancard's API domain changed from unifyapi.rancard.com
        # (no longer resolves) to unify-base.rancard.com. If SMS still
        # fails after this fix, the endpoint path/auth method may also
        # need updating per Rancard's current API docs.
        response = sms_requests.post(
            'https://unify-base.rancard.com/v2/sms/send',
            json=payload,
            timeout=10,
        )

        print(f'SMS response: {response.status_code} {response.text}')
        return response.status_code == 200

    except Exception as e:
        print(f'SMS error: {e}')
        return False


@csrf_exempt
@ratelimit(key='ip', rate='5/h', method='POST', block=False)
def register_user(request):
    if getattr(request, 'limited', False):
        return _rate_limited_response()

    if request.method != "POST":
        return JsonResponse({"error": "Invalid request"}, status=400)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "Invalid JSON"}, status=400)

    # NOTE: national_id has been removed — the Flutter registration
    # screens no longer collect it. Email is now used as the account's
    # username instead (Django's default username validator allows
    # letters, digits, and @/./+/-/_, which every valid email already
    # satisfies).
    full_name = data.get("full_name", "").strip()
    email = data.get("email", "").strip()
    phone = data.get("phone", "").strip()
    password = data.get("password", "").strip()

    if not all([full_name, email, phone, password]):
        return JsonResponse({"error": "All fields are required"}, status=400)

    if len(password) < 8:
        return JsonResponse(
            {"error": "Password must be at least 8 characters"}, status=400)

    if User.objects.filter(email=email).exists():
        return JsonResponse({"error": "Email already registered"}, status=400)

    names = full_name.split(" ", 1)
    first_name = names[0]
    last_name = names[1] if len(names) > 1 else ""

    user = User.objects.create_user(
        username=email,
        email=email,
        password=password,
        first_name=first_name,
        last_name=last_name,
    )
    user.save()

    UserProfile.objects.create(
        user=user,
        phone=phone,
    )

    return JsonResponse({
        "message": "Registration successful",
        "user": user.username,
        "full_name": f"{user.first_name} {user.last_name}".strip(),
    }, status=201)


@csrf_exempt
@ratelimit(key='ip', rate='5/5m', method='POST', block=False)
def request_otp(request):
    if getattr(request, 'limited', False):
        return _rate_limited_response()

    if request.method != "POST":
        return JsonResponse({"error": "Invalid request"}, status=400)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "Invalid JSON"}, status=400)

    identifier = data.get("identifier", "").strip()
    method = data.get("method", "").strip()

    if not identifier or not method:
        return JsonResponse(
            {"error": "Identifier and method are required"}, status=400)

    try:
        if method == "email":
            user = User.objects.filter(email=identifier).first()
        elif method == "phone":
            profile = UserProfile.objects.filter(phone=identifier).first()
            user = profile.user if profile else None
        else:
            return JsonResponse({"error": "Invalid method"}, status=400)

        if not user:
            return JsonResponse(
                {"error": "No account found with that information"},
                status=404
            )

    except Exception as e:
        print(f'OTP lookup error: {e}')
        return JsonResponse({"error": "An error occurred"}, status=500)

    code = str(random.randint(100000, 999999))

    # Invalidate any previously issued, still-unused codes for this
    # user first — without this, resending a code leaves the OLD
    # code still valid alongside the new one, which is a real bug:
    # someone could log in with a stale code from several requests
    # ago. Only the most recently issued code should ever work.
    VerificationCode.objects.filter(
        user=user,
        purpose="LOGIN",
        is_used=False,
    ).update(is_used=True)

    VerificationCode.objects.create(
        user=user,
        purpose="LOGIN",
        code=code,
        expires_at=timezone.now() + timedelta(minutes=2)
    )

    if method == "phone":
        profile = UserProfile.objects.filter(user=user).first()
        phone_number = profile.phone if profile else None
        if phone_number:
            sms_sent = send_sms_otp(phone_number, code)
            if not sms_sent:
                try:
                    send_mail(
                        subject='Your CSA Login OTP',
                        message=f'Your One Time Password (OTP) for CSA is: {code}\n\nThis OTP expires in 2 minutes.\n\nDo not share this code with anyone.',
                        from_email=settings.DEFAULT_FROM_EMAIL,
                        recipient_list=[user.email],
                        fail_silently=True,
                    )
                except Exception as e:
                    print(f'Fallback email error: {e}')

        return JsonResponse({
            "message": "OTP sent to your phone",
            "username": user.username,
        })

    else:
        try:
            send_mail(
                subject='Your CSA Login OTP',
                message=f'Your One Time Password (OTP) for CSA is: {code}\n\nThis OTP expires in 2 minutes.\n\nDo not share this code with anyone.',
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[user.email],
                fail_silently=True,
            )
        except Exception as e:
            print(f'Email error: {e}')

        return JsonResponse({
            "message": "OTP sent to your email",
            "username": user.username,
        })


@csrf_exempt
@ratelimit(key='ip', rate='10/5m', method='POST', block=False)
def verify_otp(request):
    if getattr(request, 'limited', False):
        return _rate_limited_response()

    if request.method != "POST":
        return JsonResponse({"error": "Invalid request"}, status=400)

    try:
        data = json.loads(request.body)
    except json.JSONDecodeError:
        return JsonResponse({"error": "Invalid JSON"}, status=400)

    username = data.get("username", "").strip()
    otp = data.get("otp", "").strip()

    if not username or not otp:
        return JsonResponse(
            {"error": "Username and OTP are required"}, status=400)

    try:
        user = User.objects.get(username=username)
    except User.DoesNotExist:
        return JsonResponse({"error": "User not found"}, status=404)

    try:
        verification = VerificationCode.objects.filter(
            user=user,
            code=otp,
            purpose="LOGIN",
            is_used=False,
            expires_at__gte=timezone.now()
        ).latest("created_at")
    except VerificationCode.DoesNotExist:
        return JsonResponse({"error": "Invalid or expired OTP"}, status=400)

    verification.is_used = True
    verification.save()

    refresh = RefreshToken.for_user(user)
    record_login_activity(user, 'MOBILE', username, request)

    phone = ''
    try:
        phone = user.profile.phone
    except Exception:
        pass

    return JsonResponse({
        "message": "Login successful",
        "user": user.username,
        "full_name": f"{user.first_name} {user.last_name}".strip(),
        "email": user.email,
        "phone": phone,
        "access": str(refresh.access_token),
        "refresh": str(refresh),
    })


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def protected_view(request):
    return Response({
        "message": "You are authenticated",
        "user": request.user.username,
    })


@api_view(["GET", "PUT"])
@permission_classes([IsAuthenticated])
def user_profile(request):
    user = request.user

    phone = ''
    try:
        phone = user.profile.phone
    except Exception:
        pass

    if request.method == "GET":
        return Response({
            "username": user.username,
            "email": user.email,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "full_name": f"{user.first_name} {user.last_name}".strip(),
            "phone": phone,
            "date_joined": user.date_joined,
        })

    elif request.method == "PUT":
        data = request.data
        user.first_name = data.get("first_name", user.first_name)
        user.last_name = data.get("last_name", user.last_name)
        user.email = data.get("email", user.email)

        if User.objects.filter(
                email=user.email).exclude(pk=user.pk).exists():
            return Response(
                {"error": "Email already in use"},
                status=status.HTTP_400_BAD_REQUEST
            )

        user.save()

        new_phone = data.get("phone", "")
        if new_phone:
            try:
                profile = user.profile
                profile.phone = new_phone
                profile.save()
            except Exception:
                # national_id no longer applies here — the field on
                # UserProfile still exists (blank=True) for old rows,
                # but new profiles created this way just leave it blank.
                UserProfile.objects.create(
                    user=user,
                    phone=new_phone,
                )

        return Response({
            "message": "Profile updated successfully",
            "username": user.username,
            "email": user.email,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "full_name": f"{user.first_name} {user.last_name}".strip(),
            "phone": new_phone or phone,
        }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def save_device_token(request):
    token = request.data.get('token', '').strip()
    if not token:
        return Response({'error': 'Token required'}, status=400)

    DeviceToken.objects.update_or_create(
        user=request.user,
        defaults={'token': token}
    )

    return Response({'message': 'Token saved successfully'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def change_password(request):
    user = request.user
    current_password = request.data.get('current_password', '').strip()
    new_password = request.data.get('new_password', '').strip()
    confirm_password = request.data.get('confirm_password', '').strip()

    if not current_password or not new_password or not confirm_password:
        return Response(
            {'error': 'All fields are required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    if not user.check_password(current_password):
        return Response(
            {'error': 'Current password is incorrect'},
            status=status.HTTP_400_BAD_REQUEST
        )

    if new_password != confirm_password:
        return Response(
            {'error': 'New passwords do not match'},
            status=status.HTTP_400_BAD_REQUEST
        )

    if len(new_password) < 8:
        return Response(
            {'error': 'Password must be at least 8 characters'},
            status=status.HTTP_400_BAD_REQUEST
        )

    user.set_password(new_password)
    user.save()

    return Response(
        {'message': 'Password changed successfully'},
        status=status.HTTP_200_OK
    )


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_feedback(request):
    category = request.data.get('category', '').strip()
    message = request.data.get('message', '').strip()

    if not category or not message:
        return Response(
            {'error': 'Category and message are required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    Feedback.objects.create(
        user=request.user,
        category=category,
        message=message,
    )

    return Response(
        {'message': 'Feedback submitted successfully'},
        status=status.HTTP_201_CREATED
    )


@api_view(['POST'])
def send_contact_message(request):
    name = request.data.get('name', '').strip()
    phone = request.data.get('phone', '').strip()
    email = request.data.get('email', '').strip()
    message = request.data.get('message', '').strip()

    if not name or not email or not message:
        return Response(
            {'error': 'Name email and message are required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    ContactMessage.objects.create(
        name=name,
        phone=phone,
        email=email,
        message=message,
    )

    return Response(
        {'message': 'Message sent successfully'},
        status=status.HTTP_201_CREATED
    )


@api_view(['GET', 'POST'])
@permission_classes([IsAuthenticated])
def notification_preferences(request):
    prefs, _ = NotificationPreference.objects.get_or_create(
        user=request.user
    )

    if request.method == 'GET':
        return Response({
            'alerts': prefs.alerts,
            'advisories': prefs.advisories,
            'news': prefs.news,
            'events': prefs.events,
            'report_updates': prefs.report_updates,
            'email_notifications': prefs.email_notifications,
        })

    elif request.method == 'POST':
        prefs.alerts = request.data.get('alerts', prefs.alerts)
        prefs.advisories = request.data.get(
            'advisories', prefs.advisories)
        prefs.news = request.data.get('news', prefs.news)
        prefs.events = request.data.get('events', prefs.events)
        prefs.report_updates = request.data.get(
            'report_updates', prefs.report_updates)
        prefs.email_notifications = request.data.get(
            'email_notifications', prefs.email_notifications)
        prefs.save()

        return Response({
            'message': 'Preferences saved successfully',
            'alerts': prefs.alerts,
            'advisories': prefs.advisories,
            'news': prefs.news,
            'events': prefs.events,
            'report_updates': prefs.report_updates,
            'email_notifications': prefs.email_notifications,
        })