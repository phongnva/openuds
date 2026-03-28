# =============================================================================
# OpenUDS Server HA - Ansible Deployment
# =============================================================================

## Overview
Ansible playbook to deploy OpenUDS Django server on 2 nodes with full HA:

| Component     | Details                                              |
|---------------|------------------------------------------------------|
| Server 01     | 103.131.85.183 (Primary/MASTER)                      |
| Server 02     | 103.131.85.163 (Secondary/BACKUP)                    |
| VIP           | 103.131.85.232                                       |
| Domain        | pv-vds.tk                                            |
| Python        | 3.12                                                 |
| Database      | MySQL 8.0 (Primary-Replica replication)              |
| App Server    | Gunicorn (unix socket, systemd)                      |
| Web Server    | Nginx (SSL, port 8443)                               |
| Load Balancer | HAProxy (HTTPS :443 → Nginx :8443)                   |
| HA Failover   | Keepalived (VRRP, VIP failover)                      |

## Architecture
```
                    [pv-vds.tk / 103.131.85.232 VIP]
                              │
                    ┌─────────┴─────────┐
                    │   Keepalived VIP  │
                    └─────────┬─────────┘
              ┌───────────────┴───────────────┐
    ┌─────────┴─────────┐           ┌─────────┴─────────┐
    │  Server 01        │           │  Server 02        │
    │  103.131.85.183   │           │  103.131.85.163   │
    │  (MASTER)         │           │  (BACKUP)         │
    ├───────────────────┤           ├───────────────────┤
    │  HAProxy :443     │           │  HAProxy :443     │
    │  Nginx   :8443    │           │  Nginx   :8443    │
    │  Gunicorn (socket)│           │  Gunicorn (socket)│
    │  TaskManager      │           │  TaskManager      │
    │  MySQL (Primary)  │           │  MySQL (Replica)  │
    └───────────────────┘           └───────────────────┘
```

## Prerequisites
- Ansible 2.12+ installed on control machine
- SSH key access to both servers (private_key)
- Ubuntu 22.04/24.04 on target servers

## Quick Start

```bash
# From the project root directory
cd ansible

# Test connectivity
ansible -i hosts.ini openuds -m ping

# Dry run
ansible-playbook -i hosts.ini site.yml --check

# Full deployment
ansible-playbook -i hosts.ini site.yml

# Deploy specific component only
ansible-playbook -i hosts.ini site.yml --tags nginx
ansible-playbook -i hosts.ini site.yml --tags mysql
ansible-playbook -i hosts.ini site.yml --tags openuds_server
```

## Systemd Services
```bash
# Check service status
systemctl status openuds-server.socket
systemctl status openuds-server.service
systemctl status openuds-server-taskmanager.service

# Restart all OpenUDS services
systemctl restart openuds-server.socket
systemctl restart openuds-server.service
systemctl restart openuds-server-taskmanager.service
```

## Configuration
All variables are in `group_vars/all.yml`. Key settings to customize:
- `mysql_root_password` / `db_password` - Database credentials
- `django_secret_key` - Django secret key
- `keepalived_vip` - Virtual IP address
- `domain_name` - Domain name
