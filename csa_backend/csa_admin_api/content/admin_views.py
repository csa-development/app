from django.db.models import Count, Q
from django.utils import timezone
from rest_framework import status
from rest_framework.decorators import (
    api_view,
    parser_classes,
    permission_classes,
)
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.response import Response

from accounts.permissions import IsCOMMSOrITOrSuperAdmin, IsITOrSuperAdmin

from csa_shared_models.content.models import Campaign, Event, NewsArticle, PressRelease
from csa_shared_models.content.models import (
    CampaignGallery,
    CampaignNews,
    CampaignRegistration,
    CampaignSchedule,
    CampaignSpeaker,
    EventRegistration,
    AboutPageContent,
    ContactPageContent,
)


def get_image_url(request, image):
    # Relative, not request.build_absolute_uri(...): the admin web app's
    # Vite dev server proxies /media to this API (including through its
    # self-signed HTTPS cert, which the browser itself doesn't trust), so
    # an absolute URL here would make the browser load images from this
    # API's origin directly and hit that untrusted-cert wall.
    if image:
        return image.url
    return None


def parse_bool(value, default=False):
    if value in (None, ''):
        return default
    if isinstance(value, bool):
        return value
    return str(value).lower() in ('1', 'true', 'yes', 'on')


def parse_coord(value):
    """A latitude/longitude string from the map picker, or None."""
    if value in (None, ''):
        return None
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def serialize_article(request, article):
    return {
        'id': article.id,
        'title': article.title,
        'body': article.body,
        'category': article.category,
        'category_display': article.get_category_display(),
        'image': get_image_url(request, article.image),
        'date_published': article.date_published.isoformat(),
        'is_published': article.is_published,
        'is_breaking': article.is_breaking,
    }


def _is_notify_worthy(article):
    """Only breaking news and ALERT-category articles push a
    notification, and only once they're actually published — a draft
    marked breaking doesn't notify anyone yet."""
    return article.is_published and (article.is_breaking or article.category == 'ALERT')


def notify_if_breaking_or_alert(article, was_notify_worthy):
    """Broadcasts a push only on the transition INTO a notify-worthy
    state (mirrors the existing incident-status signal's
    `if old_instance.status == instance.status: return` pattern) — an
    already-breaking article being re-saved for an unrelated edit (body
    typo fix, image swap) must not re-notify everyone. Never raises: a
    failed/partial broadcast must not roll back the publish itself."""
    if not _is_notify_worthy(article) or was_notify_worthy:
        return

    from csa_shared_models.accounts.push import send_push_broadcast

    title = 'Breaking News' if article.is_breaking else 'Alert'
    send_push_broadcast(title=title, body=article.title)


def serialize_event(request, event):
    return {
        'id': event.id,
        'title': event.title,
        'description': event.description,
        'location': event.location,
        'latitude': event.latitude,
        'longitude': event.longitude,
        'event_date': event.event_date.isoformat(),
        'end_date': (
            event.end_date.isoformat() if event.end_date else None
        ),
        'start_time': (
            event.start_time.strftime('%H:%M') if event.start_time else None
        ),
        'end_time': (
            event.end_time.strftime('%H:%M') if event.end_time else None
        ),
        'image': get_image_url(request, event.image),
        'is_published': event.is_published,
        'total_registrations': event.registrations.count(),
    }


def serialize_campaign(request, campaign):
    return {
        'id': campaign.id,
        'title': campaign.title,
        'description': campaign.description,
        'start_date': campaign.start_date.isoformat(),
        'end_date': (
            campaign.end_date.isoformat() if campaign.end_date else None
        ),
        'image': get_image_url(request, campaign.image),
        'target_audience': campaign.target_audience,
        'location': campaign.location,
        'latitude': campaign.latitude,
        'longitude': campaign.longitude,
        'category': campaign.category,
        'category_display': campaign.get_category_display(),
        'is_published': campaign.is_published,
        'gallery_count': campaign.gallery.count(),
        'schedule_count': campaign.schedule.count(),
        'speaker_count': campaign.speakers.count(),
        'registration_count': campaign.registrations.count(),
    }


def serialize_campaign_gallery(request, item):
    return {
        'id': item.id,
        'image': get_image_url(request, item.image),
        'caption': item.caption,
        'order': item.order,
    }


