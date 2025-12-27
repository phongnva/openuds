#!/bin/bash
set -e

# Wait for database
if [ "$DATABASE" = "mysql" ]
then
    echo "Waiting for mysql..."
    while ! nc -z $DB_HOST $DB_PORT; do
      sleep 0.1
    done
    echo "MySQL started"
fi

# Set database and other settings in settings.py using environment variables
# Note: In current setup, we use settings_docker.py which already uses os.environ.get
# But to follow the sample style, we can apply sed to settings.py if needed.
# However, the project is configured to use DJANGO_SETTINGS_MODULE=server.settings_docker
# which is more robust. I will apply the sample logic but keep it compatible.

export DJANGO_SETTINGS_MODULE=server.settings_docker
WORKDIR=/app/src
cd ${WORKDIR}

if [ ! -d /run/openuds ];
then
    mkdir -p /run/openuds
    chown openuds:openuds /run/openuds
fi

# Restore settings.py from sample to fix syntax errors caused by previous sed
cp /app/src/server/settings.py.sample /app/src/server/settings.py

# Generate RSA key if it doesn't exist (ensures valid PEM in container environment)
RSA_KEY_FILE=/app/src/server/rsa_key.pem
if [ ! -f "$RSA_KEY_FILE" ]; then
    echo "Generating new RSA key..."
    openssl genrsa -traditional 2048 > "$RSA_KEY_FILE"
    chown openuds:openuds "$RSA_KEY_FILE"
    chmod 600 "$RSA_KEY_FILE"
fi

# Ensure log directory exists and is writable
mkdir -p /app/src/log
chown -R openuds:openuds /app/src/log

# Run migrations
echo "Run migrations"
sudo -E -u openuds bash -c "cd /app/src; python3 manage.py migrate --noinput"

# Ensure static directory exists and is world-readable for Nginx
mkdir -p /app/src/static
# Collect static files as root to ensure all assets are gathered
echo "Collect static files"
python3 manage.py collectstatic --noinput
# Set permissions for Nginx to read
chown -R openuds:openuds /app/src/static
chmod -R 755 /app/src/static

# Fix Fontconfig error by creating a writable cache directory
export XDG_CACHE_HOME=/run/openuds/.cache
mkdir -p $XDG_CACHE_HOME
chown -R openuds:openuds $XDG_CACHE_HOME
chmod -R 777 $XDG_CACHE_HOME

# Collect static files again as openuds if preferred, but root is safer for now
# su -s /bin/bash - openuds -c "python3 manage.py collectstatic --noinput"

# Start openuds-web service (Django via Gunicorn)
echo "Starting gunicorn on unix socket"
sudo -E -u openuds bash -c "cd /app/src; gunicorn server.wsgi:application \
          --pid /run/openuds/pid \
          --bind unix:/run/openuds/socket \
          --workers 5 \
          --threads 8 \
          --daemon \
          --access-logfile /app/src/log/gunicorn-access.log \
          --error-logfile /app/src/log/gunicorn-error.log"

# Wait for socket to be created
sleep 2

# Start nginx service
echo "Starting nginx"
/usr/sbin/nginx -g 'daemon off;' &

# Start openuds-task-manager
echo "Starting task manager"
sudo -E -u openuds bash -c "cd /app/src; python3 manage.py taskManager --start --foreground"
