Place your SSL certificate file here: pv-vds.tk.crt
Place your SSL private key file here: pv-vds.tk.key

These files are used by the nginx and haproxy roles.
For development/testing, you can generate self-signed certs:

  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout pv-vds.tk.key \
    -out pv-vds.tk.crt \
    -subj "/C=VN/ST=HCM/L=HCM/O=OpenUDS/CN=pv-vds.tk"
