import random

from django.conf import settings
from django.core.mail import send_mail
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework import status
from csa_shared_models.content.models import (
    NewsArticle,
    Event,
    Campaign,
    PressRelease,
    EventRegistration,
    CampaignRegistration,
    AboutPageContent,
    ContactPageContent,
)


from .event_status import campaign_has_ended, event_has_ended


def get_image_url(request, image):
    if image:
        return request.build_absolute_uri(image.url)
    return None


def _generate_check_in_code():
    """Generates a unique CSA-#### style check-in code.

    Checked against both registration tables so an event ticket and a
    campaign ticket can never collide on the same code.
    """
    while True:
        code = f"CSA-{random.randint(1000, 9999)}"
        if (
            not EventRegistration.objects.filter(check_in_code=code).exists()
            and not CampaignRegistration.objects.filter(check_in_code=code).exists()
        ):
            return code


def _send_check_in_code_email(user, event, code):
    """Emails the check-in code to the user, reusing existing SMTP config.

    Fails silently (does not raise) so a slow/broken email server never
    blocks the registration itself from succeeding.
    """
    if not user.email:
        return
    try:
        send_mail(
            subject=f'Your check-in code for {event.title}',
            message=(
                f"Hi {user.first_name or user.username},\n\n"
                f"You're registered for \"{event.title}\" on "
                f"{event.event_date.strftime('%B %d, %Y')}.\n\n"
                f"Your check-in code is: {code}\n\n"
                f"Show this code at the door when you arrive, or give your "
                f"name if you don't have it handy.\n\n"
                f"— Cyber Security Authority"
            ),
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=True,
        )
    except Exception:
        # Never let an email failure break registration.
        pass


def _send_check_in_code_sms(user, event, code):
    """
    TODO: No SMS provider is currently wired up in this project.
    Once one is chosen (e.g. Twilio, Hubtel, Africa's Talking), send the
    check-in code here the same way OTPs are sent via SMS.
    """
    pass


def _send_campaign_check_in_code_email(user, campaign, code):
    """Emails the check-in code for a campaign registration (e.g. NCSAM)."""
    if not user.email:
        return
    try:
        send_mail(
            subject=f'Your check-in code for {campaign.title}',
            message=(
                f"Hi {user.first_name or user.username},\n\n"
                f"You're registered for \"{campaign.title}\" starting "
                f"{campaign.start_date.strftime('%B %d, %Y')}.\n\n"
                f"Your check-in code is: {code}\n\n"
                f"Show this code at the door when you arrive, or give your "
                f"name if you don't have it handy.\n\n"
                f"— Cyber Security Authority"
            ),
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=True,
        )
    except Exception:
        pass


@api_view(['GET'])
def get_news(request):
    category = request.query_params.get('category', None)
    page = int(request.query_params.get('page', 1))
    page_size = int(request.query_params.get('page_size', 10))

    if category:
        articles = NewsArticle.objects.filter(
            is_published=True,
            category=category.upper()
        ).order_by('-date_published')
    else:
        articles = NewsArticle.objects.filter(
            is_published=True
        ).order_by('-date_published')

    total_count = articles.count()
    start = (page - 1) * page_size
    end = start + page_size
    articles = articles[start:end]

    data = [
        {
            'id': a.id,
            'title': a.title,
            'body': a.body,
            'category': a.category,
            'category_display': a.get_category_display(),
            'image': get_image_url(request, a.image),
            'date_published': a.date_published.isoformat(),
            'is_breaking': a.is_breaking,
        }
        for a in articles
    ]

    return Response({
        'news': data,
        'total_count': total_count,
        'page': page,
        'page_size': page_size,
        'has_more': end < total_count,
    })


