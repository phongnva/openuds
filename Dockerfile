# Use an official Python runtime as a parent image
FROM python:3.12-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV PYTHONPATH /app/src

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libmariadb-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    libffi-dev \
    libcairo2-dev \
    libpango1.0-dev \
    libjpeg-dev \
    libgif-dev \
    libwebp-dev \
    libxml2-dev \
    libxslt1-dev \
    zlib1g-dev \
    libmemcached-dev \
    netcat-openbsd \
    curl \
    nginx \
    sudo \
    procps \
    && apt-get clean && rm -rf /var/lib/lists/*

# Install Python dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Create openuds user
RUN useradd -m -s /bin/bash openuds

# Copy project
COPY . /app/

# Create settings.py from sample if it doesn't exist
RUN if [ ! -f /app/src/server/settings.py ]; then cp /app/src/server/settings.py.sample /app/src/server/settings.py; fi

# Configure Nginx
RUN rm /etc/nginx/sites-enabled/default
COPY nginx_uds.conf /etc/nginx/sites-available/openuds.conf
RUN ln -s /etc/nginx/sites-available/openuds.conf /etc/nginx/sites-enabled/openuds.conf

# Setup runtime directory
RUN mkdir -p /run/openuds && chown openuds:openuds /run/openuds

# Set ownership of /app
RUN chown -R openuds:openuds /app

# Make entrypoint script executable
RUN chmod +x /app/entrypoint.sh

# Expose ports
EXPOSE 80 443

# Run entrypoint script
ENTRYPOINT ["/app/entrypoint.sh"]
