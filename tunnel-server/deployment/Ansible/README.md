# OpenUDS Tunnel Server - Ansible Deployment

This directory contains the Ansible configuration required to deploy the OpenUDS Tunnel Server to a target machine using a systemd service and a Python virtual environment.

## Overview

The deployment playbook performs the following actions:
1. Installs system dependencies (`python3`, `python3-venv`, `openssl`, `default-mysql-client`).
2. Synchronizes the tunnel server source code and `requirements.txt` to the target machine (`/opt/openuds-tunnel`).
3. Creates a Python virtual environment and installs required Python packages.
4. Generates an SSL Diffie-Hellman parameter file (if not present).
5. Configures the tunnel server (`/etc/openuds-tunnel/udstunnel.conf`) based on Ansible variables.
6. Installs and starts the `udstunnel` systemd service.
7. Registers the tunnel server in the OpenUDS database.

## Prerequisites

- Ansible installed on your control node.
- SSH access to the target tunnel server(s) using key-based authentication.
- A valid tunnel token generated from the OpenUDS Admin dashboard.
- SSL certificates (`.crt` / `.pem` and `.key`) already placed on the target server, or you can update the `ssl_cert_path` variables to point to them.

## Configuration

All configuration is managed in two files:

1. **`inventory/hosts.yml`**: Defines the target servers and SSH connection details.
   - Update `ansible_host` under `tunnel_servers` -> `uds-tunnel01` with your server's IP address.
   - Ensure `ansible_ssh_private_key_file` points to your correct SSH private key.

2. **`inventory/group_vars/all.yml`**: Contains settings for the tunnel, domain, SSL, and database.
   - Set `tunnel_token` to your OpenUDS token.
   - Ensure `db_password` is correct so the tunnel can register itself.

## Deployment

To deploy the tunnel server:

1. Navigate to the Ansible directory:
   ```bash
   cd tunnel-server/deployment/Ansible
   ```

2. Run a syntax check (optional but recommended):
   ```bash
   ansible-playbook playbooks/deploy_tunnel.yml --syntax-check
   ```

3. Run the deployment playbook:
   ```bash
   ansible-playbook playbooks/deploy_tunnel.yml
   ```

## Managing the Service

Once deployed, the tunnel server runs as a standard systemd service. You can manage it on the target machine with:

```bash
sudo systemctl status udstunnel
sudo systemctl restart udstunnel
sudo journalctl -u udstunnel -f
```

Configuration and logs are located at:
- Config: `/etc/openuds-tunnel/udstunnel.conf`
- Logs: `/var/log/openuds-tunnel/udstunnel.log`
- Code / Virtualenv: `/opt/openuds-tunnel/`
