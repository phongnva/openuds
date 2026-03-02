#!/bin/bash
set -e

CONFIG_FILE="/etc/openuds-tunnel/udstunnel.conf"

echo "========================================"
echo "  UDS Tunnel Server - Docker Entrypoint"
echo "========================================"

# ------------------------------------------
# 1. Configure UDS server host
# ------------------------------------------
if [ -n "${SERVER_HOST}" ]; then
    echo "[CONFIG] Setting UDS server host to: ${SERVER_HOST}"
    sed -i "s|serveruds.ovox.io|${SERVER_HOST}|g" "${CONFIG_FILE}"
else
    echo "[WARN] SERVER_HOST not set, using default from config"
fi

# ------------------------------------------
# 2. Configure SSL certificates
# ------------------------------------------
if [ -n "${SSL_CRT}" ]; then
    echo "[CONFIG] Setting SSL certificate to: ${SSL_CRT}"
    sed -i "s|ssl_certificate =.*|ssl_certificate = ${SSL_CRT}|g" "${CONFIG_FILE}"
fi

if [ -n "${SSL_KEY}" ]; then
    echo "[CONFIG] Setting SSL certificate key to: ${SSL_KEY}"
    sed -i "s|ssl_certificate_key =.*|ssl_certificate_key = ${SSL_KEY}|g" "${CONFIG_FILE}"
fi

# ------------------------------------------
# 3. Configure UDS tunnel token
# ------------------------------------------
if [ -n "${TUNNEL_TOKEN}" ]; then
    echo "[CONFIG] Setting UDS tunnel token"
    sed -i "s|uds_token =.*|uds_token = ${TUNNEL_TOKEN}|g" "${CONFIG_FILE}"
fi

# ------------------------------------------
# 4. Configure optional settings
# ------------------------------------------
if [ -n "${TUNNEL_PORT}" ]; then
    echo "[CONFIG] Setting tunnel port to: ${TUNNEL_PORT}"
    sed -i "s|port =.*|port = ${TUNNEL_PORT}|g" "${CONFIG_FILE}"
fi

if [ -n "${UDS_VERIFY_SSL}" ]; then
    echo "[CONFIG] Setting UDS verify SSL to: ${UDS_VERIFY_SSL}"
    sed -i "s|uds_verify_ssl =.*|uds_verify_ssl = ${UDS_VERIFY_SSL}|g" "${CONFIG_FILE}"
fi

if [ -n "${LOG_LEVEL}" ]; then
    echo "[CONFIG] Setting log level to: ${LOG_LEVEL}"
    sed -i "s|loglevel =.*|loglevel = ${LOG_LEVEL}|g" "${CONFIG_FILE}"
fi

# ------------------------------------------
# 5. Generate DH parameters if not existing
# ------------------------------------------
DH_FILE="/etc/openuds-tunnel/ssl/openuds-tunnel.dh"
if [ ! -f "${DH_FILE}" ]; then
    echo "[SSL] Generating DH parameters (this may take a moment)..."
    mkdir -p /etc/openuds-tunnel/ssl
    openssl dhparam -out "${DH_FILE}" 2048
    echo "[SSL] DH parameters generated"
else
    echo "[SSL] DH parameters already exist, skipping generation"
fi

# ------------------------------------------
# 6. Trust CA certificate if provided
# ------------------------------------------
if [ -n "${SSL_CA}" ] && [ -f "${SSL_CA}" ]; then
    echo "[SSL] Trusting CA certificate: ${SSL_CA}"
    cp "${SSL_CA}" /usr/local/share/ca-certificates/uds-ca.crt
    update-ca-certificates
    echo "[SSL] CA certificate trusted"
fi

# ------------------------------------------
# 7. Print final config (redacted)
# ------------------------------------------
echo ""
echo "[INFO] Final configuration:"
grep -E "^(port|address|ssl_certificate|uds_server|loglevel|workers)" "${CONFIG_FILE}" | sed 's/uds_token =.*/uds_token = ***REDACTED***/'
echo ""

# ------------------------------------------
# 8. Start tunnel server
# ------------------------------------------
echo "[START] Launching UDS Tunnel Server..."
/usr/bin/python3 /usr/share/openuds/tunnel/udstunnel.py -t -c "${CONFIG_FILE}" &
TUNNEL_PID=$!

# ------------------------------------------
# 9. Run add-tunnel-to-db script
# ------------------------------------------
if [ -x /usr/local/bin/add-tunnel-to-db.sh ]; then
    echo "[START] Running add-tunnel-to-db.sh..."
    /usr/local/bin/add-tunnel-to-db.sh
fi

# ------------------------------------------
# 10. Wait for tunnel process
# ------------------------------------------
echo "[INFO] UDS Tunnel Server is running (PID: ${TUNNEL_PID})"
wait ${TUNNEL_PID}