@api_view(['GET'])
def get_news_detail(request, news_id):
    try:
        article = NewsArticle.objects.get(id=news_id, is_published=True)
    except NewsArticle.DoesNotExist:
        return Response({'error': 'Article not found'}, status=404)

    data = {
        'id': article.id,
        'title': article.title,
        'body': article.body,
        'category': article.category,
        'category_display': article.get_category_display(),
        'image': get_image_url(request, article.image),
        'date_published': article.date_published.isoformat(),
        'is_breaking': article.is_breaking,
    }

    return Response({'article': data})


@api_view(['GET'])
def get_alerts(request):
    alerts = NewsArticle.objects.filter(
        is_published=True,
        category='ALERT'
    ).order_by('-date_published')

    data = [
        {
            'id': a.id,
            'title': a.title,
            'body': a.body,
            'image': get_image_url(request, a.image),
            'date_published': a.date_published.isoformat(),
        }
        for a in alerts
    ]

    return Response({'alerts': data})


@api_view(['GET'])
def get_breaking_news(request):
    articles = NewsArticle.objects.filter(
        is_published=True,
        is_breaking=True
    ).order_by('-date_published')[:5]

    data = [
        {
            'id': a.id,
            'title': a.title,
            'body': a.body,
            'category': a.category,
            'category_display': a.get_category_display(),
            'image': get_image_url(request, a.image),
            'date_published': a.date_published.isoformat(),
        }
        for a in articles
    ]

    return Response({'breaking_news': data})


@api_view(['GET'])
def get_events(request):
    events = Event.objects.filter(
        is_published=True
    ).order_by('-event_date')

    data = [
        {
            'id': e.id,
            'title': e.title,
            'description': e.description,
            'location': e.location,
            'latitude': e.latitude,
            'longitude': e.longitude,
            'event_date': e.event_date.strftime('%B %d, %Y'),
            'end_date': e.end_date.strftime('%B %d, %Y') if e.end_date else None,
            'start_time': e.start_time.strftime('%I:%M %p').lstrip('0')
                if e.start_time else None,
            'end_time': e.end_time.strftime('%I:%M %p').lstrip('0')
                if e.end_time else None,
            'image': get_image_url(request, e.image),
            'total_registrations': e.registrations.count(),
            'has_ended': event_has_ended(e),
        }
        for e in events
    ]

    return Response({'events': data})


@api_view(['GET'])
def get_event_detail(request, event_id):
    try:
        event = Event.objects.get(id=event_id, is_published=True)
    except Event.DoesNotExist:
        return Response({'error': 'Event not found'}, status=404)

    data = {
        'id': event.id,
        'title': event.title,
        'description': event.description,
        'location': event.location,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'event_date': event.event_date.strftime('%B %d, %Y'),
        'end_date': event.end_date.strftime('%B %d, %Y') if event.end_date else None,
        'start_time': event.start_time.strftime('%I:%M %p').lstrip('0')
            if event.start_time else None,
        'end_time': event.end_time.strftime('%I:%M %p').lstrip('0')
            if event.end_time else None,
        'image': get_image_url(request, event.image),
        'total_registrations': event.registrations.count(),
        'has_ended': event_has_ended(event),
    }

    return Response({'event': data})


@api_view(['GET'])
def get_campaigns(request):
    campaigns = Campaign.objects.filter(
        is_published=True
    ).order_by('-start_date')

    data = [
        {
            'id': c.id,
            'title': c.title,
            'description': c.description,
            'start_date': c.start_date.strftime('%B %d, %Y'),
            'end_date': c.end_date.strftime('%B %d, %Y') if c.end_date else None,
            'target_audience': c.target_audience,
            'location': c.location,
            'latitude': c.latitude,
            'longitude': c.longitude,
            'category': c.category,
            'category_display': c.get_category_display(),
            'image': get_image_url(request, c.image),
            'has_ended': campaign_has_ended(c),
        }
        for c in campaigns
    ]

    return Response({'campaigns': data})


