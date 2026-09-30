"""ASGI entry point — what the HTTPS launcher (run_mobile_https.ps1) serves
via uvicorn. Same settings/app as wsgi.py, just the async-capable server
interface, which lets uvicorn terminate TLS itself on Windows."""
import os

from django.core.asgi import get_asgi_application

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'csa_mobile_api.settings')

application = get_asgi_application()
