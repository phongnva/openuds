from .settings import *
import os

DEBUG = os.environ.get('DEBUG', 'False') == 'True'

DATABASES['default'] = {
    'ENGINE': os.environ.get('DB_ENGINE', 'django.db.backends.mysql'),
    'NAME': os.environ.get('DB_NAME', 'dbuds'),
    'USER': os.environ.get('DB_USER', 'dbuds'),
    'PASSWORD': os.environ.get('DB_PASSWORD', 'PASSWORD'),
    'HOST': os.environ.get('DB_HOST', 'db'),
    'PORT': os.environ.get('DB_PORT', '3306'),
    'OPTIONS': {
        'isolation_level': 'read committed',
    },
}

CACHES['memory'] = {
    'BACKEND': 'django.core.cache.backends.memcached.PyLibMCCache',
    'LOCATION': f"{os.environ.get('MEMCACHED_HOST', 'memcached')}:{os.environ.get('MEMCACHED_PORT', '11211')}",
}

SECRET_KEY = os.environ.get('SECRET_KEY', SECRET_KEY)

ALLOWED_HOSTS = os.environ.get('ALLOWED_HOSTS', '*').split(',')

# Read RSA Key from file to avoid string escaping issues
RSA_KEY_PATH = os.path.join(os.path.dirname(__file__), 'rsa_key.pem')
print(f"DEBUG: Loading settings_docker, RSA_KEY_PATH={RSA_KEY_PATH}")
if os.path.exists(RSA_KEY_PATH):
    with open(RSA_KEY_PATH, 'r') as f:
        RSA_KEY = f.read()
        print(f"DEBUG: Loaded RSA_KEY from file, length={len(RSA_KEY)}")
else:
    # Fallback or placeholder if file missing during build
    print("DEBUG: RSA_KEY_PATH not found, using empty string")
    RSA_KEY = ''
