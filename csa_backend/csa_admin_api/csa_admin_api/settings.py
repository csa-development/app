from pathlib import Path
from datetime import timedelta
import os
from dotenv import load_dotenv

# BASE_DIR = csa_admin_api/ (this project's own root, NOT csa_backend/)
BASE_DIR = Path(__file__).resolve().parent.parent

# SHARED_ROOT = csa_backend/ — the parent that holds both sibling projects
# plus the one shared media folder both processes read/write against.
SHARED_ROOT = BASE_DIR.parent

load_dotenv(BASE_DIR / '.env')

# SECURITY: defaults to False. A deploy must opt IN to DEBUG explicitly
# (DEBUG=True in .env) — forgetting the var can never leave a production
# box with tracebacks + relaxed security on.
DEBUG = os.environ.get('DEBUG', 'False') == 'True'

# Own, independent SECRET_KEY — must never be the same value as
# csa_mobile_api's or the original csa_project's. A JWT signed with this
# key is only ever meant to be validated by this process, so a
# mobile-user token is structurally rejected here even if presented.
_INSECURE_FALLBACK_KEY = (
    'django-insecure-admin-fallback-key-do-not-use-in-prod-CHANGE-ME'
)
SECRET_KEY = os.environ.get('SECRET_KEY', _INSECURE_FALLBACK_KEY)

# SECURITY: the fallback key is public (committed to the repo). Running
# with it means anyone can forge valid admin JWTs. Refuse to start on it
# UNLESS DEBUG is explicitly on — a local dev box may use it, a server
# never can.
if SECRET_KEY == _INSECURE_FALLBACK_KEY and not DEBUG:
    raise RuntimeError(
        'No real SECRET_KEY in the environment (and DEBUG is not on). '
        'Set SECRET_KEY in csa_admin_api/.env before running this.'
    )

# Scoped to the staff console's own hosts only.
_default_hosts = '127.0.0.1,localhost'
ALLOWED_HOSTS = [
    h.strip()
    for h in os.environ.get('ALLOWED_HOSTS', _default_hosts).split(',')
    if h.strip()
]

INSTALLED_APPS = [
    # The built-in Django staff CMS only lives here — csa_mobile_api does
    # not install django.contrib.admin at all.
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',
    'rest_framework',
    # Shared model source of truth (same tables as csa_mobile_api, same
    # database). This project NEVER runs migrate/makemigrations for these
    # three — see MIGRATION_MODULES below, which makes that a hard error
    # instead of silent drift. csa_mobile_api is the migration owner
    # (Part 6 of the split doc).
    'csa_shared_models.accounts.apps.AccountsConfig',
    'csa_shared_models.content.apps.ContentConfig',
    'csa_shared_models.incidents.apps.IncidentsConfig',
    # Local, staff-only apps: admin_views.py, permissions.py, the
    # create_admin_groups command, and admin.py (Django CMS
    # registrations). Distinct app_labels (accounts_admin/content_admin/
    # incidents_admin) so they don't collide with the shared apps above,
    # which own the actual accounts_*/content_*/incidents_* tables.
    'accounts.apps.AccountsAdminConfig',
    'content.apps.ContentAdminConfig',
    'incidents.apps.IncidentsAdminConfig',
]

# Hard-disables migrations for the shared apps from this project.
# `manage.py migrate` silently skips them (safe no-op); `manage.py
# makemigrations` for them raises instead of generating files that
# would drift from csa_mobile_api's copy. Combined with admin_api_user
# having no CREATE/ALTER grants at the database level (see
# db_setup/01_roles_and_grants.sql), this is belt-and-suspenders against
# ever accidentally altering schema from this side.
MIGRATION_MODULES = {
    'accounts': None,
    'content': None,
    'incidents': None,
}

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',
    'django.contrib.messages.middleware.MessageMiddleware',
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

ROOT_URLCONF = 'csa_admin_api.urls'

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

WSGI_APPLICATION = 'csa_admin_api.wsgi.application'

DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.environ.get('DB_NAME', 'csa_db'),
        # admin_api_user: broader CRUD access appropriate for staff
        # operations, still no CREATE/ALTER. See
        # db_setup/01_roles_and_grants.sql.
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

# Backs the login brute-force throttle. FileBasedCache (not the default
# in-process LocMemCache) so the counter is shared across gunicorn
# workers on the same host. For multi-host, point CACHE_URL at Redis.
CACHES = {
    'default': {
        'BACKEND': 'django.core.cache.backends.filebased.FileBasedCache',
        'LOCATION': os.environ.get(
            'CACHE_DIR', str(BASE_DIR / '.django_cache')
        ),
    }
}

LANGUAGE_CODE = 'en-us'
TIME_ZONE = 'UTC'
USE_I18N = True
USE_TZ = True

STATIC_URL = 'static/'
STATIC_ROOT = BASE_DIR / 'staticfiles'
STATICFILES_STORAGE = 'whitenoise.storage.CompressedManifestStaticFilesStorage'

# Same shared media directory as csa_mobile_api — one filesystem
# location, both processes. Admin uploads here, mobile serves from here.
MEDIA_URL = '/media/'
MEDIA_ROOT = SHARED_ROOT / 'shared_media'

REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    # Nothing is public by default — a view that forgets its own
    # @permission_classes is denied, not exposed.
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticated',
    ),
}

SIMPLE_JWT = {
    # Short access token: a leaked/stolen admin token is only good for
    # 30 min instead of a full day.
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=30),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=1),
    'AUTH_HEADER_TYPES': ('Bearer',),
}

# Refresh-token revocation. Needs the token_blacklist tables (created by
# csa_migrator from csa_mobile_api — same database) and
# db_setup/02_token_blacklist_grants.sql, so it is OPT-IN via env until
# that has been applied; with it on but the tables missing every login
# would 500. Installed here too so an admin disabling an account can
# blacklist that user's refresh tokens (they live in the shared table).
ENABLE_TOKEN_BLACKLIST = os.environ.get('ENABLE_TOKEN_BLACKLIST', 'False') == 'True'
if ENABLE_TOKEN_BLACKLIST:
    INSTALLED_APPS.append('rest_framework_simplejwt.token_blacklist')
    SIMPLE_JWT.update({
        'ROTATE_REFRESH_TOKENS': True,
        'BLACKLIST_AFTER_ROTATION': True,
    })

if not DEBUG:
    # JSON only — no DRF browsable-API HTML page on a deployed API.
    REST_FRAMEWORK['DEFAULT_RENDERER_CLASSES'] = (
        'rest_framework.renderers.JSONRenderer',
    )

# Used by csa_shared_models.accounts.push for sending FCM notifications
# (breaking news / alert broadcasts, certificate-approved). Same file
# as csa_mobile_api — see that project's settings.py for why this is
# now settings-driven instead of a hardcoded machine-specific path.
FIREBASE_SERVICE_ACCOUNT_FILE = os.environ.get(
    'FIREBASE_SERVICE_ACCOUNT_FILE',
    str(SHARED_ROOT / 'csa_project' / 'firebase-adminsdk.json'),
)

if not DEBUG:
    SECURE_SSL_REDIRECT = True
    SESSION_COOKIE_SECURE = True
    CSRF_COOKIE_SECURE = True
    SECURE_HSTS_SECONDS = 31536000
    SECURE_HSTS_INCLUDE_SUBDOMAINS = True
    SECURE_HSTS_PRELOAD = True
