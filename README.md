# uds-client
UDS Client used to connect to OpenUDS Broker

This project is the UDS Client moved to its own repository, so it's easier to make changes, track it, etc...

## How to build

### Windows

See [BUILD-Windows.md](BUILD-Windows.md)

### Linux

See [BUILD-Linux.md](BUILD-Linux.md)

### macOS (Apple Silicon / ARM64)

VDC macOS Client supports building as a DMG image natively on M-series chips.

```bash
cd src
bash build-macos-arm64-dmg.sh
```

**Performance Improvements Included:**
- Optimized TLS tunnel for Real-time Video/Network usage.
- Enabled `TCP_NODELAY` to remove Nagle's algorithm latency (fixing lag and jitter during VDI sessions).
- Configured TCP `SO_KEEPALIVE` against frequent package loss instances.
- Expanded Tunnel `BUFFER_SIZE` up to 64KB for high-resolution connection smoothness.