def serialize_campaign_schedule(item):
    return {
        'id': item.id,
        'week_number': item.week_number,
        'day': item.day,
        'start_time': item.start_time.isoformat(),
        'end_time': (
            item.end_time.isoformat() if item.end_time else None
        ),
        'session_title': item.session_title,
        'speaker': item.speaker,
        'venue': item.venue,
    }


def serialize_campaign_speaker(request, item):
    return {
        'id': item.id,
        'name': item.name,
        'title': item.title,
        'organisation': item.organisation,
        'bio': item.bio,
        'photo': get_image_url(request, item.photo),
        'order': item.order,
    }


def serialize_campaign_news(item):
    return {
        'id': item.id,
        'article_id': item.article_id,
        'article_title': item.article.title,
        'article_category': item.article.category,
    }


def serialize_registration(item):
    has_profile = hasattr(item.user, 'profile')
    full_name = f"{item.user.first_name} {item.user.last_name}".strip()

    return {
        'id': item.id,
        'registered_at': item.registered_at.isoformat(),
        'check_in_code': item.check_in_code,
        'checked_in': item.checked_in,
        'checked_in_at': (
            item.checked_in_at.isoformat()
            if item.checked_in_at else None
        ),
        'user': {
            'id': item.user.id,
            'username': item.user.username,
            'name': full_name or item.user.username,
            'email': item.user.email,
            'phone': item.user.profile.phone if has_profile else '',
            'national_id': (
                item.user.profile.national_id if has_profile else ''
            ),
        },
        'event': {
            'id': item.event.id,
            'title': item.event.title,
            'event_date': item.event.event_date.isoformat(),
        }
    }


def serialize_campaign_registration(item):
    has_profile = hasattr(item.user, 'profile')
    full_name = f"{item.user.first_name} {item.user.last_name}".strip()

    return {
        'id': item.id,
        'registered_at': item.registered_at.isoformat(),
        'check_in_code': item.check_in_code,
        'checked_in': item.checked_in,
        'checked_in_at': (
            item.checked_in_at.isoformat()
            if item.checked_in_at else None
        ),
        'user': {
            'id': item.user.id,
            'username': item.user.username,
            'name': full_name or item.user.username,
            'email': item.user.email,
            'phone': item.user.profile.phone if has_profile else '',
            'national_id': (
                item.user.profile.national_id if has_profile else ''
            ),
        },
        'campaign': {
            'id': item.campaign.id,
            'title': item.campaign.title,
        },
    }


def serialize_press_release(request, release):
    return {
        'id': release.id,
        'title': release.title,
        'body': release.body,
        'image': get_image_url(request, release.image),
        'date_published': release.date_published.isoformat(),
        'is_published': release.is_published,
    }


def update_image_field(instance, request, field_name='image'):
    new_image = request.FILES.get(field_name)
    image_field = getattr(instance, field_name)
    if new_image:
        if image_field:
            image_field.delete(save=False)
        setattr(instance, field_name, new_image)
    elif parse_bool(request.data.get('remove_image'), False):
        if image_field:
            image_field.delete(save=False)
            setattr(instance, field_name, None)


