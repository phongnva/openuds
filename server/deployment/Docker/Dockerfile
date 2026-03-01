FROM python:3.12-slim-bookworm

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    default-libmysqlclient-dev \
    libldap2-dev \
    libsasl2-dev \
    libxml2-dev \
    libxslt1-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    libjpeg-dev \
    zlib1g-dev \
    libcairo2 \
    libpango-1.0-0 \
    libpangocairo-1.0-0 \
    libgdk-pixbuf2.0-0 \
    shared-mime-info \
    libxmlsec1-dev \
    pkg-config \
    libmemcached-dev \
    netcat-openbsd \
    sudo \
    nginx \
    openssl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create user and group
RUN groupadd -r openuds && useradd -r -g openuds -d /app openuds

# Set working directory
WORKDIR /app

# Copy requirements and install dependencies
# Build context is server/ root, so paths are relative to that
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src ./src

# Copy Docker-specific files
COPY deployment/Docker/nginx_uds.conf /etc/nginx/sites-available/default
COPY deployment/Docker/entrypoint.sh .
RUN chmod +x entrypoint.sh

# Create necessary directories
RUN mkdir -p /run/openuds /app/src/log /app/src/static /app/certs && \
    chown -R openuds:openuds /app /run/openuds

# Expose ports
EXPOSE 80 443

# Entrypoint
ENTRYPOINT ["./entrypoint.sh"]
