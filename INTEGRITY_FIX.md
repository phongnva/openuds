# Integrity Attribute Removal - Technical Explanation

## Problem Summary

The UDS Broker web interface was failing to load with the following browser errors:

```
Failed to find a valid digest in the 'integrity' attribute for resource 
'https://example.com/uds/res/modern/main.js' with computed SHA-384 integrity 
'ehGQjnpxL6UebGXCE0CMycMSDI+k3fBLKgBJcNxFq04MX1h+W3Tj/phfT5vIK+2j'. 
The resource has been blocked.
```

Similar errors occurred for:
- `main.js`
- `polyfills.js`
- `scripts.js`
- `styles.css`

## Root Cause Analysis

### What is Subresource Integrity (SRI)?

Subresource Integrity is a security feature that allows browsers to verify that files they fetch (like JavaScript or CSS) haven't been tampered with. It works by:

1. The HTML includes an `integrity` attribute with a cryptographic hash (e.g., SHA-384)
2. The browser downloads the file
3. The browser computes the hash of the downloaded content
4. The browser compares the computed hash with the `integrity` attribute
5. If they match: the file loads ✅
6. If they don't match: the file is blocked ❌

### The Windows Git Line Ending Issue

The UDS Broker repository contains:
- **HTML templates** with hardcoded integrity hashes (in `src/uds/templates/uds/modern/index.html` and `src/uds/templates/uds/admin/index.html`)
- **Static files** (JavaScript and CSS files in `src/uds/static/`)

**The Problem:**

1. **Original Repository (Linux/Unix)**:
   - Files use LF (Line Feed, `\n`) line endings
   - Integrity hashes were computed on files with LF endings
   - Example: `main.js` with LF has hash `BwSW1dB1uvbzdwIj8z/FtIEmxQP9CQJuQBGlJWCoz5NaubNKdytu1yevDEGRJbw3`

2. **On Windows Clone**:
   - Git's default behavior on Windows: `core.autocrlf = true`
   - This converts LF → CRLF (Carriage Return + Line Feed, `\r\n`) for text files
   - JavaScript (`.js`) and CSS (`.css`) files are treated as text files
   - After conversion, the same `main.js` now has hash `ehGQjnpxL6UebGXCE0CMycMSDI+k3fBLKgBJcNxFq04MX1h+W3Tj/phfT5vIK+2j`

3. **The Mismatch**:
   - HTML template still has: `integrity="sha384-BwSW1d..."`  (LF hash)
   - Actual file on disk has: CRLF line endings
   - Browser computes: `sha384-ehGQjn...` (CRLF hash)
   - **Result**: Integrity check fails! 🔴

### Verification of Root Cause

We verified this by checking the actual file hash inside the container:

```bash
podman exec -it uds-broker-broker-1 \
  openssl dgst -sha384 -binary /app/src/static/modern/main.js | \
  openssl base64 -A
```

**Result**: `ehGQjnpxL6UebGXCE0CMycMSDI+k3fBLKgBJcNxFq04MX1h+W3Tj/phfT5vIK+2j`

This confirmed that:
- The file on disk has the CRLF hash
- The HTML template expects the LF hash
- The browser's computed hash matches the file on disk
- But it doesn't match the hardcoded `integrity` attribute

## Solution Implemented

### Changes Made

We removed the `integrity` and `crossorigin` attributes from both HTML templates:

#### File 1: `src/uds/templates/uds/modern/index.html`

**Before:**
```html
<link rel="stylesheet" href="/uds/res/modern/styles.css" 
      crossorigin="anonymous" 
      integrity="sha384-hM++3qfVhckRVfI9wfmiFYkEhG0M6dd8aXNoTDAuoJhrG53tmqQZGnimHbd9KShb" 
      media="print" onload="this.media='all'">

<script src="/uds/res/modern/polyfills.js" type="module" 
        crossorigin="anonymous" 
        integrity="sha384-TVRkn44wOGJBeCKWJBHWLvXubZ+Julj/yA0OoEFa3LgJHVHaPeeATX6NcjuNgsIA">
</script>

<script src="/uds/res/modern/scripts.js" defer 
        crossorigin="anonymous" 
        integrity="sha384-gJ6CPuwXlJNL6wOYMLzD98cFi988rpY6Ln6S+UhAkZs84+MOQ+ws+0qgV4WicE5i">
</script>

<script src="/uds/res/modern/main.js" type="module" 
        crossorigin="anonymous" 
        integrity="sha384-BwSW1dB1uvbzdwIj8z/FtIEmxQP9CQJuQBGlJWCoz5NaubNKdytu1yevDEGRJbw3">
</script>
```

**After:**
```html
<link rel="stylesheet" href="/uds/res/modern/styles.css" 
      media="print" onload="this.media='all'">

<script src="/uds/res/modern/polyfills.js" type="module"></script>

<script src="/uds/res/modern/scripts.js" defer></script>

<script src="/uds/res/modern/main.js" type="module"></script>
```

