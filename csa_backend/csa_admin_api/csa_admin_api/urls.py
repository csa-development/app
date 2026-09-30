from django.contrib import admin
from django.urls import path, re_path, include
from django.conf import settings
from django.views.static import serve
from rest_framework_simplejwt.views import TokenRefreshView

urlpatterns = [
    # The built-in Django staff CMS. Only exists in this process.
    path('admin/', admin.site.urls),
    path('api/', include('accounts.urls')),
    path('api/incidents/', include('incidents.urls')),
    path('api/content/', include('content.urls')),
    path('api/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    # django.conf.urls.static.static() only works while DEBUG=True, which
    # would 404 every uploaded image on a deployed (DEBUG=False) server.
    # Uploaded media here is public content (event/news images), so the
    # plain serve view is adequate for a pilot; put a real web server /
    # object store in front for a full production rollout.
    re_path(r'^media/(?P<path>.*)$', serve, {'document_root': settings.MEDIA_ROOT}),
]
