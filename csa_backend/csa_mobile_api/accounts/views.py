import json
import os
import random
import requests as sms_requests
from datetime import timedelta

from django.http import JsonResponse
from django.contrib.auth.models import User
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.conf import settings
from django.core.cache import cache
from django.core.mail import get_connection, send_mail
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError

from django_ratelimit.decorators import ratelimit

from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from rest_framework_simplejwt.tokens import RefreshToken

from csa_shared_models.accounts.models import (
    VerificationCode,
    UserProfile,
    DeviceToken,
    Feedback,
    ContactMessage,
    NotificationPreference,
)
from csa_shared_models.accounts.utils import record_login_activity, revoke_all_tokens


def _rate_limited_response():
    """Consistent JSON response when a rate limit is hit, instead
    of Django's default blank 403 page."""
    return JsonResponse(
        {"error": "Too many attempts. Please wait a moment and try again."},
        status=429,
    )


def send_sms_otp(phone, otp, message=None):
    # Rancard bulk-SMS credentials. Read from the environment (.env),
    # never hardcoded — a committed key can be used by anyone with repo
    # access to send SMS as "MobApp-CSA".
    api_key = getattr(settings, 'RANCARD_SMS_API_KEY', '') or os.environ.get(
        'RANCARD_SMS_API_KEY', ''
    )
    sender_id = os.environ.get('RANCARD_SMS_SENDER_ID', 'MobApp-CSA')
    if not api_key:
        print('RANCARD_SMS_API_KEY not set — SMS OTP disabled, falling back to email.', flush=True)
        return False
    if message is None:
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

    # Confirmed-correct endpoint (found in Rancard's own API docs
    # after the old unifyapi.rancard.com / unify-base.rancard.com
    # "/v2/sms/send" paths turned out to be wrong entirely — this is
    # a different domain, not just a changed path).
    url = 'https://bulkmessagingapi.rancard.com/api/v1/sms/public/sendMessage'

    # One retry with a shorter timeout. The very first outbound
    # request after a device reconnects (emulator restart, coming
    # back online) routinely has slower DNS/TLS negotiation than
    # normal — enough to trip a single 10s attempt and silently fall
    # back to email even though Rancard itself is fine. Both attempts
    # combined (10s + 4s) stay under the Flutter client's 15s
    # timeout, so this can't turn into a hung request either.
    for attempt, timeout in enumerate((10, 4), start=1):
        try:
            response = sms_requests.post(url, json=payload, timeout=timeout)

            print(
                f'SMS response (attempt {attempt}): '
                f'{response.status_code} {response.text}',
                flush=True,
            )

            # NOTE: this endpoint's response body is not a reliable
            # signal of what actually happened — it was confirmed by
            # hand that a real text can still arrive even when the
            # response reports contactSize: 0. A 200 here means
            # Rancard accepted the request; that's the only thing
            # worth trusting.
            return response.status_code == 200

        except Exception as e:
            print(f'SMS error (attempt {attempt}): {e}', flush=True)

    return False


def send_email_otp(subject, message, recipient_list):
    # Same fix as send_sms_otp above, same reason: confirmed by hand
    # that a plain send_mail() call can hang for minutes — not fail,
    # just sit there — on a slow first SMTP connection after a network
    # change, with no timeout set at all it's bounded only by the OS.
    # A short, explicit per-attempt timeout plus one retry means a
    # slow handshake fails fast instead of blowing past the Flutter
    # client's own 15s request timeout.
    #
    # Measured by hand on a real flaky connection: the first attempt
    # never actually succeeds slowly, it just fails outright once its
    # timeout elapses — so there's nothing to gain from giving it
    # longer, only less room left for the retry. (10, 4) measured
    # 13.7s end to end on a real failing-then-succeeding run — too
    # close to the 15s client limit for comfort. (6, 4) keeps the same
    # one-retry shape with real headroom (max ~10s) instead.
    for attempt, timeout in enumerate((6, 4), start=1):
        try:
            connection = get_connection(timeout=timeout)
            sent = send_mail(
                subject=subject,
                message=message,
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=recipient_list,
                connection=connection,
                fail_silently=False,
            )
            print(f'Email sent (attempt {attempt}): {sent} message(s)', flush=True)
            return sent == 1
        except Exception as e:
            print(f'Email error (attempt {attempt}): {e}', flush=True)

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

    try:
        validate_password(password)
    except DjangoValidationError as exc:
        return JsonResponse({"error": " ".join(exc.messages)}, status=400)

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


