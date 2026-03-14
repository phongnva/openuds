# OpenUDS HA Deployment with Ansible

This directory contains the Ansible playbooks and roles for deploying OpenUDS in a High Availability (HA) configuration.

## Architecture Overview

The deployment sets up a robust cluster comprising:
- **Load Balancers**: 2 nodes running **HAProxy** and **Keepalived** for a floating Virtual IP (VIP).
- **Web Servers**: 2 nodes running **Nginx** as a reverse proxy for Gunicorn.
- **App Servers**: 2 nodes running **OpenUDS (Gunicorn + TaskManager)**.
- **Database**: 2 nodes running **MariaDB** with **Galera Cluster** (multi-master synchronous replication).

| Role | Server 01 | Server 02 | VIP |
|------|-----------|-----------|-----|
| IP | 103.131.85.183 | 103.131.85.163 | 103.131.85.232 |
| MariaDB | Galera Node (Bootstrap) | Galera Node (Joiner) | - |
| HAProxy | HTTPS (:443) + MariaDB (:3307) | HTTPS (:443) + MariaDB (:3307) | 103.131.85.232 |
| Keepalived | MASTER (priority 101) | BACKUP (priority 100) | Floating VIP |

## Prerequisites

1.  **Ansible**: Version 2.12 or higher installed on your control machine.
2.  **SSH Access**: Key-based SSH access to the target servers (`root` user recommended).
3.  **OS**: Ubuntu 24.04 (Noble) or 22.04 (Jammy).
4.  **Dependencies**: `python3-pymysql` must be installed on the target nodes (handled automatically by roles).

## Roles

### `mysql` — MariaDB Installation & Configuration
- Installs **MariaDB Server**, **MariaDB Client**, **mariadb-backup**, and **Galera-4**
- Deploys Galera wsrep configuration to `/etc/mysql/mariadb.conf.d/99-galera.cnf`
- Starts MariaDB temporarily **without wsrep** (`--wsrep-on=OFF`) to set the root password
- Stops MariaDB after password setup — cluster startup is handled by `mariadb_galera`

