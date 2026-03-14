# OpenUDS HA Deployment with Ansible

This directory contains an Ansible-based High Availability deployment for OpenUDS.
The implementation in `server/deployment/Ansible` is designed around a two-node active/passive edge layer with HAProxy + Keepalived, two OpenUDS application nodes, and a two-node MariaDB Galera cluster.

## Architecture Overview

The deployment targets a six-role logical topology mapped onto two servers plus a floating VIP:

- **Load Balancers**: 2 nodes running **HAProxy** and **Keepalived**.
- **Web Layer**: 2 nodes running **Nginx** as reverse proxy in front of Gunicorn.
- **Application Layer**: 2 nodes running **OpenUDS** (`gunicorn` + `taskManager`).
- **Database Layer**: 2 nodes running **MariaDB Galera**.
- **Virtual IP**: 1 floating VIP managed by Keepalived.

| Role | Server 01 | Server 02 | VIP |
|------|-----------|-----------|-----|
| IP | 103.131.85.183 | 103.131.85.163 | 103.131.85.232 |
| MariaDB | Galera bootstrap node | Galera joiner node | - |
| HAProxy | HTTPS `:443` + MariaDB `:3307` | HTTPS `:443` + MariaDB `:3307` | `103.131.85.232` |
| Keepalived | MASTER | BACKUP | Floating VIP |
| Nginx | Reverse proxy to Gunicorn socket | Reverse proxy to Gunicorn socket | - |
| OpenUDS | Gunicorn + TaskManager | Gunicorn + TaskManager | - |

## Repository Layout

The generated deployment assets live under:

```text
server/deployment/Ansible/
+-- ansible.cfg
+-- files/
¦   +-- ssl/
+-- inventory/
¦   +-- dev/
¦   +-- prod/
+-- playbooks/
¦   +-- site.yml
¦   +-- deploy_app.yml
¦   +-- rolling_update.yml
+-- roles/
    +-- common/
    +-- mysql/
    +-- mariadb_galera/
    +-- openuds/
    +-- nginx/
    +-- haproxy/
    +-- keepalived/
```

## Prerequisites

1. **Ansible** `2.12+` on the control host.
2. **SSH access** to all target nodes.
3. **Ubuntu 22.04 or 24.04** on the managed nodes.
4. **TLS certificate material** prepared under `files/ssl/`.
5. **Secrets updated** in `inventory/*/group_vars/all.yml` before any production run.

## Playbooks

### `playbooks/site.yml`

Full deployment flow:

1. Prepare base OS packages and swap.
2. Install MariaDB + Galera dependencies.
3. Bootstrap or join the Galera cluster.
4. Deploy OpenUDS application code and services.
5. Configure Nginx.
6. Configure HAProxy and Keepalived.
7. Verify service state.

Run:

```bash
cd server/deployment/Ansible
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml
```

Dry run:

```bash
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --check --diff
```

### `playbooks/deploy_app.yml`

Application-only redeploy for OpenUDS code changes:

```bash
ansible-playbook -i inventory/prod/hosts.yml playbooks/deploy_app.yml
```

### `playbooks/rolling_update.yml`

Per-node rolling restart with temporary HAProxy drain:

```bash
ansible-playbook -i inventory/prod/hosts.yml playbooks/rolling_update.yml
```

## Inventory Model

Both `inventory/dev/hosts.yml` and `inventory/prod/hosts.yml` define the same logical groups:

- `primary`
- `secondary`
- `uds_servers`
- `load_balancers`
- `web_servers`
- `app_servers`
- `db_servers`

Example:

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
          galera_bootstrap: true
    secondary:
      hosts:
        uds-server02:
          ansible_host: 103.131.85.163
          keepalived_priority: 100
          keepalived_state: BACKUP
          mysql_server_id: 2
          mysql_role: replica
