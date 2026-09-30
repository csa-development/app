from pathlib import Path
from datetime import timedelta
import os
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent

# Load variables from .env (kept out of Git via .gitignore)
load_dotenv(BASE_DIR / '.env')

DEBUG = os.environ.get('DEBUG', 'True') == 'True'

# ============================================================
# SECRET_KEY
#
# The hardcoded fallback below is fine for quick local dev, but
# NEVER acceptable once DEBUG=False (i.e. once this is actually
# deployed). This now hard-fails on startup if DEBUG=False and
# no real SECRET_KEY was set in .env — better to crash loudly at
# boot than silently run production on an exposed, guessable key.
# ============================================================
_INSECURE_FALLBACK_KEY = (
    'django-insecure-g$7zbge8)7zxrb7%j21j)m=7$_eo3p)!w@k*u-%xjs-c9x(j7o'
)
SECRET_KEY = os.environ.get('SECRET_KEY', _INSECURE_FALLBACK_KEY)

if not DEBUG and SECRET_KEY == _INSECURE_FALLBACK_KEY:
    raise RuntimeError(
        'DEBUG is False but no real SECRET_KEY was found in the '
        'environment. Set SECRET_KEY in your .env before deploying.'
    )

# ============================================================
# ALLOWED_HOSTS
#
# Reads from .env as a comma-separated list (ALLOWED_HOSTS in
# .env, e.g. "csa.gov.gh,www.csa.gov.gh"), so adding your real
# production domain later is a .env change, not a code change +
# redeploy. Falls back to your current dev/testing IPs if nothing
# is set, so this doesn't break your local/UAT workflow today.
#
# NOTE: your local network IP changes fairly often (router/hotspot
# reassigns it). Rather than editing this file every time, it's
# easier to add ALLOWED_HOSTS=<your current ip> to your .env —
# .env always wins over this default list, and .env isn't tracked
# in Git, so you can update it freely without touching code.
# ============================================================
_default_hosts = (
    '127.0.0.1,localhost,10.0.2.2,172.20.10.2,'
    '192.168.31.58,10.255.26.252'
)
ALLOWED_HOSTS = [
    h.strip()
    for h in os.environ.get('ALLOWED_HOSTS', _default_hosts).split(',')
    if h.strip()
]

INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'incidents.apps.IncidentsConfig',
    'accounts',
    'content',
    'rest_framework',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    # WhiteNoise serves static files directly from Django even with
    # DEBUG=False, so your admin panel (and anything else using
    # STATIC_URL) doesn't break the moment DEBUG flips off — this
    # covers you until real Nginx-based deployment happens.
    # Requires: pip install whitenoise
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'csa_project.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

WSGI_APPLICATION = 'csa_project.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'csa_db'),
        'USER': os.environ.get('DB_USER', 'csa_user'),
        'PASSWORD': os.environ.get('DB_PASSWORD', ''),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {
        'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator',
    },
    {
        'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator',
    },
]

LANGUAGE_CODE = 'en-us'

TIME_ZONE = 'UTC'

USE_I18N = True

USE_TZ = True

STATIC_URL = 'static/'

# STATIC_ROOT is where `manage.py collectstatic` gathers every
# static file into one place for production serving. This didn't
# exist before — without it, `collectstatic` has nowhere to put
# files, and WhiteNoise (above) has nothing to serve once
# DEBUG=False.
STATIC_ROOT = BASE_DIR / 'staticfiles'

# Compresses and fingerprints static files for production, and
# lets WhiteNoise serve them efficiently without Nginx.
STATICFILES_STORAGE = (
    'whitenoise.storage.CompressedManifestStaticFilesStorage'
)

MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(days=1),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
    'AUTH_HEADER_TYPES': ('Bearer',),
}

EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
EMAIL_HOST = 'smtp.gmail.com'
EMAIL_PORT = 465
EMAIL_USE_TLS = False
EMAIL_USE_SSL = True
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
DEFAULT_FROM_EMAIL = f'CSA Notifications <{EMAIL_HOST_USER}>'

# ============================================================
# PRODUCTION-ONLY SECURITY SETTINGS
#
# These force HTTPS and lock down cookies — correct for a real
# deployment, but WRONG for your current local/UAT testing over
# plain HTTP on your WiFi IP (they'd make the app unreachable).
# Gated behind `not DEBUG` so they only activate once this is
# actually deployed with DEBUG=False and a real HTTPS domain.
# ============================================================
if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True