### `mariadb_galera` — Galera Cluster Bootstrap & Join
Follows the [SeveralNines Galera bootstrap guide](https://severalnines.com/blog/updated-how-bootstrap-mysql-or-mariadb-galera-cluster/).

**Bootstrap node** (first node, `galera_bootstrap: true`):
1. Stops MariaDB
2. Sets `safe_to_bootstrap: 1` in `/var/lib/mysql/grastate.dat`
3. Runs `galera_new_cluster`
4. Waits for `wsrep_cluster_status = Primary`
5. Creates all database users (app, SST, HAProxy health-check, replication)

**Joiner nodes** (remaining nodes):
1. Stops MariaDB
2. Waits for bootstrap node to reach Primary state
3. Starts MariaDB normally (connects via `gcomm://node1,node2`)
4. Waits for `wsrep_local_state_comment = Synced`

**Verification** outputs `wsrep_cluster_size` and `wsrep_local_state_comment` on all nodes.

### `haproxy` — Load Balancer
- **HTTPS frontend** (`:443`): SSL termination → backend Nginx servers
- **MariaDB frontend** (`:3307`): TCP load balancing → backend Galera nodes on `:3306`
- Health checks: `mysql-check` for DB, HTTP check for web backends
- Sticky sessions via `SERVERID` cookie for UDS session affinity

### `keepalived` — Virtual IP Failover
- VRRP-based VIP failover between MASTER and BACKUP
- Health check script verifies both HAProxy service and listening ports (HTTPS + MariaDB)
- Configurable VIP subnet mask via `keepalived_vip_cidr`

## Setup & Configuration

### 1. Inventory

The inventory is split into `prod` and `dev` environments:
- `inventory/prod/hosts.yml`: Production server IPs and SSH key paths.
- `inventory/dev/hosts.yml`: Development/Local environment test IPs.

**Example `hosts.yml`:**
```yaml
all:
  children:
    primary:
      hosts:
        uds-server01:
          ansible_host: 103.131.85.183
          keepalived_priority: 101
          keepalived_state: MASTER
          mysql_server_id: 1
          mysql_role: primary
          galera_bootstrap: true    # Bootstrap node
    secondary:
      hosts:
        uds-server02:
          ansible_host: 103.131.85.163
          keepalived_priority: 100
          keepalived_state: BACKUP
          mysql_server_id: 2
          mysql_role: replica
    uds_servers:
      children:
        primary:
        secondary:
```

### 2. Group Variables

Global configuration is managed in `inventory/prod/group_vars/all.yml`:
- **`domain`**: Your UDS domain (e.g., `pv-vds.tk`).
- **`vip`**: The floating IP managed by Keepalived.
- **`haproxy_mysql_port`**: HAProxy MariaDB frontend port (default: `3307`, avoids conflict with local MariaDB on `3306`).
- **`ssl_use_pem`**: Set to `true` for single `.pem` file, or `false` for separate `.crt` and `.key`.
- **`galera_cluster_nodes`**: List of Galera node IPs for `gcomm://`.
- **`galera_sst_method`**: SST method (default: `mariabackup`).

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
Deploys EVERYTHING (Common, MySQL, Galera Cluster, OpenUDS, Nginx, HAProxy, Keepalived).
```bash
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml
```

### Dry-run (Recommended First)
```bash
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --check --diff
```

### Deploying Rebranded Source Code
If you have modified the UI aesthetics or client downloads locally, you must execute the rebranding script to dynamically reconstruct the UI payloads (`main.js`, `index.html` without integrity hashes, etc.) first:
```bash
cd ../../  # Navigate to the server root
./run_rebrand.sh
```

### Application-only Redeploy
Synchronizes the local workspace codebase directly to the remote App nodes and forcibly restarts the `gunicorn` environment to clear rendering caches. Use this to push Python updates or new rebranding modifications.
```bash
ansible-playbook -i inventory/prod/hosts.yml playbooks/deploy_app.yml
```

### Zero-Downtime Rolling Update
Updates nodes one by one, using HAProxy to drain traffic.
```bash
ansible-playbook -i inventory/prod/hosts.yml playbooks/rolling_update.yml
```

## Ansible Tags

All tasks are tagged by category, enabling fine-grained selective runs with `--tags` or `--skip-tags`.

### Tag Reference

| Tag | Task Category | Roles/Files áp dụng |
|-----|---------------|---------------------|
| `packages` | Cài đặt apt packages & Python pip/venv | `common`, `mysql`, `nginx`, `haproxy`, `keepalived`, `openuds` |
| `system` | Quản lý user/group/directory, sysctl | `common`, `nginx`, `haproxy`, `keepalived`, `openuds` |
| `config` | Deploy config templates (`.j2`) & scripts | `common`, `mysql`, `mariadb_galera`, `nginx`, `haproxy`, `keepalived`, `openuds` |
| `ssl` | Deploy SSL certificates và RSA keys | `nginx`, `haproxy`, `openuds` |
| `security` | Passwords, file permissions, keys | `mysql`, `mariadb_galera`, `nginx`, `haproxy`, `openuds` |
| `database` | Tất cả MariaDB/MySQL tasks | `mysql`, `mariadb_galera` |
| `mysql` | MariaDB-specific tasks | `mysql` |
| `galera` | Galera bootstrap / join / verify | `mariadb_galera` (bootstrap, join, verify) |
| `db_users` | Tạo database users & permissions | `mysql/primary`, `mariadb_galera/bootstrap` |
| `app` | Deploy source code OpenUDS | `openuds` |
| `openuds` | Tất cả tasks trong role openuds | `openuds/deploy`, `openuds/migrate` |
| `migrate` | Django migrate, createcachetable, collectstatic | `openuds/migrate` |
| `deploy` | Rsync source code | `openuds/deploy` |
| `nginx` | Tất cả tasks trong role nginx | `nginx` |
| `haproxy` | Tất cả tasks trong role haproxy | `haproxy`, `keepalived` |
| `keepalived` | Tất cả tasks trong role keepalived | `keepalived` |
| `service` | systemd enable/start/restart | `openuds`, `nginx`, `haproxy`, `keepalived`, playbook post_tasks |
| `network` | sysctl `ip_nonlocal_bind` (VIP support) | `haproxy`, `keepalived` |
| `verify` | Kiểm tra trạng thái cluster/services | `mariadb_galera/verify`, playbook post_tasks |
| `rolling_update` | Drain/re-enable HAProxy node trong rolling update | `rolling_update.yml` |
| `common` | Tất cả tasks trong role common | `common` |
| `always` | Tasks luôn chạy (deployment info) | `site.yml` post_tasks |

### Ví dụ sử dụng tags

```bash
# Chỉ cài packages trên tất cả nodes
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --tags packages

# Deploy app code + run migrations (bỏ qua database infrastructure)
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --tags "app,migrate"

# Chỉ update SSL certificates
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --tags ssl

# Chỉ deploy config templates (không restart)
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --tags config

# Bootstrap/join/verify Galera cluster
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --tags galera

# Tạo DB users (sau khi cluster đã chạy)
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --tags db_users

# Chỉ start/enable tất cả services
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --tags service

# Verify cluster và services status
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --tags verify

# Bỏ qua toàn bộ database tasks (deploy infra + app only)
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --skip-tags "database,galera"
```

## Troubleshooting

- **Galera Bootstrap Fails**: Ensure `safe_to_bootstrap: 1` is set in `/var/lib/mysql/grastate.dat` on the bootstrap node. After a hard crash, run `mysqld --wsrep-recover` on each node to find the most advanced one, then set its `safe_to_bootstrap: 1`.
- **MariaDB Won't Start**: Check if another instance is running (`ss -lnt | grep 3306`). Never start MariaDB normally when no cluster exists — use `galera_new_cluster` on the first node.
- **Galera Node Won't Join**: Verify the bootstrap node is in `Primary` state (`SHOW STATUS LIKE 'wsrep_cluster_status'`). Check firewall allows ports `3306`, `4567` (Galera), `4568` (IST), `4444` (SST).
- **HAProxy Port Conflict**: HAProxy MariaDB frontend uses port `3307` by default. Ensure your Django `settings_ha.py` connects to `VIP:3307`.
- **OOM Errors**: On small servers (2GB RAM), MariaDB might be killed. The `common` role adds a 2GB swap file to mitigate this.
- **Gunicorn Sockets**: If the service fails to start, ensure `/run/openuds/` is owned by `openuds` and no ghost processes are holding the socket. Use `pkill -9 -f gunicorn` to clean up.
