![UDS Logo](https://www2.udsenterprise.com/static//img/logoUDSNav.png)

OpenUDS Tunnel Server
=====================

This is the OpenUDS Tunnel Server, a component of the OpenUDS system.

More info at https://github.com/VirtualCable/openuds

## Installation

UDS Tunnel server needs:
  * psutil
  * aiohttp

UDS Tunnel server has been tested, in several distributions, using:
  * uvloop (highly recommended for performance)

## Performance Optimizations (RDP)

The tunnel server includes optimizations for low-latency, smooth RDP connections:

### Application-Level
| Optimization | Description |
|---|---|
| **64KB relay buffer** | Matches RDP bitmap frame sizes, fewer syscalls |
| **TCP_NODELAY** | Disables Nagle's algorithm on the VDI backend socket (eliminates 40ms delay) |
| **256KB socket buffers** | SO_SNDBUF/SO_RCVBUF sized for bursty RDP traffic |
| **Write buffer limits** | Prevents asyncio back-pressure from choking RDP bursts |
| **X25519 ECDH** | ~3x faster TLS key exchange than secp384r1 |
| **TLS session tickets** | Saves 1 full TLS handshake RTT on reconnects |
| **TCP Fast Open** | Saves 1 RTT on initial connection |
| **aiohttp session reuse** | Connection pooling for UDS API ticket validation |

### OS-Level (via Ansible sysctl)
| Parameter | Value | Purpose |
|---|---|---|
| `tcp_congestion_control` | `bbr` | Better throughput + lower latency |
| `tcp_mtu_probing` | `1` | Auto-discovers optimal path MTU |
| `tcp_sack` | `1` | Faster recovery from packet loss |
| `tcp_fastopen` | `3` | Data-in-SYN for client+server |
| `tcp_keepalive_time` | `60` | Detect dead connections faster |
| `rmem_max` / `wmem_max` | `16MB` | Allow large kernel buffers |

### Tunable Parameters in `udstunnel.conf`
```ini
# Relay buffer size (default: 64KB)
buffer_size = 65536

# Socket send/receive buffer size (default: 256KB)
socket_buffer_size = 262144
```

## Deployment

See [Ansible Deployment README](deployment/Ansible/README.md) for step-by-step instructions.

## Quick Start

```bash
# Run tunnel server
python3 src/udstunnel.py -t -c /etc/udstunnel.conf

# Check stats
python3 src/udstunnel.py -s
```
