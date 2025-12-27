# UDS Broker - Docker Deployment Guide

This guide will walk you through deploying the UDS Broker application using Docker and Docker Compose.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Git** - for cloning the repository
- **Docker** (20.10 or later) or **Podman** (3.0 or later)
- **Docker Compose** or **podman-compose**

For Windows users using Podman, you may need to install podman-compose separately:
```powershell
pip install podman-compose
```

## Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd uds-broker
```

### 2. Configure SSL Certificates

The application requires SSL certificates for HTTPS access. You have two options:

#### Option A: Use Existing Certificates

If you have existing SSL certificates, place them in the `certs` directory:

```bash
mkdir -p certs
cp /path/to/your/certificate.crt certs/example.com.crt
cp /path/to/your/private-key.key certs/example.com.key
```

#### Option B: Generate Self-Signed Certificates (Development Only)

For development purposes, you can generate self-signed certificates:

```bash
mkdir -p certs
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout certs/example.com.key \
  -out certs/example.com.crt \
  -subj "/C=US/ST=State/L=City/O=Organization/CN=example.com"
```

**Note**: Replace `example.com` with your actual domain name.

### 3. Configure Environment Variables

Review and update the `docker.env` file with your configuration:

```bash
# Database Configuration
MYSQL_ROOT_PASSWORD=your_secure_root_password
MYSQL_DATABASE=dbuds
MYSQL_USER=uds
MYSQL_PASSWORD=your_secure_db_password

# Django Configuration
SECRET_KEY=your_very_long_and_random_secret_key_here
DEBUG=False
ALLOWED_HOSTS=yourdomain.com,www.yourdomain.com,localhost

# Database Connection (from Django's perspective)
DB_HOST=db
DB_PORT=3306
DB_NAME=dbuds
DB_USER=uds
DB_PASSWORD=your_secure_db_password

# Memcached Configuration
MEMCACHED_HOST=memcached
MEMCACHED_PORT=11211
```

**Important**:
- Change all default passwords to secure values
- Generate a new `SECRET_KEY` (you can use: `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`)
- Update `ALLOWED_HOSTS` with your actual domain name

### 4. Update Domain Configuration

#### Update Nginx Configuration

Edit `nginx_uds.conf` and replace `example.com` with your domain:

```nginx
server {
    listen 80;
    server_name your-domain.com www.your-domain.com;
    # ... rest of configuration
}

server {
    listen 443 ssl;
    server_name your-domain.com www.your-domain.com;
    
    ssl_certificate /app/certs/your-domain.com.crt;
    ssl_certificate_key /app/certs/your-domain.com.key;
    # ... rest of configuration
}
```

#### Update Certificate Paths

If you used different certificate filenames, update the paths in both:

1. **nginx_uds.conf**:
   ```nginx
   ssl_certificate /app/certs/your-certificate-name.crt;
   ssl_certificate_key /app/certs/your-certificate-name.key;
   ```

2. **docker-compose.yml** (if you changed the cert directory structure):
   ```yaml
   volumes:
     - ./certs:/app/certs:ro
   ```

### 5. Build and Run

Using Docker Compose:
```bash
docker-compose up -d
```

Using Podman Compose:
```bash
podman-compose up -d
```

The first build will take several minutes as it installs all dependencies.

### 6. Monitor the Startup

Watch the logs to ensure everything starts correctly:

```bash
# Docker
docker-compose logs -f broker

# Podman
podman-compose logs -f broker
```

Wait for the message indicating that services have started successfully.

### 7. Access the Application

Once the services are running:

- **HTTPS**: `https://your-domain.com/uds/`
- **HTTP**: `http://your-domain.com/uds/` (redirects to HTTPS)

**Admin Panel**: `https://your-domain.com/uds/adm/`

## Advanced Configuration

### Using Different Ports

By default, the application uses ports 80 and 443. To change these, edit `docker-compose.yml`:

```yaml
services:
  broker:
    ports:
      - "8080:80"    # HTTP on port 8080
      - "8443:443"   # HTTPS on port 8443
```

