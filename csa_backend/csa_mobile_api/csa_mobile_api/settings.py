from pathlib import Path
from datetime import timedelta
import os
from dotenv import load_dotenv

# BASE_DIR = csa_mobile_api/ (this project's own root, NOT csa_backend/)
BASE_DIR = Path(__file__).resolve().parent.parent

# SHARED_ROOT = csa_backend/ — the parent that holds both sibling projects
# plus the one shared media folder both processes read/write against.
SHARED_ROOT = BASE_DIR.parent

load_dotenv(BASE_DIR / '.env')

# SECURITY: defaults to False. Turning on DEBUG must be a deliberate
# opt-in (DEBUG=True in .env), never the result of a missing var.
DEBUG = os.environ.get('DEBUG', 'False') == 'True'

# Own, independent SECRET_KEY — must never be the same value as
# csa_admin_api's or the original csa_project's. A JWT signed with this
# key is only ever meant to be validated by this process.
_INSECURE_FALLBACK_KEY = (
    'django-insecure-mobile-fallback-key-do-not-use-in-prod-CHANGE-ME'
)
SECRET_KEY = os.environ.get('SECRET_KEY', _INSECURE_FALLBACK_KEY)

# SECURITY: the fallback key is committed to the repo — running on it
# means citizen JWTs can be forged. Only a DEBUG dev box may use it.
if SECRET_KEY == _INSECURE_FALLBACK_KEY and not DEBUG:
    raise RuntimeError(
        'No real SECRET_KEY in the environment (and DEBUG is not on). '
        'Set SECRET_KEY in csa_mobile_api/.env before running this.'
    )

# Scoped to the mobile app's own hosts only — this project should never
# be reachable at the admin console's hostname.
_default_hosts = '127.0.0.1,localhost,10.0.2.2,172.20.10.2'
ALLOWED_HOSTS = [
    h.strip()
    for h in os.environ.get('ALLOWED_HOSTS', _default_hosts).split(',')
    if h.strip()
]

INSTALLED_APPS = [
    # Deliberately NOT including django.contrib.admin,
    # django.contrib.messages, or django.contrib.staticfiles' admin
    # assets here: this process is citizen-facing only and must never
    # expose Django's built-in staff CMS, even if this process is fully
    # compromised. That site only lives in csa_admin_api.
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.staticfiles',  # kept only so DRF's browsable API
                                    # renders correctly in dev (DEBUG=True)
    'rest_framework',
    # Shared model/migration source of truth. This project OWNS the real
    # migrations for these apps (see Part 6 of the split doc) — never run
    # `migrate` for these from csa_admin_api.
    'csa_shared_models.accounts.apps.AccountsConfig',
    'csa_shared_models.content.apps.ContentConfig',
    'csa_shared_models.incidents.apps.IncidentsConfig',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'csa_mobile_api.urls'

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
            ],
        },
    },
]

WSGI_APPLICATION = 'csa_mobile_api.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'csa_db'),
        # mobile_api_user: scoped SELECT/INSERT/UPDATE only on the tables
        # this process legitimately needs. See db_setup/01_roles_and_grants.sql.
        'USER': os.environ.get('DB_USER'),
        'PASSWORD': os.environ.get('DB_PASSWORD'),
        'HOST': os.environ.get('DB_HOST', 'localhost'),
        'PORT': os.environ.get('DB_PORT', '5432'),
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {'NAME': 'django.contrib.auth.password_validation.UserAttributeSimilarityValidator'},
    {'NAME': 'django.contrib.auth.password_validation.MinimumLengthValidator'},
    {'NAME': 'django.contrib.auth.password_validation.CommonPasswordValidator'},
    {'NAME': 'django.contrib.auth.password_validation.NumericPasswordValidator'},
]

# Backs the per-account OTP wrong-code lockout. FileBasedCache so the
# counter is shared across gunicorn workers on the same host (the
# default LocMemCache is per-process, which would multiply every limit
# by the worker count). Point at Redis for multi-host.
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.filebased.FileBasedCache',
        'LOCATION': os.environ.get(
            'CACHE_DIR', str(BASE_DIR / '.django_cache')
        ),
    }
}

# Rancard bulk-SMS credentials — set in csa_mobile_api/.env, never
# hardcoded. If unset, SMS OTP is skipped and email OTP is used.
RANCARD_SMS_API_KEY = os.environ.get('RANCARD_SMS_API_KEY', '')

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'
# Project-level static assets (not tied to any one installed app) —
# currently just the public Terms of Service page. Without this,
# Django's default AppDirectoriesFinder only looks inside each
# INSTALLED_APPS app's own static/ folder, and this project's own
# top-level static/ directory would be silently ignored by
# `collectstatic`.
STATICFILES_DIRS = [BASE_DIR / 'static']

