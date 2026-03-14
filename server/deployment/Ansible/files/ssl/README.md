Place your SSL files here. Two modes are supported:

## Mode 1: Separate cert + key files (default)
  - `pv-vds.tk.crt`  — SSL certificate
  - `pv-vds.tk.key`  — SSL private key
  Set `ssl_use_pem: false` in group_vars (default).

## Mode 2: Single PEM file (cert + key combined)
  - `pv-vds.tk.pem`  — Combined cert + key PEM
  Set `ssl_use_pem: true` in group_vars.

## Generate self-signed certs for testing

### Separate .crt + .key:
```bash
openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
  -keyout pv-vds.tk.key \
  -out pv-vds.tk.crt \
  -subj "/C=VN/ST=HCM/L=HCM/O=OpenUDS/CN=pv-vds.tk"
```

### Single PEM (combine cert+key):
```bash
cat pv-vds.tk.crt pv-vds.tk.key > pv-vds.tk.pem
```
