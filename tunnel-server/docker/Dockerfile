FROM python:3.12-slim-bookworm

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssl \
    ca-certificates \
    default-mysql-client \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /usr/share/openuds/tunnel \
    /etc/openuds-tunnel/ssl \
    /var/log/openuds-tunnel \
    /var/run

# Install Python dependencies
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt && rm /tmp/requirements.txt

# Copy tunnel server source code
COPY src/ /usr/share/openuds/tunnel/

# Set PYTHONPATH so udstunnel module is importable
ENV PYTHONPATH=/usr/share/openuds/tunnel

# Copy Docker configuration files
COPY docker/udstunnel.conf /etc/openuds-tunnel/udstunnel.conf
COPY docker/add-tunnel-to-db.sh /usr/local/bin/add-tunnel-to-db.sh
COPY docker/entrypoint.sh /entrypoint.sh

# Set permissions
RUN chmod +x /entrypoint.sh /usr/local/bin/add-tunnel-to-db.sh

# Expose tunnel port
EXPOSE 8443

ENTRYPOINT ["/entrypoint.sh"]