# One shared media directory on disk for both processes — admin uploads,
# mobile reads. Not duplicated per project; this is not a database split
# and it isn't a file-storage split either.
MEDIA_URL = '/media/'
MEDIA_ROOT = SHARED_ROOT / 'shared_media'

# Used by csa_shared_models.accounts.push for sending FCM notifications.
# Was previously a machine-specific absolute path hardcoded inside the
# signal itself (C:/Users/user/Desktop/...), which silently failed on
# any other machine — the failure was swallowed by a broad except and
# never surfaced. Now settings-driven with a default that matches
# where the file actually lives on disk today.
FIREBASE_SERVICE_ACCOUNT_FILE = os.environ.get(
    'FIREBASE_SERVICE_ACCOUNT_FILE',
    str(SHARED_ROOT / 'csa_project' / 'firebase-adminsdk.json'),
)

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    # No restrictive DEFAULT_PERMISSION_CLASSES here on purpose: this
    # process has many deliberately-public DRF endpoints (news, events,
    # certificate verification, the contact form). Every endpoint that
    # needs a login already carries @permission_classes([IsAuthenticated])
    # explicitly — audited.
}

if not DEBUG:
    # JSON only. Without this, a browser hitting any endpoint gets DRF's
    # HTML "browsable API" page — it lists methods/parameters and is a
    # standard pentest finding on a deployed API.
    REST_FRAMEWORK['DEFAULT_RENDERER_CLASSES'] = (
        'rest_framework.renderers.JSONRenderer',
    )

# JWTs minted here are only ever meant to be validated by this same
# process (its own SECRET_KEY). csa_admin_api has its own SIMPLE_JWT
# using its own SECRET_KEY, so a mobile-user token is structurally
# rejected if presented to the admin API, and vice versa.
SIMPLE_JWT = {
    # Short access token; the phone refreshes silently. A leaked token
    # is good for 30 min, not a day.
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=30),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=3),
    'AUTH_HEADER_TYPES': ('Bearer',),
}

# Refresh-token revocation (logout / password change / rotation with
# reuse detection). Needs the token_blacklist tables, which only
# csa_migrator can create — so it is OPT-IN via env until that migration
# (and db_setup/02_token_blacklist_grants.sql) has been applied. With it
# on but the tables missing, every login would 500. run_mobile_https.ps1
# checks for the tables before starting with this on.
ENABLE_TOKEN_BLACKLIST = os.environ.get('ENABLE_TOKEN_BLACKLIST', 'False') == 'True'
if ENABLE_TOKEN_BLACKLIST:
    INSTALLED_APPS.append('rest_framework_simplejwt.token_blacklist')
    SIMPLE_JWT.update({
        # Every refresh hands back a NEW refresh token and kills the old
        # one, so a stolen refresh token stops working as soon as the real
        # app next refreshes (and replaying it is detectable).
        'ROTATE_REFRESH_TOKENS': True,
        'BLACKLIST_AFTER_ROTATION': True,
    })

EMAIL_BACKEND = 'django.core.mail.backends.smtp.EmailBackend'
# ZeptoMail SMTP relay (EU region — matches the api.zeptomail.eu
# account this project was moved to). Was SendGrid before this, and
# Microsoft 365 direct-mailbox (noreply.mobile@csa.gov.gh) before
# that — that tenant has SMTP AUTH (basic auth) disabled org-wide, a
# Microsoft security policy change, not something fixable on our end.
# ZeptoMail's username is always the literal word "emailapikey"; the
# actual identity/permissions live in the password (the SMTP token)
# instead, which is why DEFAULT_FROM_EMAIL below is a separate
# constant rather than derived from EMAIL_HOST_USER. Note: ZeptoMail
# also enforces that the From address be a verified/allowed sender on
# the account, or it rejects with "553 Relaying disallowed" — confirm
# noreply.mobile@csa.gov.gh is added as an allowed sender/alias in the
# ZeptoMail dashboard, not just that csa.gov.gh the domain is verified.
EMAIL_HOST = 'smtp.zeptomail.eu'
EMAIL_PORT = 587
EMAIL_USE_TLS = True
EMAIL_USE_SSL = False
EMAIL_HOST_USER = os.environ.get('EMAIL_HOST_USER', '')
EMAIL_HOST_PASSWORD = os.environ.get('EMAIL_HOST_PASSWORD', '')
DEFAULT_FROM_EMAIL = 'CSA Notifications <noreply.mobile@csa.gov.gh>'

# Unset by default, meaning Django will wait as long as the OS allows
# on a slow/stalled SMTP connection — confirmed to actually hang for
# minutes on a slow first connection after a network change (same
# class of issue already fixed for SMS). This caps every email send
# anywhere in the app to a sane wait, so a slow handshake fails fast
# instead of blowing past the mobile app's own 15s request timeout.
EMAIL_TIMEOUT = 10

if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
