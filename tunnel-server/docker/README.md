# OpenUDS Tunnel Server - Docker Setup

This directory contains the necessary files to build and run the OpenUDS Tunnel Server in a Docker container.

## Features

- **Python 3.12** based image.
- **Dynamic Configuration**: Automatically configures the tunnel server using environment variables.
- **SSL/TLS Support**: Handles SSL certificate paths and generates DH parameters automatically.
- **Auto-Registration**: Includes a script to register the tunnel token in the UDS database on startup.
- **Optimized Performance**: Uses `uvloop` for high-performance async processing.

## Prerequisites

- Docker and Docker Compose installed.
- Valid SSL certificates (PEM format) for the tunnel server.
- A tunnel token generated from the UDS Admin console.

## Quick Start

1. **Prepare Environment Variables**:
   Copy the example environment file and edit it with your server details:
   ```bash
   cp .env.example .env
   ```

2. **Place SSL Certificates**:
   Place your `server.pem` and `server.key` in the `ssl/` directory (or modify the `.env` paths):
   ```bash
   mkdir -p ssl/
   # Copy your certs here...
   ```

3. **Deploy with Docker Compose**:
   ```bash
   docker compose up -d --build
   ```

## Configuration (via .env)

| Variable | Description | Default/Status |
|----------|-------------|----------------|
| `SERVER_HOST` | Hostname/IP of the UDS application server | **Required** |
| `TUNNEL_TOKEN` | Authentication token from UDS Admin | **Required** |
| `SSL_CRT` | Path to SSL certificate inside container | `/etc/openuds-tunnel/ssl/server.pem` |
| `SSL_KEY` | Path to SSL private key inside container | `/etc/openuds-tunnel/ssl/server.key` |
| `MYSQL_DATABASE` | UDS database name for registration | `dbuds` |
| `MYSQL_USER` | UDS database user | `dbuds` |
| `MYSQL_PASSWORD` | UDS database password | **Required** |
| `TUNNEL_IP` | IP to register in DB | Auto-detected if not set |
| `TUNNEL_PORT` | Listening port for the tunnel | `8443` |

## DB Registration Logic

The file `add-tunnel-to-db.sh` runs once at container startup. It uses the `mysql` client to insert the tunnel's registration data (IP, Token, Date, etc.) into the `uds_tunneltoken` table of your UDS database.

## Support

For more information about OpenUDS, visit [https://github.com/VirtualCable/openuds](https://github.com/VirtualCable/openuds).
