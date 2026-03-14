Place your TLS certificate material here before running the HAProxy role.

Supported layouts:

1. `ssl_use_pem: true`
   - `{{ domain }}.pem`

2. `ssl_use_pem: false`
   - `{{ domain }}.crt`
   - `{{ domain }}.key`

The HAProxy role assembles the final PEM under `/etc/haproxy/certs/`.