```

## Important Group Variables

Main configuration sits in `inventory/<env>/group_vars/all.yml`.

### Core networking

- `domain`
- `vip`
- `keepalived_vip_cidr`
- `keepalived_router_id`
- `keepalived_auth_pass`
- `keepalived_interface`
- `haproxy_mysql_port`
- `haproxy_stats_bind`
- `cors_allowed_origin`

### OpenUDS application

- `openuds_base_dir`
- `openuds_venv_dir`
- `openuds_runtime_dir`
- `openuds_log_dir`
- `openuds_static_dir`
- `openuds_local_src_dir`
- `openuds_gunicorn_workers`
- `openuds_log_level`
- `openuds_secret_key`
- `openuds_rsa_private_key`
- `openuds_allowed_hosts`
- `openuds_csrf_trusted_origins`
- `openuds_migrate_host`
- `openuds_force_restart`
- `openuds_run_migrations`
- `common_timezone`

### Database and Galera

- `openuds_database_name`
- `openuds_database_user`
- `openuds_database_password`
- `mysql_root_password`
- `mysql_bind_address`
- `galera_cluster_name`
- `galera_sst_method`
- `galera_sst_user`
- `galera_sst_password`
- `haproxy_mysql_check_user`
- `haproxy_mysql_check_password`
- `openuds_replication_user`
- `openuds_replication_password`

## Role Summary

### `common`

- Installs shared OS and Python build dependencies.
- Configures timezone from `common_timezone`.
- Creates `/swapfile` when the host has no swap.

### `mysql`

- Installs `mariadb-server`, `mariadb-client`, `mariadb-backup`, `galera-4`.
- Renders `/etc/mysql/mariadb.conf.d/99-galera.cnf`.
- Enables but stops `mariadb` so cluster orchestration is handled by `mariadb_galera`.

### `mariadb_galera`

- Detects the bootstrap node from `galera_bootstrap` or first DB host.
- Sets `safe_to_bootstrap: 1` when needed.
- Runs `galera_new_cluster` on the bootstrap node.
- Starts joiners and waits for `wsrep_local_state_comment = Synced`.
- Creates the OpenUDS DB user, SST user, HAProxy health-check user, and replication user.

### `openuds`

- Creates the `openuds` system user and directories.
- Builds a Python virtualenv.
- Copies the local `server/` source tree to the remote app host.
- Installs `requirements.txt` inside the virtualenv.
- Renders `settings_ha.py`.
- Deploys systemd units for `openuds-gunicorn` and `openuds-taskmanager`.
- Runs `migrate`, `createcachetable`, and `collectstatic`.

### `nginx`

- Installs Nginx.
- Renders `roles/nginx/templates/nginx_uds.conf.j2`.
- Publishes the site under `/etc/nginx/sites-available/openuds.conf`.
- Removes the default site.

### `haproxy`

- Installs HAProxy.
- Enables `net.ipv4.ip_nonlocal_bind = 1`.
- Builds the TLS PEM file under `/etc/haproxy/certs/`.
- Exposes HTTPS on `:443` and MySQL TCP load balancing on `:3307`.
- Creates `/run/haproxy/admin.sock` for rolling update drain/re-enable actions.

### `keepalived`

- Installs Keepalived.
- Renders a VRRP config using unicast peer mode.
- Tracks HAProxy availability through `/usr/local/bin/check_haproxy.sh`.
- Manages the floating VIP.

## OpenUDS Settings Generation

The HA settings template is intentionally rendered from the full baseline file:

- Source baseline: `server/src/server/settings.py.sample`
- Generated target: `/opt/openuds/src/server/settings_ha.py`
- Rendering template: `roles/openuds/templates/settings_ha.py.j2`

The template inserts the entire `settings.py.sample` content first, then appends HA overrides such as:

- database endpoint switched to `VIP:3307`
- `SECRET_KEY`
- `RSA_KEY`
- `ALLOWED_HOSTS`
- `CSRF_TRUSTED_ORIGINS`
- `TIME_ZONE = "{{ common_timezone }}"`
- `STATIC_ROOT`
- `LOGDIR`
- `LOGLEVEL`

This keeps the generated HA settings aligned with the upstream sample while still making HA-specific values explicit.

## Nginx Security Headers

`roles/nginx/templates/nginx_uds.conf.j2` includes the hardened header mapping below:

- `Cache-Control: no-store`
- `Content-Security-Policy` without `unsafe-inline`, `unsafe-eval`, `data:`, or `blob:`
- `Permissions-Policy: geolocation=(self)`
- `Referrer-Policy: no-referrer-when-downgrade`
- `Strict-Transport-Security: max-age=31536000; includeSubDomains; preload`
- `X-Content-Type-Options: nosniff`
- `X-Frame-Options: SAMEORIGIN`
- `X-XSS-Protection: 1; mode=block`
- `Cross-Origin-Embedder-Policy: require-corp`
- `Cross-Origin-Opener-Policy: same-origin`
- `Cross-Origin-Resource-Policy: same-origin`
- `Access-Control-Allow-Credentials: true`
- `Access-Control-Allow-Origin: {{ cors_allowed_origin }}`
- `ssl_session_tickets off`

Headers are repeated inside `location /uds/res/` to avoid losing them because of Nginx `add_header` inheritance behavior.

## TLS Certificate Layout

Store certificates in `files/ssl/` using one of these modes.

### PEM mode

```text
files/ssl/
+-- <domain>.pem
```

Set:

```yaml
ssl_use_pem: true
```

### CRT + KEY mode

```text
files/ssl/
+-- <domain>.crt
+-- <domain>.key
```

Set:

```yaml
ssl_use_pem: false
```

The HAProxy role assembles the final PEM under `/etc/haproxy/certs/<domain>.pem`.

## Tags

Common tags available across the deployment:

- `packages`
- `system`
- `config`
- `ssl`
- `security`
- `database`
- `mysql`
- `galera`
- `db_users`
- `app`
- `openuds`
- `migrate`
- `deploy`
- `nginx`
- `haproxy`
- `keepalived`
- `service`
- `network`
- `verify`
- `rolling_update`
- `common`
- `always`

Examples:

```bash
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --tags packages
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --tags "app,migrate"
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --tags ssl
ansible-playbook -i inventory/prod/hosts.yml playbooks/site.yml --skip-tags "database,galera"
```

## Rebranding Workflow

If UI artifacts or downloadable clients are rebranded locally, rebuild them before application deployment:

```bash
cd server
./run_rebrand.sh
```

Then redeploy the application layer:

```bash
cd deployment/Ansible
ansible-playbook -i inventory/prod/hosts.yml playbooks/deploy_app.yml
```

## Troubleshooting

### Galera bootstrap fails

- Verify `/var/lib/mysql/grastate.dat` has `safe_to_bootstrap: 1` on the chosen bootstrap node.
- After hard crashes, recover the most advanced node with `mysqld --wsrep-recover`.

### Joiner never reaches `Synced`

- Check ports `3306`, `4444`, `4567`, and `4568`.
- Verify the bootstrap node reports `wsrep_cluster_status = Primary`.

### MariaDB port conflict

- HAProxy exposes MariaDB on `3307`.
- OpenUDS is configured to talk to `VIP:3307`, not local `3306`.

### Gunicorn socket problems

- Ensure `/run/openuds/` is writable by `openuds:www-data`.
- Remove stale sockets or processes before restart.

### Nginx headers missing on static paths

- Check the rendered file under `/etc/nginx/sites-available/openuds.conf`.
- The template defines headers at server level and again under `/uds/res/`.

### Rolling update drain does not work

- Verify HAProxy created `/run/haproxy/admin.sock`.
- Ensure `socat` is installed on the load balancer nodes.

## Notes

- This repository snapshot was prepared from a workspace that did not include `.git` metadata.
- If you want to publish these changes to GitHub, clone the target repo first, copy the updated files, create a branch, commit, and push.
