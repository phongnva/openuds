# OpenUDS HA Deployment with Ansible

This directory contains the Ansible playbooks and roles for deploying OpenUDS in a High Availability (HA) configuration.

## Architecture Overview

The deployment sets up a robust cluster comprising:
- **Load Balancers**: 2 nodes running **HAProxy** and **Keepalived** for a floating Virtual IP (VIP).
- **Web Servers**: 2 nodes running **Nginx** as a reverse proxy for Gunicorn.
- **App Servers**: 2 nodes running **OpenUDS (Gunicorn + TaskManager)**.
- **Database**: 2 nodes running **MySQL 8.0** with Primary-Replica GTID-based replication.

| Role | Server 01 | Server 02 | VIP |
|------|-----------|-----------|-----|
| IP | 103.131.85.183 | 103.131.85.163 | 103.131.85.232 |
| MySQL | Primary | Replica | - |

## Prerequisites

1.  **Ansible**: Version 2.12 or higher installed on your control machine.
2.  **SSH Access**: Key-based SSH access to the target servers (`root` user recommended).
3.  **OS**: Ubuntu 24.04 (Noble) or 22.04 (Jammy).
4.  **Dependencies**: `python3-pymysql` must be installed on the target nodes (handled automatically by roles).

## Setup & Configuration

### 1. Inventory

The inventory is split into `prod` and `dev` environments:
- `inventory/prod/hosts.yml`: Production server IPs and SSH key paths.
- `inventory/dev/hosts.yml`: Development/Local environment test IPs.

**Example `hosts.yml` update:**
```yaml
all:
  hosts:
    uds-server01:
      ansible_host: 103.131.85.183
      ansible_ssh_private_key_file: /path/to/your/key
    uds-server02:
      ansible_host: 103.131.85.163
```

### 2. Group Variables

Global configuration is managed in `inventory/prod/group_vars/all.yml`:
- **`domain`**: Your UDS domain (e.g., `pv-vds.tk`).
- **`vip`**: The floating IP managed by Keepalived.
- **`django_allowed_hosts`**: Set to `"*"` or a specific list.
- **`ssl_use_pem`**: Set to `true` to use one `.pem` file, or `false` for separate `.crt` and `.key`.

### 3. SSL Certificates

Place your SSL files in `files/ssl/`:
- Mode 1 (Separate): `pv-vds.tk.crt` and `pv-vds.tk.key`.
- Mode 2 (Combined): `pv-vds.tk.pem`.

## Deployment Workflows

Navigate to this directory:
```bash
cd server/deployment/Ansible
```

### Full Stack Deployment
Deploys EVERYTHING (Common, MySQL, OpenUDS, Nginx, HAProxy, Keepalived).
```bash
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml
```

### Application-only Redeploy
Updates only the Django source code and restarts the app.
```bash
ansible-playbook -i inventory/prod/hosts.yml playbooks/deploy_app.yml
```

### Zero-Downtime Rolling Update
Updates nodes one by one, using HAProxy to drain traffic.
```bash
ansible-playbook -i inventory/prod/hosts.yml playbooks/rolling_update.yml
```

## Troubleshooting

- **MySQL GTID Errors**: The `mysql` role handles transitions from `OFF` to `ON` dynamically. If replication fails, check `gtid_mode` on both nodes.
- **OOM Errors**: On small servers (2GB RAM), MySQL might be killed. The `common` role adds a 2GB swap file to mitigate this.
- **Gunicorn Sockets**: If the service fails to start, ensure `/run/openuds/` is owned by `openuds` and no ghost processes are holding the socket. Use `pkill -9 -f gunicorn` to clean up.
