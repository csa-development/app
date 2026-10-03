"""Public, unauthenticated HTML pages for shared links.

These exist so a link shared out of the app (WhatsApp, SMS, etc.) has
somewhere real to land when opened by someone who doesn't have the app
installed — Android/iOS App Links open the app directly when it *is*
installed, and only fall through to these pages otherwise.
"""
from django.http import Http404, JsonResponse
from django.shortcuts import render

from csa_shared_models.content.models import (
    Campaign,
    Event,
    NewsArticle,
    PressRelease,
)

from .views import get_image_url


def _render_article(request, *, eyebrow, title, subtitle, body, image):
    return render(request, 'content/public_article.html', {
        'eyebrow': eyebrow,
        'title': title,
        'subtitle': subtitle,
        'body': body,
        'image_url': get_image_url(request, image),
        'og_description': (body or '')[:200],
    })


def news_public_detail(request, news_id):
    try:
        article = NewsArticle.objects.get(id=news_id, is_published=True)
    except NewsArticle.DoesNotExist:
        raise Http404('Article not found')

    return _render_article(
        request,
        eyebrow=article.get_category_display(),
        title=article.title,
        subtitle=article.date_published.strftime('%B %d, %Y'),
        body=article.body,
        image=article.image,
    )


def event_public_detail(request, event_id):
    try:
        event = Event.objects.get(id=event_id, is_published=True)
    except Event.DoesNotExist:
        raise Http404('Event not found')

    subtitle = f"{event.event_date.strftime('%B %d, %Y')} · {event.location}"
    return _render_article(
        request,
        eyebrow='Event',
        title=event.title,
        subtitle=subtitle,
        body=event.description,
        image=event.image,
    )


def campaign_public_detail(request, campaign_id):
    try:
        campaign = Campaign.objects.get(id=campaign_id, is_published=True)
    except Campaign.DoesNotExist:
        raise Http404('Campaign not found')

    return _render_article(
        request,
        eyebrow=campaign.get_category_display(),
        title=campaign.title,
        subtitle=campaign.start_date.strftime('%B %d, %Y'),
        body=campaign.description,
        image=campaign.image,
    )


def press_release_public_detail(request, release_id):
    try:
        release = PressRelease.objects.get(id=release_id, is_published=True)
    except PressRelease.DoesNotExist:
        raise Http404('Press release not found')

    return _render_article(
        request,
        eyebrow='Press Release',
        title=release.title,
        subtitle=release.date_published.strftime('%B %d, %Y'),
        body=release.body,
        image=release.image,
    )


# Android App Links verification file
# (served at /.well-known/assetlinks.json, per Google's spec).
#
# TODO: 'sha256_cert_fingerprints' below is a placeholder. Replace it with
# the real SHA-256 fingerprint of the certificate the release APK is
# actually signed with (currently the app is still signed with the debug
# key — see android/app/build.gradle.kts — so there is no real production
# fingerprint yet). Get it with:
#   keytool -list -v -keystore <your-release-keystore> -alias <alias>
# This file also needs to actually be reachable at
# https://csa.gov.gh/.well-known/assetlinks.json in production for
# Android to trust it — i.e. csa.gov.gh (or a subdomain) needs to be
# pointed at wherever this Django process is actually deployed.
def android_asset_links(request):
    return JsonResponse([
        {
            'relation': ['delegate_permission/common.handle_all_urls'],
            'target': {
                'namespace': 'android_app',
                'package_name': 'gh.gov.csa.app',
                'sha256_cert_fingerprints': [
                    'REPLACE_WITH_REAL_RELEASE_SHA256_FINGERPRINT',
                ],
            },
        }
    ], safe=False)
