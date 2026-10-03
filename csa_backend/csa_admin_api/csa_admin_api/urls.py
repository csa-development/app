from django.contrib import admin
from django.urls import path, re_path, include
from django.conf import settings
from .media_views import serve_evidence, serve_media

urlpatterns = [
    # The built-in Django staff CMS. Only exists in this process.
    path('admin/', admin.site.urls),
    # Reporter evidence: reachable only with a short-lived signed link that
    # the (permission-checked) incident API hands to CERT staff.
    path('api/evidence/<str:token>/', serve_evidence),
    path('api/', include('accounts.urls')),
    path('api/incidents/', include('incidents.urls')),
    path('api/content/', include('content.urls')),
    # django.conf.urls.static.static() only works while DEBUG=True, which
    # would 404 every uploaded image on a deployed (DEBUG=False) server.
    # Uploaded media here is public content (event/news images), so the
    # plain serve view is adequate for a pilot; put a real web server /
    # object store in front for a full production rollout.
    # serve_media = the same serve view plus byte-range support, which
    # browsers need to play uploaded evidence videos.
    re_path(r'^media/(?P<path>.*)$', serve_media, {'document_root': settings.MEDIA_ROOT}),
]