@api_view(['GET'])
def get_campaign_detail(request, campaign_id):
    try:
        campaign = Campaign.objects.get(id=campaign_id, is_published=True)
    except Campaign.DoesNotExist:
        return Response({'error': 'Campaign not found'}, status=404)

    gallery = [
        {
            'id': g.id,
            'image': get_image_url(request, g.image),
            'caption': g.caption,
        }
        for g in campaign.gallery.all()
    ]

    schedule = []
    current_week = None
    current_sessions = []

    for s in campaign.schedule.all():
        if s.week_number != current_week:
            if current_week is not None:
                schedule.append({
                    'week': current_week,
                    'sessions': current_sessions,
                })
            current_week = s.week_number
            current_sessions = []
        current_sessions.append({
            'start_time': s.start_time.strftime('%H:%M'),
            'end_time': s.end_time.strftime('%H:%M') if s.end_time else None,
            'session_title': s.session_title,
            'speaker': s.speaker,
            'venue': s.venue,
            'day': s.day,
        })

    if current_week is not None:
        schedule.append({
            'week': current_week,
            'sessions': current_sessions,
        })

    speakers = [
        {
            'id': sp.id,
            'name': sp.name,
            'title': sp.title,
            'organisation': sp.organisation,
            'bio': sp.bio,
            'photo': get_image_url(request, sp.photo),
        }
        for sp in campaign.speakers.all()
    ]

    related_news = [
        {
            'id': cn.article.id,
            'title': cn.article.title,
            'body': cn.article.body,
            'image': get_image_url(request, cn.article.image),
            'date_published': cn.article.date_published.isoformat(),
            'category_display': cn.article.get_category_display(),
        }
        for cn in campaign.related_news.all()
    ]

    data = {
        'id': campaign.id,
        'title': campaign.title,
        'description': campaign.description,
        'start_date': campaign.start_date.strftime('%B %d, %Y'),
        'end_date': campaign.end_date.strftime('%B %d, %Y') if campaign.end_date else None,
        'start_date_iso': campaign.start_date.isoformat(),
        'has_ended': campaign_has_ended(campaign),
        'end_date_iso': campaign.end_date.isoformat() if campaign.end_date else None,
        'target_audience': campaign.target_audience,
        'location': campaign.location,
        'latitude': campaign.latitude,
        'longitude': campaign.longitude,
        'category': campaign.category,
        'category_display': campaign.get_category_display(),
        'image': get_image_url(request, campaign.image),
        'gallery': gallery,
        'schedule': schedule,
        'speakers': speakers,
        'related_news': related_news,
    }

    return Response({'campaign': data})


@api_view(['GET'])
def get_press_releases(request):
    releases = PressRelease.objects.filter(
        is_published=True
    ).order_by('-date_published')

    data = [
        {
            'id': r.id,
            'title': r.title,
            'body': r.body,
            'image': get_image_url(request, r.image),
            'date_published': r.date_published.strftime('%B %d, %Y'),
        }
        for r in releases
    ]

    return Response({'press_releases': data})


