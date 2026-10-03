from django.http import Http404
from django.urls import path, re_path, include
from django.conf import settings
from django.views.static import serve
from rest_framework_simplejwt.views import TokenRefreshView

from content.public_views import (
    android_asset_links,
    campaign_public_detail,
    event_public_detail,
    news_public_detail,
    press_release_public_detail,
)

def _evidence_not_public(request):
    raise Http404


# No django.contrib.admin route here on purpose — the built-in Django
# staff CMS only exists in csa_admin_api. This process is citizen-facing
# only.
urlpatterns = [
    path('api/', include('accounts.urls')),
    path('api/incidents/', include('incidents.urls')),
    path('api/content/', include('content.urls')),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    # django.conf.urls.static.static() only works while DEBUG=True, which
    # would 404 every uploaded image on a deployed (DEBUG=False) server.
    # Uploaded media here is public content (event/news images), so the
    # plain serve view is adequate for a pilot; put a real web server /
    # object store in front for a full production rollout.
    # Reporter evidence (incident_evidence/) is sensitive and is never
    # served publicly — CERT staff get it through the admin API only.
    re_path(r'^media/incident_evidence/', _evidence_not_public),
    re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),

    # Public, no-login web pages for links shared out of the app (see
    # content/public_views.py). Android/iOS open the app directly instead
    # of these when the app is installed and App Links/Universal Links
    # are verified; these are the fallback for everyone else.
    path('news/<int:news_id>/', news_public_detail, name='news_public_detail'),
    path('events/<int:event_id>/', event_public_detail, name='event_public_detail'),
    path('campaigns/<int:campaign_id>/', campaign_public_detail, name='campaign_public_detail'),
    path('press/<int:release_id>/', press_release_public_detail, name='press_release_public_detail'),
    path('.well-known/assetlinks.json', android_asset_links, name='android_asset_links'),
]