@api_view(['GET', 'POST'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_news_collection(request):
    if request.method == 'GET':
        articles = NewsArticle.objects.all().order_by(
            '-date_published', '-id'
        )

        category = request.query_params.get('category')
        if category:
            articles = articles.filter(category=category.upper())

        breaking = request.query_params.get('breaking')
        if breaking is not None:
            articles = articles.filter(
                is_breaking=parse_bool(breaking)
            )

        return Response({
            'items': [
                serialize_article(request, item) for item in articles
            ]
        })

    title = request.data.get('title', '').strip()
    body = request.data.get('body', '').strip()
    category = request.data.get('category', 'NEWS').strip().upper()

    if not title or not body:
        return Response(
            {'error': 'Title and body are required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    article = NewsArticle.objects.create(
        title=title,
        body=body,
        category=category,
        is_published=parse_bool(request.data.get('is_published'), True),
        is_breaking=parse_bool(request.data.get('is_breaking'), False),
        image=request.FILES.get('image'),
    )

    notify_if_breaking_or_alert(article, was_notify_worthy=False)

    return Response(
        {'item': serialize_article(request, article)},
        status=status.HTTP_201_CREATED,
    )


@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_news_detail(request, article_id):
    try:
        article = NewsArticle.objects.get(pk=article_id)
    except NewsArticle.DoesNotExist:
        return Response(
            {'error': 'Content not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if request.method == 'GET':
        return Response({'item': serialize_article(request, article)})

    if request.method == 'DELETE':
        if article.image:
            article.image.delete(save=False)
        article.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    was_notify_worthy = _is_notify_worthy(article)

    title = request.data.get('title')
    body = request.data.get('body')
    category = request.data.get('category')

    if title is not None:
        article.title = title.strip()
    if body is not None:
        article.body = body.strip()
    if category:
        article.category = category.strip().upper()

    if 'is_published' in request.data:
        article.is_published = parse_bool(
            request.data.get('is_published')
        )
    if 'is_breaking' in request.data:
        article.is_breaking = parse_bool(
            request.data.get('is_breaking')
        )

    new_image = request.FILES.get('image')
    if new_image:
        if article.image:
            article.image.delete(save=False)
        article.image = new_image
    elif parse_bool(request.data.get('remove_image'), False):
        if article.image:
            article.image.delete(save=False)
            article.image = None

    article.save()
    notify_if_breaking_or_alert(article, was_notify_worthy=was_notify_worthy)
    return Response({'item': serialize_article(request, article)})


@api_view(['GET', 'POST'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_events_collection(request):
    if request.method == 'GET':
        items = Event.objects.all().order_by('-event_date', '-id')
        return Response({
            'items': [serialize_event(request, item) for item in items]
        })

    title = request.data.get('title', '').strip()
    description = request.data.get('description', '').strip()
    event_date = request.data.get('event_date', '').strip()

    if not title or not description or not event_date:
        return Response(
            {
                'error': (
                    'Title, description, and event date are required.'
                )
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    item = Event.objects.create(
        title=title,
        description=description,
        location=request.data.get('location', '').strip(),
        latitude=parse_coord(request.data.get('latitude')),
        longitude=parse_coord(request.data.get('longitude')),
        event_date=event_date,
        end_date=request.data.get('end_date') or None,
        start_time=request.data.get('start_time') or None,
        end_time=request.data.get('end_time') or None,
        image=request.FILES.get('image'),
        is_published=parse_bool(request.data.get('is_published'), True),
    )
    # Re-fetch from the database so event_date/end_date come back as
    # real date objects (Django only converts them on read, not on
    # the in-memory instance right after .create()).
    item.refresh_from_db()
    return Response(
        {'item': serialize_event(request, item)},
        status=status.HTTP_201_CREATED,
    )


@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_event_detail(request, event_id):
    try:
        item = Event.objects.get(pk=event_id)
    except Event.DoesNotExist:
        return Response(
            {'error': 'Event not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if request.method == 'GET':
        return Response({'item': serialize_event(request, item)})

    if request.method == 'DELETE':
        if item.image:
            item.image.delete(save=False)
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    for field in ['title', 'description', 'location']:
        if field in request.data:
            setattr(item, field, request.data.get(field, '').strip())

    if 'latitude' in request.data:
        item.latitude = parse_coord(request.data.get('latitude'))
    if 'longitude' in request.data:
        item.longitude = parse_coord(request.data.get('longitude'))

    if 'event_date' in request.data:
        item.event_date = request.data.get('event_date') or item.event_date
    if 'end_date' in request.data:
        item.end_date = request.data.get('end_date') or None
    if 'start_time' in request.data:
        item.start_time = request.data.get('start_time') or None
    if 'end_time' in request.data:
        item.end_time = request.data.get('end_time') or None
    if 'is_published' in request.data:
        item.is_published = parse_bool(request.data.get('is_published'))

    update_image_field(item, request)
    item.save()
    # Same fix as create: re-fetch so event_date/end_date come back
    # as real date objects instead of the raw strings just assigned.
    item.refresh_from_db()
    return Response({'item': serialize_event(request, item)})


@api_view(['GET', 'POST'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_campaigns_collection(request):
    if request.method == 'GET':
        items = Campaign.objects.all().order_by('-start_date', '-id')
        return Response({
            'items': [
                serialize_campaign(request, item) for item in items
            ]
        })

    title = request.data.get('title', '').strip()
    description = request.data.get('description', '').strip()
    start_date = request.data.get('start_date', '').strip()

    if not title or not description or not start_date:
        return Response(
            {
                'error': (
                    'Title, description, and start date are required.'
                )
            },
            status=status.HTTP_400_BAD_REQUEST,
        )

    item = Campaign.objects.create(
        title=title,
        description=description,
        start_date=start_date,
        end_date=request.data.get('end_date') or None,
        image=request.FILES.get('image'),
        target_audience=request.data.get('target_audience', '').strip(),
        location=request.data.get('location', '').strip(),
        latitude=parse_coord(request.data.get('latitude')),
        longitude=parse_coord(request.data.get('longitude')),
        category=request.data.get('category', 'OTHER').strip().upper(),
        is_published=parse_bool(request.data.get('is_published'), True),
    )
    # Same date-serialization fix as Event: force a re-read from the
    # database so start_date/end_date are real date objects.
    item.refresh_from_db()
    return Response(
        {'item': serialize_campaign(request, item)},
        status=status.HTTP_201_CREATED,
    )


@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_campaign_detail(request, campaign_id):
    try:
        item = Campaign.objects.get(pk=campaign_id)
    except Campaign.DoesNotExist:
        return Response(
            {'error': 'Campaign not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if request.method == 'GET':
        related_news = item.related_news.select_related('article').all()
        return Response({
            'item': serialize_campaign(request, item),
            'gallery': [
                serialize_campaign_gallery(request, entry)
                for entry in item.gallery.all()
            ],
            'schedule': [
                serialize_campaign_schedule(entry)
                for entry in item.schedule.all()
            ],
            'speakers': [
                serialize_campaign_speaker(request, entry)
                for entry in item.speakers.all()
            ],
            'related_news': [
                serialize_campaign_news(entry) for entry in related_news
            ],
            'available_news': [
                {
                    'id': article.id,
                    'title': article.title,
                    'category': article.category,
                }
                for article in NewsArticle.objects.all().order_by(
                    '-date_published'
                )[:100]
            ],
        })

    if request.method == 'DELETE':
        if item.image:
            item.image.delete(save=False)
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    for field in ['title', 'description', 'target_audience', 'location']:
        if field in request.data:
            setattr(item, field, request.data.get(field, '').strip())

    if 'latitude' in request.data:
        item.latitude = parse_coord(request.data.get('latitude'))
    if 'longitude' in request.data:
        item.longitude = parse_coord(request.data.get('longitude'))

    if 'start_date' in request.data:
        item.start_date = request.data.get('start_date') or item.start_date
    if 'end_date' in request.data:
        item.end_date = request.data.get('end_date') or None
    if 'category' in request.data:
        item.category = request.data.get('category', 'OTHER').strip().upper()
    if 'is_published' in request.data:
        item.is_published = parse_bool(request.data.get('is_published'))

    update_image_field(item, request)
    item.save()
    item.refresh_from_db()
    return Response({'item': serialize_campaign(request, item)})


@api_view(['POST'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_campaign_gallery_create(request, campaign_id):
    try:
        campaign = Campaign.objects.get(pk=campaign_id)
    except Campaign.DoesNotExist:
        return Response(
            {'error': 'Campaign not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    image = request.FILES.get('image')
    if not image:
        return Response(
            {'error': 'Image is required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    item = CampaignGallery.objects.create(
        campaign=campaign,
        image=image,
        caption=request.data.get('caption', '').strip(),
        order=int(request.data.get('order') or 0),
    )
    return Response(
        {'item': serialize_campaign_gallery(request, item)},
        status=status.HTTP_201_CREATED,
    )


@api_view(['PUT', 'DELETE'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_campaign_gallery_detail(request, gallery_id):
    try:
        item = CampaignGallery.objects.get(pk=gallery_id)
    except CampaignGallery.DoesNotExist:
        return Response(
            {'error': 'Gallery item not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if request.method == 'DELETE':
        if item.image:
            item.image.delete(save=False)
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    item.caption = request.data.get('caption', item.caption).strip()
    item.order = int(request.data.get('order') or item.order)
    update_image_field(item, request)
    item.save()
    return Response({'item': serialize_campaign_gallery(request, item)})


@api_view(['POST'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
def admin_campaign_schedule_create(request, campaign_id):
    try:
        campaign = Campaign.objects.get(pk=campaign_id)
    except Campaign.DoesNotExist:
        return Response(
            {'error': 'Campaign not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    item = CampaignSchedule.objects.create(
        campaign=campaign,
        week_number=int(request.data.get('week_number') or 1),
        day=request.data.get('day', '').strip(),
        start_time=request.data.get('start_time'),
        end_time=request.data.get('end_time') or None,
        session_title=request.data.get('session_title', '').strip(),
        speaker=request.data.get('speaker', '').strip(),
        venue=request.data.get('venue', '').strip(),
    )
    return Response(
        {'item': serialize_campaign_schedule(item)},
        status=status.HTTP_201_CREATED,
    )


@api_view(['PUT', 'DELETE'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
def admin_campaign_schedule_detail(request, schedule_id):
    try:
        item = CampaignSchedule.objects.get(pk=schedule_id)
    except CampaignSchedule.DoesNotExist:
        return Response(
            {'error': 'Schedule item not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if request.method == 'DELETE':
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    item.week_number = int(
        request.data.get('week_number') or item.week_number
    )
    item.day = request.data.get('day', item.day).strip()
    item.start_time = request.data.get('start_time') or item.start_time
    item.end_time = request.data.get('end_time') or None
    item.session_title = request.data.get(
        'session_title', item.session_title
    ).strip()
    item.speaker = request.data.get('speaker', item.speaker).strip()
    item.venue = request.data.get('venue', item.venue).strip()
    item.save()
    return Response({'item': serialize_campaign_schedule(item)})


@api_view(['POST'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_campaign_speaker_create(request, campaign_id):
    try:
        campaign = Campaign.objects.get(pk=campaign_id)
    except Campaign.DoesNotExist:
        return Response(
            {'error': 'Campaign not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    item = CampaignSpeaker.objects.create(
        campaign=campaign,
        name=request.data.get('name', '').strip(),
        title=request.data.get('title', '').strip(),
        organisation=request.data.get('organisation', '').strip(),
        bio=request.data.get('bio', '').strip(),
        photo=request.FILES.get('photo'),
        order=int(request.data.get('order') or 0),
    )
    return Response(
        {'item': serialize_campaign_speaker(request, item)},
        status=status.HTTP_201_CREATED,
    )


@api_view(['PUT', 'DELETE'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_campaign_speaker_detail(request, speaker_id):
    try:
        item = CampaignSpeaker.objects.get(pk=speaker_id)
    except CampaignSpeaker.DoesNotExist:
        return Response(
            {'error': 'Speaker item not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if request.method == 'DELETE':
        if item.photo:
            item.photo.delete(save=False)
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    for field in ['name', 'title', 'organisation', 'bio']:
        if field in request.data:
            setattr(item, field, request.data.get(field, '').strip())
    item.order = int(request.data.get('order') or item.order)
    update_image_field(item, request, 'photo')
    item.save()
    return Response({'item': serialize_campaign_speaker(request, item)})


@api_view(['POST'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
def admin_campaign_news_create(request, campaign_id):
    try:
        campaign = Campaign.objects.get(pk=campaign_id)
    except Campaign.DoesNotExist:
        return Response(
            {'error': 'Campaign not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    article_id = request.data.get('article_id')
    if not article_id:
        return Response(
            {'error': 'Article id is required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    item, _ = CampaignNews.objects.get_or_create(
        campaign=campaign, article_id=article_id
    )
    return Response(
        {'item': serialize_campaign_news(item)},
        status=status.HTTP_201_CREATED,
    )


@api_view(['DELETE'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
def admin_campaign_news_detail(request, related_news_id):
    try:
        item = CampaignNews.objects.get(pk=related_news_id)
    except CampaignNews.DoesNotExist:
        return Response(
            {'error': 'Related news item not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )
    item.delete()
    return Response(status=status.HTTP_204_NO_CONTENT)


@api_view(['GET'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
def admin_event_registrations(request, event_id):
    items = EventRegistration.objects.select_related(
        'user', 'user__profile', 'event'
    ).filter(event_id=event_id)
    return Response({
        'registrations': [
            serialize_registration(item) for item in items
        ]
    })


@api_view(['GET'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
def admin_campaign_registrations(request, campaign_id):
    items = CampaignRegistration.objects.select_related(
        'user', 'user__profile', 'campaign'
    ).filter(campaign_id=campaign_id)
    return Response({
        'registrations': [
            serialize_campaign_registration(item) for item in items
        ]
    })


@api_view(['POST'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
def admin_campaign_check_in(request, campaign_id):
    raw_code = request.data.get('check_in_code') or ''
    check_in_code = raw_code.strip().upper()

    if not check_in_code:
        return Response(
            {'error': 'Check-in code is required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        registration = CampaignRegistration.objects.select_related(
            'user', 'user__profile', 'campaign'
        ).get(campaign_id=campaign_id, check_in_code=check_in_code)
    except CampaignRegistration.DoesNotExist:
        return Response(
            {'error': 'No registration found for that code.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if registration.checked_in:
        return Response({
            'message': 'This code has already been checked in.',
            'already_checked_in': True,
            'item': serialize_campaign_registration(registration),
        }, status=status.HTTP_200_OK)

    registration.checked_in = True
    registration.checked_in_at = timezone.now()
    registration.save(update_fields=['checked_in', 'checked_in_at'])

    return Response({
        'message': 'Checked in successfully.',
        'already_checked_in': False,
        'item': serialize_campaign_registration(registration),
    }, status=status.HTTP_200_OK)


@api_view(['GET', 'POST'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_press_collection(request):
    if request.method == 'GET':
        items = PressRelease.objects.all().order_by(
            '-date_published', '-id'
        )
        return Response({
            'items': [
                serialize_press_release(request, item) for item in items
            ]
        })

    title = request.data.get('title', '').strip()
    body = request.data.get('body', '').strip()

    if not title or not body:
        return Response(
            {'error': 'Title and body are required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    item = PressRelease.objects.create(
        title=title,
        body=body,
        image=request.FILES.get('image'),
        is_published=parse_bool(request.data.get('is_published'), True),
    )
    return Response(
        {'item': serialize_press_release(request, item)},
        status=status.HTTP_201_CREATED,
    )


@api_view(['GET', 'PUT', 'DELETE'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_press_detail(request, release_id):
    try:
        item = PressRelease.objects.get(pk=release_id)
    except PressRelease.DoesNotExist:
        return Response(
            {'error': 'Press release not found.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if request.method == 'GET':
        return Response({'item': serialize_press_release(request, item)})

    if request.method == 'DELETE':
        if item.image:
            item.image.delete(save=False)
        item.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)

    if 'title' in request.data:
        item.title = request.data.get('title', '').strip()
    if 'body' in request.data:
        item.body = request.data.get('body', '').strip()
    if 'is_published' in request.data:
        item.is_published = parse_bool(request.data.get('is_published'))

    update_image_field(item, request)
    item.save()
    return Response({'item': serialize_press_release(request, item)})


# ============================================================
# RECEPTIONIST CHECK-IN
# Receptionist types a visitor's check-in code into the admin
# web app; this looks it up against the given event and marks
# the registration as checked in.
# ============================================================

@api_view(['POST'])
@permission_classes([IsCOMMSOrITOrSuperAdmin])
def admin_check_in_registration(request, event_id):
    raw_code = request.data.get('check_in_code') or ''
    check_in_code = raw_code.strip().upper()

    if not check_in_code:
        return Response(
            {'error': 'Check-in code is required.'},
            status=status.HTTP_400_BAD_REQUEST,
        )

    try:
        registration = EventRegistration.objects.select_related(
            'user', 'user__profile', 'event'
        ).get(event_id=event_id, check_in_code=check_in_code)
    except EventRegistration.DoesNotExist:
        return Response(
            {'error': 'No registration found for that code.'},
            status=status.HTTP_404_NOT_FOUND,
        )

    if registration.checked_in:
        return Response({
            'message': 'This code has already been checked in.',
            'already_checked_in': True,
            'item': serialize_registration(registration),
        }, status=status.HTTP_200_OK)

    registration.checked_in = True
    registration.checked_in_at = timezone.now()
    registration.save(update_fields=['checked_in', 'checked_in_at'])

    return Response({
        'message': 'Checked in successfully.',
        'already_checked_in': False,
        'item': serialize_registration(registration),
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsITOrSuperAdmin])
def admin_content_dashboard(request):
    today = timezone.now().date()

    content_mix_counts = [
        {'key': 'News & Alerts', 'count': NewsArticle.objects.count()},
        {'key': 'Events', 'count': Event.objects.count()},
        {'key': 'Campaigns', 'count': Campaign.objects.count()},
        {'key': 'Press Releases', 'count': PressRelease.objects.count()},
    ]
    content_mix_total = sum(row['count'] for row in content_mix_counts)

    article_category_counts = (
        NewsArticle.objects.values('category')
        .annotate(count=Count('id'))
        .order_by('-count')
    )

    return Response({
        'stats': {
            'published_articles_count': NewsArticle.objects.filter(is_published=True).count(),
            'breaking_news_count': NewsArticle.objects.filter(is_breaking=True).count(),
            'upcoming_events_count': Event.objects.filter(
                is_published=True, event_date__gte=today
            ).count(),
            'active_campaigns_count': Campaign.objects.filter(
                is_published=True
            ).filter(
                Q(end_date__isnull=True) | Q(end_date__gte=today)
            ).count(),
        },
        'charts': {
            'content_mix': [
                {'label': row['key'], 'value': row['count']}
                for row in content_mix_counts
            ],
            'content_type_pie': [
                {
                    'label': row['key'],
                    'value': row['count'],
                    'percentage': round((row['count'] / content_mix_total) * 100, 1) if content_mix_total else 0,
                }
                for row in content_mix_counts
            ],
            'article_category_mix': [
                {'label': row['category'], 'value': row['count']}
                for row in article_category_counts
            ],
        },
    })


# ============================================================
# ABOUT / CONTACT PAGE CONTENT
# Singletons — exactly one row each, get_or_create'd on first access
# so there's always something to edit and nothing to "create new" of.
# ============================================================

def serialize_about_page(request, about):
    data = {
        'id': about.id,
        'intro_paragraph_1': about.intro_paragraph_1,
        'intro_paragraph_2': about.intro_paragraph_2,
        'image': get_image_url(request, about.image),
        'mandate_text': about.mandate_text,
        'mission_text': about.mission_text,
        'vision_text': about.vision_text,
    }
    for i in range(1, 7):
        data[f'value_{i}_title'] = getattr(about, f'value_{i}_title')
        data[f'value_{i}_description'] = getattr(
            about, f'value_{i}_description'
        )
    return data


@api_view(['GET', 'PUT'])
@permission_classes([IsITOrSuperAdmin])
@parser_classes([MultiPartParser, FormParser, JSONParser])
def admin_about_page(request):
    about, _ = AboutPageContent.objects.get_or_create(pk=1)

    if request.method == 'GET':
        return Response({'item': serialize_about_page(request, about)})

    text_fields = [
        'intro_paragraph_1', 'intro_paragraph_2',
        'mandate_text', 'mission_text', 'vision_text',
    ] + [
        f'value_{i}_{part}'
        for i in range(1, 7)
        for part in ('title', 'description')
    ]
    for field in text_fields:
        if field in request.data:
            setattr(about, field, request.data.get(field, ''))

    update_image_field(about, request)
    about.save()
    return Response({'item': serialize_about_page(request, about)})


def serialize_contact_page(request, contact):
    return {
        'id': contact.id,
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


@api_view(['GET', 'PUT'])
@permission_classes([IsITOrSuperAdmin])
def admin_contact_page(request):
    contact, _ = ContactPageContent.objects.get_or_create(pk=1)

    if request.method == 'GET':
        return Response({'item': serialize_contact_page(request, contact)})

    string_fields = [
        'office_address', 'phone', 'emergency_hotline', 'email',
        'whatsapp_channel_url', 'twitter_url', 'instagram_url',
        'linkedin_url', 'facebook_url',
    ]
    for field in string_fields:
        if field in request.data:
            setattr(contact, field, request.data.get(field, ''))

    if 'latitude' in request.data:
        try:
            contact.latitude = float(request.data.get('latitude'))
        except (TypeError, ValueError):
            pass
    if 'longitude' in request.data:
        try:
            contact.longitude = float(request.data.get('longitude'))
        except (TypeError, ValueError):
            pass

    contact.save()
    return Response({'item': serialize_contact_page(request, contact)})