@api_view(['GET'])
def get_press_release_detail(request, release_id):
    try:
        release = PressRelease.objects.get(id=release_id, is_published=True)
    except PressRelease.DoesNotExist:
        return Response({'error': 'Press release not found'}, status=404)

    data = {
        'id': release.id,
        'title': release.title,
        'body': release.body,
        'image': get_image_url(request, release.image),
        'date_published': release.date_published.strftime('%B %d, %Y'),
    }

    return Response({'press_release': data})


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_event_interest(request, event_id):
    try:
        event = Event.objects.get(id=event_id, is_published=True)
    except Event.DoesNotExist:
        return Response({'error': 'Event not found'}, status=404)

    # Ended: no new sign-ups. Someone already registered just gets their
    # existing registration back below.
    if event_has_ended(event) and not EventRegistration.objects.filter(
        user=request.user, event=event
    ).exists():
        return Response(
            {'error': 'This event has ended. Registration is closed.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    registration, created = EventRegistration.objects.get_or_create(
        user=request.user,
        event=event,
    )

    if created:
        # Generate the check-in code and send it out via email/SMS the
        # moment a new registration is created.
        registration.check_in_code = _generate_check_in_code()
        registration.save()

        _send_check_in_code_email(request.user, event, registration.check_in_code)
        _send_check_in_code_sms(request.user, event, registration.check_in_code)

        return Response({
            'message': 'Successfully registered interest',
            'registered': True,
            'check_in_code': registration.check_in_code,
            'total_registrations': event.registrations.count(),
        }, status=status.HTTP_201_CREATED)
    else:
        return Response({
            'message': 'Already registered',
            'registered': True,
            'check_in_code': registration.check_in_code,
            'total_registrations': event.registrations.count(),
        }, status=status.HTTP_200_OK)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def unregister_event_interest(request, event_id):
    try:
        event = Event.objects.get(id=event_id, is_published=True)
        # An ended event's registrations are a record of who signed up and
        # who attended, so they can no longer be removed.
        if event_has_ended(event):
            return Response(
                {'error': 'This event has ended.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        registration = EventRegistration.objects.get(
            user=request.user,
            event=event,
        )
        registration.delete()
        return Response({
            'message': 'Registration removed',
            'registered': False,
            'total_registrations': event.registrations.count(),
        }, status=status.HTTP_200_OK)
    except Event.DoesNotExist:
        return Response({'error': 'Event not found'}, status=404)
    except EventRegistration.DoesNotExist:
        return Response({'error': 'Not registered'}, status=404)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_event_registration(request, event_id):
    try:
        event = Event.objects.get(id=event_id, is_published=True)
        registration = EventRegistration.objects.filter(
            user=request.user,
            event=event,
        ).first()
        return Response({
            'registered': registration is not None,
            'check_in_code': registration.check_in_code if registration else None,
            'checked_in': registration.checked_in if registration else False,
            'total_registrations': event.registrations.count(),
            'has_ended': event_has_ended(event),
        }, status=status.HTTP_200_OK)
    except Event.DoesNotExist:
        return Response({'error': 'Event not found'}, status=404)


@api_view(['POST'])
@permission_classes([IsAuthenticated])
def register_campaign_interest(request, campaign_id):
    try:
        campaign = Campaign.objects.get(id=campaign_id, is_published=True)
    except Campaign.DoesNotExist:
        return Response({'error': 'Campaign not found'}, status=404)

    if campaign_has_ended(campaign) and not CampaignRegistration.objects.filter(
        user=request.user, campaign=campaign
    ).exists():
        return Response(
            {'error': 'This campaign has ended. Registration is closed.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    registration, created = CampaignRegistration.objects.get_or_create(
        user=request.user,
        campaign=campaign,
    )

    if created:
        registration.check_in_code = _generate_check_in_code()
        registration.save()

        _send_campaign_check_in_code_email(
            request.user, campaign, registration.check_in_code
        )

        return Response({
            'message': 'Successfully registered interest',
            'registered': True,
            'check_in_code': registration.check_in_code,
            'total_registrations': campaign.registrations.count(),
        }, status=status.HTTP_201_CREATED)
    else:
        return Response({
            'message': 'Already registered',
            'registered': True,
            'check_in_code': registration.check_in_code,
            'total_registrations': campaign.registrations.count(),
        }, status=status.HTTP_200_OK)


@api_view(['DELETE'])
@permission_classes([IsAuthenticated])
def unregister_campaign_interest(request, campaign_id):
    try:
        campaign = Campaign.objects.get(id=campaign_id, is_published=True)
        if campaign_has_ended(campaign):
            return Response(
                {'error': 'This campaign has ended.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        registration = CampaignRegistration.objects.get(
            user=request.user,
            campaign=campaign,
        )
        registration.delete()
        return Response({
            'message': 'Registration removed',
            'registered': False,
            'total_registrations': campaign.registrations.count(),
        }, status=status.HTTP_200_OK)
    except Campaign.DoesNotExist:
        return Response({'error': 'Campaign not found'}, status=404)
    except CampaignRegistration.DoesNotExist:
        return Response({'error': 'Not registered'}, status=404)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def check_campaign_registration(request, campaign_id):
    try:
        campaign = Campaign.objects.get(id=campaign_id, is_published=True)
        registration = CampaignRegistration.objects.filter(
            user=request.user,
            campaign=campaign,
        ).first()
        return Response({
            'registered': registration is not None,
            'check_in_code': registration.check_in_code if registration else None,
            'checked_in': registration.checked_in if registration else False,
            'total_registrations': campaign.registrations.count(),
            'has_ended': campaign_has_ended(campaign),
        }, status=status.HTTP_200_OK)
    except Campaign.DoesNotExist:
        return Response({'error': 'Campaign not found'}, status=404)


@api_view(['GET'])
def get_about_page(request):
    about = AboutPageContent.objects.first()
    if not about:
        return Response({'about': None})

    data = {
        'intro_paragraph_1': about.intro_paragraph_1,
        'intro_paragraph_2': about.intro_paragraph_2,
        'image': get_image_url(request, about.image),
        'mandate_text': about.mandate_text,
        'mission_text': about.mission_text,
        'vision_text': about.vision_text,
        'core_values': [
            {
                'title': getattr(about, f'value_{i}_title'),
                'description': getattr(about, f'value_{i}_description'),
            }
            for i in range(1, 7)
        ],
    }
    return Response({'about': data})


@api_view(['GET'])
def get_contact_page(request):
    contact = ContactPageContent.objects.first()
    if not contact:
        return Response({'contact': None})

    data = {
        'office_address': contact.office_address,
        'latitude': contact.latitude,
        'longitude': contact.longitude,
        'phone': contact.phone,
        'emergency_hotline': contact.emergency_hotline,
        'email': contact.email,
        'whatsapp_channel_url': contact.whatsapp_channel_url,
        'twitter_url': contact.twitter_url,
        'instagram_url': contact.instagram_url,
        'linkedin_url': contact.linkedin_url,
        'facebook_url': contact.facebook_url,
    }
    return Response({'contact': data})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_my_event_registrations(request):
    """
    Returns every event the current user has registered for, along with
    their check-in code and checked-in status. Used by the mobile app's
    "My Upcoming Events" section on Home.
    """
    # Newest registration first (was ordered by the EVENT's own date,
    # not when the user registered — so a ticket just registered for
    # could land anywhere in the list instead of at the top).
    registrations = EventRegistration.objects.filter(
        user=request.user
    ).select_related('event').order_by('-registered_at')

    data = [
        {
            'event_id': r.event.id,
            'event_title': r.event.title,
            'event_date': r.event.event_date.strftime('%B %d, %Y'),
            'check_in_code': r.check_in_code,
            'checked_in': r.checked_in,
            'registered_at': r.registered_at.isoformat(),
        }
        for r in registrations
    ]

    return Response({'registrations': data})


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def get_my_campaign_registrations(request):
    """
    Returns every campaign (e.g. NCSAM) the current user has registered
    for, along with their check-in code and checked-in status. Used by
    the mobile app's "My Tickets" section on Home alongside events.
    """
    # Newest registration first — same fix as get_my_event_registrations
    # above, same reason.
    registrations = CampaignRegistration.objects.filter(
        user=request.user
    ).select_related('campaign').order_by('-registered_at')

    data = [
        {
            'campaign_id': r.campaign.id,
            'campaign_title': r.campaign.title,
            'campaign_date': r.campaign.start_date.strftime('%B %d, %Y'),
            'check_in_code': r.check_in_code,
            'checked_in': r.checked_in,
            'registered_at': r.registered_at.isoformat(),
        }
        for r in registrations
    ]

    return Response({'registrations': data})