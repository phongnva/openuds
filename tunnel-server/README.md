# UDS Tunnel Server

High-performance tunnel server for connecting clients to VDI infrastructure through OpenUDS.

## Overview

The UDS Tunnel Server provides a secure, optimized tunnel between clients and VDI endpoints. It handles connection routing, session management, and provides detailed performance metrics.

## Architecture

```
┌─────────────┐      ┌──────────────────┐      ┌──────────┐
│   Client    │ ───► │  Tunnel Server   │ ───► │    VDI   │
│  (OpenUDS) │      │ (Worker Process)  │      │ (Target) │
└─────────────┘      └──────────────────┘      └──────────┘
                            │
                    ┌───────┴───────┐
                    │               │
               TunnelProtocol  TunnelClientProtocol
               (server side)    (client to VDI)
```

## Features

### Performance Optimizations

- **Large Buffer Size**: 64KB default buffer (vs 16KB default) for improved throughput
- **TCP Keepalive**: Detect dead connections quickly
- **TCP_NODELAY**: Disable Nagle's algorithm for lower latency
- **TCP_DEFER_ACCEPT**: Reduce overhead for idle connections
- **Socket Buffer Tuning**: Configurable receive/send buffers
- **TLS Session Resumption**: Faster reconnection for repeat clients
- **Dynamic Thread Pool**: Optimized worker threads based on CPU cores

### Latency & Performance Metrics

- Real-time latency tracking (min, max, average)
- Round-trip time (RTT) estimation
- Bytes sent/received per session
- Connection statistics (active, total)

### Security

- TLS 1.2/1.3 support
- Certificate-based authentication
- IP allowlisting for admin commands
- Secret-protected statistics endpoint

## Installation

### Requirements

- Python 3.8+
- OpenSSL
- Linux (for TCP optimizations)

### Quick Start

1. Copy the sample configuration:
```bash
cp src/udstunnel.conf /etc/udstunnel.conf
```

2. Edit the configuration file with your UDS server details:
```ini
[uds]
address = 0.0.0.0
port = 443
uds_server = https://your-uds-server.com/uds/rest/tunnel/ticket
uds_token = your_token_here
ssl_certificate = /path/to/certificate.pem
ssl_certificate_key = /path/to/key.pem
secret = your_admin_secret
```

3. Run the tunnel server:
```bash
python src/udstunnel.py -t -c /etc/udstunnel.conf
```

## Configuration Options

### Basic Settings

| Option | Default | Description |
|--------|---------|-------------|
| `address` | `0.0.0.0` | Listen address |
| `port` | `443` | Listen port |
| `workers` | CPU cores | Number of worker processes |
| `ipv6` | `false` | Enable IPv6 |

### SSL/TLS Settings

| Option | Default | Description |
|--------|---------|-------------|
| `ssl_certificate` | (required) | SSL certificate path |
| `ssl_certificate_key` | (optional) | SSL key path |
| `ssl_min_tls_version` | `1.2` | Minimum TLS version (1.2 or 1.3) |
| `ssl_ciphers` | (default) | SSL ciphersuite list |

### TCP Performance Options

| Option | Default | Description |
|--------|---------|-------------|
| `socket_rcvbuf` | `0` (system) | Socket receive buffer size (bytes) |
| `socket_sndbuf` | `0` (system) | Socket send buffer size (bytes) |
| `tcp_keepalive` | `true` | Enable TCP keepalive |
| `tcp_keepidle` | `60` | Keepalive idle time (seconds) |
| `tcp_keepintvl` | `10` | Keepalive interval (seconds) |
| `tcp_keepcnt` | `3` | Keepalive probe count |
| `tcp_nodelay` | `true` | Disable Nagle's algorithm |
| `tcp_defer_accept` | `3` | Defer accept timeout (seconds) |
| `tcp_quickack` | `false` | Immediate ACK mode |

### Recommended Settings for VDI

For optimal VDI performance:

```ini
socket_rcvbuf = 262144
socket_sndbuf = 262144
tcp_keepalive = true
tcp_nodelay = true
tcp_defer_accept = 3
```

### Logging Settings

| Option | Default | Description |
|--------|---------|-------------|
| `loglevel` | `ERROR` | Log level (DEBUG, INFO, WARN, ERROR) |
| `logfile` | stdout | Log file path |
| `logsize` | `32M` | Max log file size |
| `lognumber` | `3` | Number of backup logs |

## Performance Tuning

### High-Speed Networks

For 1Gbps+ networks, increase buffer sizes:

```ini
socket_rcvbuf = 524288
socket_sndbuf = 524288
```

### Low-Latency Requirements

For minimal latency (interactive VDI):

```ini
tcp_nodelay = true
tcp_quickack = true
tcp_defer_accept = 1
```

### Connection Stability

For unreliable networks:

```ini
tcp_keepalive = true
tcp_keepidle = 30
tcp_keepintvl = 5
tcp_keepcnt = 3
```

## Monitoring

### Check Statistics

```bash
# Basic stats
python src/udstunnel.py -s -c /etc/udstunnel.conf

# Detailed stats (includes latency)
python src/udstunnel.py -d -c /etc/udstunnel.conf
```

### Stats Output Format

```
current_connections;total_connections;bytes_sent;bytes_recv;latency_avg_ms;latency_min_ms;latency_max_ms
```

### Log Analysis

Monitor for:
- Connection timeouts
- TLS handshake errors
- VDI connection failures

## Deployment

### Using Ansible

See `deployment/Ansible/README.md` for automated deployment.

### Systemd Service

Create `/etc/systemd/system/udstunnel.service`:

```ini
[Unit]
Description=UDS Tunnel Server
After=network.target

[Service]
Type=simple
User=www-data
ExecStart=/usr/bin/python3 /path/to/src/udstunnel.py -t -c /etc/udstunnel.conf
Restart=always

[Install]
WantedBy=multi-user.target
```

## Troubleshooting

### High Latency

1. Check network path: `ping -c 100 <vdi_host>`
2. Enable `tcp_nodelay = true`
3. Increase socket buffers
4. Check for network congestion

### Connection Drops

1. Enable TCP keepalive
2. Check firewall settings
3. Verify VDI server is reachable

### Low Throughput

1. Increase `socket_rcvbuf` and `socket_sndbuf`
2. Increase `BUFFER_SIZE` in source if needed
3. Check TLS ciphersuite performance

### Performance Metrics Not Available

Ensure you're using the detailed stats command:
```bash
python src/udstunnel.py -d -c /etc/udstunnel.conf
```

## Development

### Requirements

```bash
pip install -r requirements.txt
```

### Testing

```bash
pytest
```

### Code Structure

```
tunnel-server/
├── src/
│   ├── udstunnel.py          # Main entry point
│   ├── udstunnel.conf        # Sample configuration
│   └── uds_tunnel/
│       ├── tunnel.py         # Server-side tunnel protocol
│       ├── tunnel_client.py  # Client-side VDI connection
│       ├── proxy.py          # SSL/TLS proxy handler
│       ├── processes.py      # Worker process management
│       ├── config.py         # Configuration loader
│       ├── stats.py          # Statistics collection
│       └── consts.py         # Constants
└── deployment/               # Ansible deployment
```

## License

Copyright (c) 2022 Virtual Cable S.L.U.
See LICENSE file for details.