### Database Persistence

Database data is stored in a Docker volume named `db_data`. To back up your database:

```bash
# Docker
docker-compose exec db mysqldump -u root -p dbuds > backup.sql

# Podman
podman-compose exec db mysqldump -u root -p dbuds > backup.sql
```

### Scaling Memcached

If you need more cache memory, edit `docker-compose.yml`:

```yaml
memcached:
  image: memcached:alpine
  command: memcached -m 256  # 256 MB instead of default 64 MB
```

## Management Commands

### Viewing Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f broker
docker-compose logs -f db
docker-compose logs -f memcached
```

### Restarting Services

```bash
# Restart all services
docker-compose restart

# Restart specific service
docker-compose restart broker
```

### Stopping Services

```bash
# Stop all services
docker-compose down

# Stop and remove volumes (WARNING: deletes database)
docker-compose down -v
```

### Running Django Management Commands

```bash
# Create superuser
docker-compose exec -u openuds broker python3 manage.py createsuperuser

# Run migrations
docker-compose exec -u openuds broker python3 manage.py migrate

# Collect static files
docker-compose exec -u openuds broker python3 manage.py collectstatic --noinput
```

## Troubleshooting

### Issue: 502 Bad Gateway

**Cause**: Gunicorn service hasn't started yet or crashed.

**Solution**:
1. Check logs: `docker-compose logs broker`
2. Look for Python/Django errors
3. Verify database connection settings in `docker.env`
4. Restart: `docker-compose restart broker`

### Issue: SSL Certificate Errors

**Cause**: Certificate files not found or incorrect permissions.

**Solution**:
1. Verify certificates exist in `./certs/` directory
2. Check certificate names match `nginx_uds.conf`
3. For self-signed certs, browsers will show warnings (normal for development)

### Issue: Static Files Not Loading

**Cause**: Static files not collected or Nginx misconfigured.

**Solution**:
1. Run: `docker-compose exec -u openuds broker python3 manage.py collectstatic --noinput`
2. Check Nginx logs: `docker-compose logs broker | grep nginx`
3. Verify static file path in `nginx_uds.conf` points to `/app/src/static/`

### Issue: Database Connection Errors

**Cause**: Database not ready or wrong credentials.

**Solution**:
1. Verify database is running: `docker-compose ps`
2. Check database logs: `docker-compose logs db`
3. Verify credentials in `docker.env` match between Django and MySQL sections
4. Wait for database initialization (first startup takes longer)

### Issue: Permission Denied Errors

**Cause**: File permissions issues, especially on Windows.

**Solution**:
1. Ensure the `openuds` user owns application files inside container
2. Check `entrypoint.sh` runs with correct permissions
3. Verify volume mounts in `docker-compose.yml`

## Security Recommendations

For production deployments:

1. **Use Strong Passwords**: Change all default passwords in `docker.env`
2. **Use Valid SSL Certificates**: Obtain proper certificates from Let's Encrypt or a certificate authority
3. **Firewall Configuration**: Ensure only ports 80 and 443 are exposed
4. **Regular Updates**: Keep Docker images and dependencies updated
5. **Database Backups**: Implement regular database backup strategy
6. **Secret Management**: Consider using Docker secrets instead of environment files for sensitive data
7. **Disable Debug Mode**: Ensure `DEBUG=False` in production

## File Structure

```
uds-broker/
├── certs/                      # SSL certificates directory
│   ├── example.com.crt
│   └── example.com.key
├── docker-compose.yml          # Docker Compose configuration
├── Dockerfile                  # Docker image definition
├── docker.env                  # Environment variables
├── nginx_uds.conf             # Nginx web server configuration
├── entrypoint.sh              # Container startup script
├── requirements.txt           # Python dependencies
└── src/                       # Application source code
    ├── server/
    │   ├── settings.py.sample
    │   └── settings_docker.py
    └── uds/
        └── ...
```

## Support

For issues and questions:
- Review logs: `docker-compose logs -f`
- Check Django admin logs
- Verify configuration files match your environment

## License

[Add your license information here]
