import re

from django.conf import settings
from django.http import HttpResponse

_LOCAL_ORIGIN = re.compile(r'^https?://(localhost|127\.0\.0\.1)(:\d+)?$')


class LocalhostCorsMiddleware:
    """Lets the Flutter app running in a browser on this same PC
    (flutter run -d chrome, served from http://localhost:<random port>)
    call this API. Browsers block that unless the server says it's OK.

    Does nothing unless CORS_ALLOW_LOCALHOST=True is set in .env, and even
    then only for localhost / 127.0.0.1 origins — never an arbitrary
    website. Leave it off in any real deployment; phones don't need it."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        origin = request.headers.get('Origin', '')
        allowed = settings.CORS_ALLOW_LOCALHOST and _LOCAL_ORIGIN.match(origin)

        is_preflight = (
            request.method == 'OPTIONS'
            and 'Access-Control-Request-Method' in request.headers
        )
        if allowed and is_preflight:
            response = HttpResponse(status=204)
        else:
            response = self.get_response(request)

        if allowed:
            response['Access-Control-Allow-Origin'] = origin
            response['Access-Control-Allow-Headers'] = 'authorization, content-type'
            response['Access-Control-Allow-Methods'] = 'GET, POST, PUT, PATCH, DELETE, OPTIONS'
            response['Access-Control-Max-Age'] = '600'
            response['Vary'] = 'Origin'
        return response