# At most one login code per account per this many seconds. The app only
# lets a person ask for another code after the current one has expired (2
# minutes), so this never gets in the way of normal use — it stops repeated
# taps, duplicate requests and any stray call from flooding an inbox or
# racking up SMS costs.
OTP_COOLDOWN_SECONDS = 30


def _mask_identifier(identifier):
    """Enough to recognise an account in a log without exposing it."""
    if '@' in identifier:
        name, _, domain = identifier.partition('@')
        return f"{name[:1]}***@{domain}"
    return f"***{identifier[-3:]}"


@csrf_exempt
# 8 per 10 min per IP — enough headroom for "didn't get it, resend" and
# for several people behind one office NAT, still a hard cap on OTP spam
# / SMS cost.
@ratelimit(key='ip', rate='8/10m', method='POST', block=False)
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

    # Audit trail: every code request is logged with its source, so an
    # unexpected one can be traced to the exact app, browser or address.
    print(
        f"OTP requested: at={timezone.now().isoformat(timespec='seconds')} "
        f"method={method} id={_mask_identifier(identifier)} "
        f"ip={request.META.get('REMOTE_ADDR', '-')} "
        f"origin={request.headers.get('Origin', '-')} "
        f"ua={request.headers.get('User-Agent', '-')[:70]}",
        flush=True,
    )

    try:
        if method == "email":
            user = User.objects.filter(email=identifier).first()
        elif method == "phone":
            profile = UserProfile.objects.filter(phone=identifier).first()
            user = profile.user if profile else None
        else:
            return JsonResponse({"error": "Invalid method"}, status=400)

        # Product decision: tell the user outright that no account
        # matches, rather than the generic "if that account exists"
        # 200 this used to send. Trades account-enumeration resistance
        # for a clearer login experience — accepted knowingly since
        # phone/email aren't treated as secrets here.
        if not user:
            no_account_message = (
                "No account found with that email address. Please register first."
                if method == "email"
                else "No account found with that phone number. Please register first."
            )
            return JsonResponse({"error": no_account_message}, status=404)

        # A disabled account (is_active=False, set by an IT admin) is
        # deliberately told so — a product decision — rather than folded
        # into the generic response above.
        if not user.is_active:
            return JsonResponse(
                {"error": "This account has been disabled. Please contact CSA support."},
                status=403,
            )

    except Exception as e:
        print(f'OTP lookup error: {e}')
        return JsonResponse({"error": "An error occurred"}, status=500)

    cooldown_key = f"otpsent:{user.pk}"
    if not cache.add(cooldown_key, True, OTP_COOLDOWN_SECONDS):
        return JsonResponse(
            {"error": "A code was just sent. Please wait a moment before "
                      "asking for another."},
            status=429,
        )

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
        sms_sent = send_sms_otp(phone_number, code) if phone_number else False

        if sms_sent:
            delivered_via = "phone"
        else:
            # SMS failed (or no SMS provider configured at all —
            # RANCARD_SMS_API_KEY unset makes send_sms_otp always
            # return False without even attempting a send) — fall back
            # to email. Whichever channel it actually went out on is
            # what gets reported below; claiming "sent to your phone"
            # when it silently went to email instead was the actual
            # bug — a citizen who never checks email would just never
            # find their code, no error, nothing to explain why.
            email_sent = send_email_otp(
                subject='Your CSA Login OTP',
                message=f'Your One Time Password (OTP) for CSA is: {code}\n\nThis OTP expires in 2 minutes.\n\nDo not share this code with anyone.',
                recipient_list=[user.email],
            )
            delivered_via = "email" if email_sent else None

        if delivered_via is None:
            # Both SMS and the email fallback failed — say so rather
            # than a false "sent" the user has no way to act on.
            cache.delete(cooldown_key)
            return JsonResponse(
                {"error": "Could not send a verification code right now. Please try again shortly."},
                status=502,
            )

        return JsonResponse({
            "message": f"OTP sent to your {delivered_via}",
            "delivered_via": delivered_via,
            "username": user.username,
        })

    else:
        email_sent = send_email_otp(
            subject='Your CSA Login OTP',
            message=f'Your One Time Password (OTP) for CSA is: {code}\n\nThis OTP expires in 2 minutes.\n\nDo not share this code with anyone.',
            recipient_list=[user.email],
        )

        if not email_sent:
            # Previously this branch reported success unconditionally
            # regardless of whether the email actually sent — exactly
            # the silent-failure shape of "I never received anything."
            cache.delete(cooldown_key)
            return JsonResponse(
                {"error": "Could not send a verification code right now. Please try again shortly."},
                status=502,
            )

        return JsonResponse({
            "message": "OTP sent to your email",
            "delivered_via": "email",
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

    # Unknown username: same generic error as a wrong code — no oracle
    # for which usernames are real. (Staff accounts are allowed through
    # the mobile OTP flow: CSA staff are citizens of the app too, and
    # request_otp already lets them request a code — the two endpoints
    # must agree or a valid code reads as "invalid".)
    user = User.objects.filter(username=username).first()
    if not user:
        return JsonResponse({"error": "Invalid or expired code."}, status=400)

    # Covers the case where the account was disabled in the short window
    # between an OTP being issued and the user submitting it.
    if not user.is_active:
        return JsonResponse(
            {"error": "This account has been disabled. Please contact CSA support."},
            status=403,
        )

    # Per-account wrong-code lockout, on top of the per-IP rate limit.
    fail_key = f"otpfail:{user.pk}"
    if cache.get(fail_key, 0) >= 5:
        return JsonResponse(
            {"error": "Too many incorrect codes. Request a new one in a few minutes."},
            status=429,
        )

    try:
        verification = VerificationCode.objects.filter(
            user=user,
            code=otp,
            purpose="LOGIN",
            is_used=False,
            expires_at__gte=timezone.now()
        ).latest("created_at")
    except VerificationCode.DoesNotExist:
        try:
            cache.incr(fail_key)
        except ValueError:
            cache.set(fail_key, 1, 600)
        return JsonResponse({"error": "Invalid or expired code."}, status=400)

    verification.is_used = True
    verification.save()
    cache.delete(fail_key)

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

        # Phone number changes no longer happen here — they require
        # verifying the new number first (see request_phone_change /
        # confirm_phone_change below), so a phone value sent to this
        # endpoint is intentionally ignored rather than trusted as-is.

        return Response({
            "message": "Profile updated successfully",
            "username": user.username,
            "email": user.email,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "full_name": f"{user.first_name} {user.last_name}".strip(),
            "phone": phone,
        }, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@ratelimit(key='ip', rate='5/5m', method='POST', block=False)
def request_phone_change(request):
    """Step 1 of changing your phone number: send a verification code
    to the NEW number. Nothing is saved to the profile yet — that only
    happens once confirm_phone_change verifies the code."""
    if getattr(request, 'limited', False):
        return Response(
            {'error': 'Too many attempts. Please wait a moment and try again.'},
            status=429,
        )

    new_phone = request.data.get('phone', '').strip()
    if not new_phone:
        return Response({'error': 'Phone number is required'}, status=400)

    if UserProfile.objects.filter(
            phone=new_phone).exclude(user=request.user).exists():
        return Response(
            {'error': 'This phone number is already associated with another account'},
            status=400,
        )

    code = str(random.randint(100000, 999999))

    # Invalidate any previously issued, still-unused phone-change codes
    # for this user — same reasoning as the login OTP flow: only the
    # most recently issued code should ever work.
    VerificationCode.objects.filter(
        user=request.user,
        purpose='PHONE_CHANGE',
        is_used=False,
    ).update(is_used=True)

    VerificationCode.objects.create(
        user=request.user,
        purpose='PHONE_CHANGE',
        code=code,
        pending_value=new_phone,
        expires_at=timezone.now() + timedelta(minutes=2),
    )

    sms_sent = send_sms_otp(
        new_phone,
        code,
        message=(
            f'Your CSA verification code to confirm this new phone '
            f'number is: {code}. It expires in 2 minutes. Do not '
            f'share this code with anyone.'
        ),
    )
    if not sms_sent:
        try:
            send_mail(
                subject='Your CSA Phone Verification Code',
                message=(
                    f'Your verification code to confirm your new phone '
                    f'number is: {code}\n\nThis code expires in 2 minutes.'
                    f'\n\nDo not share this code with anyone.'
                ),
                from_email=settings.DEFAULT_FROM_EMAIL,
                recipient_list=[request.user.email],
                fail_silently=True,
            )
        except Exception as e:
            print(f'Fallback email error: {e}')

    return Response({'message': 'Verification code sent to the new number'})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
@ratelimit(key='ip', rate='10/5m', method='POST', block=False)
def confirm_phone_change(request):
    """Step 2: verify the code sent to the new number, and only then
    actually save it to the profile."""
    if getattr(request, 'limited', False):
        return Response(
            {'error': 'Too many attempts. Please wait a moment and try again.'},
            status=429,
        )

    code = request.data.get('code', '').strip()
    if not code:
        return Response({'error': 'Code is required'}, status=400)

    try:
        verification = VerificationCode.objects.filter(
            user=request.user,
            code=code,
            purpose='PHONE_CHANGE',
            is_used=False,
            expires_at__gte=timezone.now(),
        ).latest('created_at')
    except VerificationCode.DoesNotExist:
        return Response({'error': 'Invalid or expired code'}, status=400)

    new_phone = verification.pending_value
    if not new_phone:
        return Response(
            {'error': 'No pending phone number found for this code'},
            status=400,
        )

    # Re-check uniqueness at confirm time too, in case someone else
    # claimed this number in the few minutes between request and
    # confirm.
    if UserProfile.objects.filter(
            phone=new_phone).exclude(user=request.user).exists():
        return Response(
            {'error': 'This phone number was just claimed by another account. Please try a different number.'},
            status=400,
        )

    profile, _ = UserProfile.objects.get_or_create(user=request.user)
    profile.phone = new_phone
    profile.save()

    verification.is_used = True
    verification.save()

    return Response({
        'message': 'Phone number updated successfully',
        'phone': new_phone,
    })


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

    try:
        validate_password(new_password, user)
    except DjangoValidationError as exc:
        return Response(
            {'error': ' '.join(exc.messages)},
            status=status.HTTP_400_BAD_REQUEST
        )

    user.set_password(new_password)
    user.save()

    # A changed password must kill every session that could belong to
    # someone who knew the old one (a stolen phone, a leaked refresh
    # token). Then give THIS device a fresh pair so the person who just
    # changed it isn't logged out.
    revoke_all_tokens(user)
    refresh = RefreshToken.for_user(user)

    return Response(
        {
            'message': 'Password changed successfully',
            'access': str(refresh.access_token),
            'refresh': str(refresh),
        },
        status=status.HTTP_200_OK
    )


# The refresh token itself is the credential here, so this is open to
# anyone holding one — that also lets a phone whose ACCESS token has
# already expired still log out properly. Always answers 200 so it can't
# be used to probe which tokens are valid.
@api_view(['POST'])
@permission_classes([AllowAny])
@ratelimit(key='ip', rate='30/10m', method='POST', block=False)
def logout(request):
    if getattr(request, 'limited', False):
        return _rate_limited_response()

    refresh = str(request.data.get('refresh', '')).strip()
    if refresh:
        try:
            token = RefreshToken(refresh)
            blacklist = getattr(token, 'blacklist', None)
            if blacklist is not None:
                blacklist()
        except Exception:
            # Expired / malformed / already revoked: nothing to revoke.
            pass

    return Response({'message': 'Logged out.'}, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def send_feedback(request):
    category = request.data.get('category', '').strip()
    message = request.data.get('message', '').strip()
    rating = request.data.get('rating')

    if not category:
        return Response(
            {'error': 'Category is required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Every other category is a written note and needs a message. Only
    # the "Rate the App" star picker (APP_RATING) can be submitted with
    # just stars and no comment.
    if category == 'APP_RATING':
        if not rating:
            return Response(
                {'error': 'A star rating is required'},
                status=status.HTTP_400_BAD_REQUEST
            )
    elif not message:
        return Response(
            {'error': 'Category and message are required'},
            status=status.HTTP_400_BAD_REQUEST
        )

    Feedback.objects.create(
        user=request.user,
        category=category,
        message=message,
        rating=rating if category == 'APP_RATING' else None,
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