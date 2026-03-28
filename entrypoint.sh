#!/bin/bash
set -e

# Wait for database
if [ "$DATABASE" = "mysql" ]
then
    echo "Waiting for mysql ($DB_HOST:$DB_PORT)..."
    while ! nc -z $DB_HOST $DB_PORT; do
      sleep 1
    done
    echo "MySQL started"
fi

export DJANGO_SETTINGS_MODULE=server.settings_docker
WORKDIR=/app/src
cd ${WORKDIR}

# Ensure necessary directories exist
mkdir -p /run/openuds /app/src/log /app/src/static /app/certs /app/src/media
chown -R openuds:openuds /run/openuds /app/src/log /app/src/static /app/src/media /app/certs

# Generate self-signed certificates if they don't exist
if [ ! -f "/app/certs/example.com.crt" ]; then
    echo "Generating self-signed certificates..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout /app/certs/example.com.key \
      -out /app/certs/example.com.crt \
      -subj "/C=US/ST=State/L=City/O=Organization/CN=example.com"
    chown openuds:openuds /app/certs/example.com.key /app/certs/example.com.crt
fi

# Restore settings.py from sample if it doesn't exist
if [ ! -f "/app/src/server/settings.py" ]; then
    cp /app/src/server/settings.py.sample /app/src/server/settings.py
fi

# Generate RSA key if it doesn't exist
RSA_KEY_FILE=/app/src/server/rsa_key.pem
if [ ! -f "$RSA_KEY_FILE" ]; then
    echo "Generating new RSA key..."
    openssl genrsa -traditional 2048 > "$RSA_KEY_FILE"
    chown openuds:openuds "$RSA_KEY_FILE"
    chmod 600 "$RSA_KEY_FILE"
fi

# Run migrations
echo "Run migrations"
sudo -E -u openuds bash -c "cd /app/src; python3 manage.py migrate --noinput"

# Create cache table if it doesn't exist
echo "Creating cache table"
sudo -E -u openuds bash -c "cd /app/src; python3 manage.py createcachetable"

# Collect static files
echo "Collect static files"
sudo -E -u openuds bash -c "cd /app/src; python3 manage.py collectstatic --noinput"

# Ensure Nginx can read static files
# Add www-data to openuds group if not already
usermod -a -G openuds www-data
chmod -R 755 /app/src/static
chown -R openuds:openuds /app/src/static

# Fix Fontconfig cache
export XDG_CACHE_HOME=/run/openuds/.cache
mkdir -p $XDG_CACHE_HOME
chown -R openuds:openuds $XDG_CACHE_HOME

# Start gunicorn
echo "Starting gunicorn on unix socket"
sudo -E -u openuds bash -c "cd /app/src; gunicorn server.wsgi:application \
          --pid /run/openuds/pid \
          --bind unix:/run/openuds/socket \
          --workers 5 \
          --threads 8 \
          --daemon \
          --access-logfile /app/src/log/gunicorn-access.log \
          --error-logfile /app/src/log/gunicorn-error.log"

# Wait for socket
sleep 2

# Start task manager in background
echo "Starting task manager"
sudo -E -u openuds bash -c "cd /app/src; python3 manage.py taskManager --start --foreground" &

# Start nginx in foreground to keep container running
echo "Starting nginx"
/usr/sbin/nginx -g 'daemon off;'