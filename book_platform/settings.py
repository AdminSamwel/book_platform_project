"""
Django settings for book_platform project.
"""

import os
from pathlib import Path
from datetime import timedelta

BASE_DIR = Path(__file__).resolve().parent.parent

# ============================================
# 1. USER MODEL MAALUM (lazima iwe juu)
# ============================================
AUTH_USER_MODEL = 'users.User'

# ============================================
# 2. SECURITY
# ============================================
SECRET_KEY = os.environ.get('SECRET_KEY', 'django-insecure-change-this-to-a-random-secret-key')
DEBUG = os.environ.get('DEBUG', 'False') == 'True'
ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '*').split(',')

# ============================================
# 3. APPLICATIONS
# ============================================
INSTALLED_APPS = [
    # Django core
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Third-party
    'corsheaders',
    'rest_framework',
    'rest_framework_simplejwt',
    'django_filters',

    # Apps zetu
    'users',
    'books',
    'payments',
    'wallet',
    'subscriptions',
    'comments',
]

# ============================================
# 4. MIDDLEWARE (lazima kwa admin)
# ============================================
MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'whitenoise.middleware.WhiteNoiseMiddleware',
    'corsheaders.middleware.CorsMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',       # Admin inahitaji hii
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',   # Admin inahitaji hii
    'django.contrib.messages.middleware.MessageMiddleware',      # Admin inahitaji hii
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

# ============================================
# 5. TEMPLATES (lazima kwa admin)
# ============================================
TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]

# ============================================
# 6. DATABASE
# ============================================
DATABASE_URL = os.environ.get('DATABASE_URL')
if DATABASE_URL:
    import dj_database_url
    DATABASES = {'default': dj_database_url.config(default=DATABASE_URL, conn_max_age=600)}
else:
    DATABASES = {
        'default': {
            'ENGINE': 'django.db.backends.sqlite3',
            'NAME': BASE_DIR / 'db.sqlite3',
        }
    }

# ============================================
# 7. REST FRAMEWORK & JWT
# ============================================
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
    'DEFAULT_PERMISSION_CLASSES': (
        'rest_framework.permissions.IsAuthenticatedOrReadOnly',
    ),
    'DEFAULT_PAGINATION_CLASS': 'rest_framework.pagination.PageNumberPagination',
    'PAGE_SIZE': 20,
    'DEFAULT_FILTER_BACKENDS': ['django_filters.rest_framework.DjangoFilterBackend'],
}

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(hours=1),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=7),
}

# ============================================
# 8. ENCRYPTION KEY (DRM)
# ============================================
BOOK_ENCRYPTION_KEY = b'12345678901234567890123456789012'  # Badilisha kwa uzalishaji

# ============================================
# 9. KIMATAIFA, MEDIA, STATIC
# ============================================
LANGUAGE_CODE = 'sw'
TIME_ZONE = 'Africa/Dar_es_Salaam'
USE_I18N = True
USE_TZ = True

STATIC_URL = '/static/'
STATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')
MEDIA_URL = '/media/'
MEDIA_ROOT = os.path.join(BASE_DIR, 'media')

DEFAULT_AUTO_FIELD = 'django.db.models.BigAutoField'

# ============================================
# 10. ROOT_URLCONF & WSGI
# ============================================
ROOT_URLCONF = 'book_platform.urls'
WSGI_APPLICATION = 'book_platform.wsgi.application'

# ============================================
# 11. CORS (kwa Flutter web na development)
# ============================================
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True