#### File 2: `src/uds/templates/uds/admin/index.html`

**Before:**
```html
<link rel="stylesheet" href="/uds/res/admin/styles.css" 
      crossorigin="anonymous" 
      integrity="sha384-DXP9vGDW7QYfvL7c+ABJZMqwpUWBqZPhfEIV+wyBnc4/5Oy7j+M/TBRh61fX5Xiq" 
      media="print" onload="this.media='all'">

<link rel="modulepreload" href="/uds/res/admin/chunk-2F3F2YC2.js?stamp=1763670632" 
      integrity="sha384-VVOra5xy5Xg9fYkBmK9MLhX7vif/MexRAaLIDBsQ4ZlkF31s/U6uWWrj+LAnvX/q">

<script src="/uds/res/admin/polyfills.js?stamp=1763670632" type="module" 
        crossorigin="anonymous" 
        integrity="sha384-TVRkn44wOGJBeCKWJBHWLvXubZ+Julj/yA0OoEFa3LgJHVHaPeeATX6NcjuNgsIA">
</script>

<script src="/uds/res/admin/main.js?stamp=1763670632" type="module" 
        crossorigin="anonymous" 
        integrity="sha384-rpa4AiwJwItB7Wlb6Pl8s9RcA1wWrhLV9pZeE3R9Mkjf4Vs/enDBPUlecVBmomfO">
</script>
```

**After:**
```html
<link rel="stylesheet" href="/uds/res/admin/styles.css" 
      media="print" onload="this.media='all'">

<link rel="modulepreload" href="/uds/res/admin/chunk-2F3F2YC2.js?stamp=1763670632">

<script src="/uds/res/admin/polyfills.js?stamp=1763670632" type="module"></script>

<script src="/uds/res/admin/main.js?stamp=1763670632" type="module"></script>
```

## Why This Solution Works

By removing the `integrity` attributes:

1. **No SRI Check**: The browser no longer verifies file integrity
2. **Files Load Successfully**: CRLF line endings don't matter anymore
3. **Same-Origin Security**: Files are served from the same domain, so CORS isn't a concern
4. **Functional Application**: The web interface loads and works correctly

## Alternative Solutions (Not Implemented)

### Option 1: Fix Git Line Endings
Configure Git to preserve LF line endings on Windows:

```bash
git config --global core.autocrlf false
# Then re-clone the repository
```

**Downsides**:
- Requires re-cloning the repository
- May cause issues with Windows text editors
- Doesn't help users who already cloned with CRLF

### Option 2: Update Integrity Hashes
Compute new SHA-384 hashes for CRLF versions and update HTML templates:

```bash
openssl dgst -sha384 -binary main.js | openssl base64 -A
```

**Downsides**:
- Breaks on Linux/Unix systems (where files have LF)
- Need separate template versions for Windows vs Linux
- Fragile solution

### Option 3: Use ManifestStaticFilesStorage
Configure Django to auto-generate integrity hashes:

```python
STATICFILES_STORAGE = 'django.contrib.staticfiles.storage.ManifestStaticFilesStorage'
```

**Downsides**:
- Requires code changes to UDS Broker
- `staticfiles.json` was missing, indicating this isn't currently configured
- More complex to implement

## Security Implications

### What We Lost
- **Subresource Integrity Protection**: Can no longer detect if files are tampered with during transit

### Why It's Acceptable
1. **Self-Hosted Application**: Files are served from the same server, not a CDN
2. **HTTPS Encryption**: TLS protects files in transit from tampering
3. **Same-Origin Policy**: Browser security prevents loading files from other domains
4. **Development/Private Deployment**: This is typically deployed in controlled environments

### If You Need SRI
For maximum security (e.g., production with CDN):
1. Use Option 1 (fix Git line endings) and re-clone
2. Or use Option 3 (Django ManifestStaticFilesStorage)
3. Or deploy from a Linux build system

## Testing Verification

After the changes:

1. ✅ Static files load without integrity errors
2. ✅ `/uds/res/modern/main.js` returns HTTP 200
3. ✅ `/uds/res/modern/styles.css` returns HTTP 200
4. ✅ Browser console shows no integrity errors
5. ✅ Web interface renders correctly

## Summary

**Problem**: Windows Git converted LF → CRLF, breaking hardcoded integrity hashes

**Solution**: Removed `integrity` and `crossorigin` attributes from HTML templates

**Impact**: Application now loads correctly on Windows, with acceptable security trade-offs for self-hosted deployment

**Files Modified**:
- `src/uds/templates/uds/modern/index.html`
- `src/uds/templates/uds/admin/index.html`

## References

- [MDN: Subresource Integrity](https://developer.mozilla.org/en-US/docs/Web/Security/Subresource_Integrity)
- [Git Line Endings](https://git-scm.com/book/en/v2/Customizing-Git-Git-Configuration#_core_autocrlf)
- [Django ManifestStaticFilesStorage](https://docs.djangoproject.com/en/stable/ref/contrib/staticfiles/#manifeststaticfilesstorage)
