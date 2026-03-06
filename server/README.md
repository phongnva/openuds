# OpenUDS Server Rebranding and Customization

To automate the visual and textual rebranding of OpenUDS to **FSOFT Virtual Desktop**, a standalone Python script and a Bash execution wrapper are provided.

## How to Rebrand

1. Ensure you are in the `server` directory where this README is located.
   ```bash
   cd /path/to/openuds/server
   ```

2. Run the provided execution script:
   ```bash
   ./run_rebrand.sh
   ```

### What `run_rebrand.sh` does:
- Bootstraps a temporary Docker container to run the `rebrand.py` script without requiring any local dependencies (like Python's Pillow library).
- The `rebrand.py` script automatically:
  - Takes the source FPT logo from `../logo-fpt/fpt-logo.png`.
  - Resizes and centers the logo perfectly onto transparent backgrounds for all required target images (e.g., `udsicon.png`, `favicon.png`, `favicon.ico`, `login-img.png`).
  - Safely opens all relevant JavaScript bundles, HTML templates, Python config files, and Locale files to replace textual references of "UDS Enterprise" -> "FSOFT Virtual Desktop" and "udsenterprise.com" -> "fptsoftware.com".
  - Strips Subresource Integrity (SRI) `integrity="..."` tags from the `index.html` headers so updated Javascript bundles can load correctly.
- Instructs `docker compose` to rebuild the `uds-app` image with the newly customized assets.
- Restarts the `uds-app` container in the background to serve the newly branded interface.

## Manual Steps Remaining

After the script finishes and the containers are back online:

1. Open your browser and navigate to the Admin Panel: `https://localhost/uds/adm/`
2. Go to **Configuration -> Custom**
3. Validate and manually update the specific Database fields:
   - **Site name**
   - **Logo name**
    - **Site copyright link**

## Security Headers Configuration

All published domains are configured with the following security headers at the **Nginx reverse proxy layer** (both Docker and Ansible deployments):

| Header | Value |
|--------|-------|
| `Cache-Control` | `no-store` |
| `Content-Security-Policy` | `default-src 'self'; upgrade-insecure-requests; block-all-mixed-content; connect-src 'self'; img-src 'self'; frame-ancestors 'self'; form-action 'self'; font-src 'self'; style-src 'self'; script-src 'self'; script-src-elem 'self'; object-src 'none'; base-uri 'self';` |
| `Permissions-Policy` | `geolocation=(self)` |
| `Referrer-Policy` | `no-referrer-when-downgrade` |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` |
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `SAMEORIGIN` |
| `X-XSS-Protection` | `1; mode=block` |
| `Cross-Origin-Embedder-Policy` | `require-corp` |
| `Cross-Origin-Opener-Policy` | `same-origin` |
| `Cross-Origin-Resource-Policy` | `same-origin` |
| `Access-Control-Allow-Credentials` | `true` |
| `Access-Control-Allow-Origin` | `https://trusted-domain.com` (configurable) |

> **CSP Policy:** No `unsafe-inline`, `unsafe-eval`, `data:`, or `blob:` directives are used.

### Django Security Settings (`settings.py.sample`)

| Setting | Value |
|---------|-------|
| `SESSION_COOKIE_HTTPONLY` | `True` |
| `SESSION_COOKIE_SECURE` | `True` |
| `SESSION_COOKIE_SAMESITE` | `Lax` |
| `CSRF_COOKIE_SECURE` | `True` |
| `CSRF_COOKIE_HTTPONLY` | `True` |
| `SECURE_HSTS_SECONDS` | `31536000` |
| `SECURE_HSTS_INCLUDE_SUBDOMAINS` | `True` |
| `SECURE_HSTS_PRELOAD` | `True` |
| `SECURE_CONTENT_TYPE_NOSNIFF` | `True` |
| `X_FRAME_OPTIONS` | `SAMEORIGIN` |

### Post-deployment Verification

```bash
curl -sI https://your-domain/ | grep -iE 'cache-control|content-security|permissions|referrer|strict-transport|x-content|x-frame|x-xss|cross-origin|access-control'
```
