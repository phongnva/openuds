# OpenUDS Tunnel Server - Ansible Deployment

This directory contains Ansible playbooks to deploy the OpenUDS Tunnel Server in **two modes**:

| Mode | Playbook | Description |
|---|---|---|
| Single node | `playbooks/deploy_tunnel.yml` | One tunnel node (simple) |
| **HA cluster** | **`playbooks/deploy_tunnel_ha.yml`** | Two nodes + HAProxy + Keepalived VIP |

---

## HA Deployment (Recommended for Production)

### Architecture

```
UDS Client (TCP 8443)
       │
       ▼
  VIP: <ha_vip>:8443   ← Keepalived VRRP floating IP
       │
       ▼
  HAProxy (on both nodes)
       ├── uds-tunnel01:8443  (MASTER, priority 100)
       └── uds-tunnel02:8443  (BACKUP, priority 90)
```

When tunnel01 fails: Keepalived moves the VIP to tunnel02 in ~2 s. HAProxy detects the dead backend and removes it from the pool. New sessions reconnect through the healthy node automatically.

### Prerequisites

- Two servers with SSH key access (root)
- Same SSL certificate deployed on both nodes
- Both nodes on the **same L2 subnet** (VRRP requires L2 multicast/broadcast)
- An unused IP on that subnet for the VIP

### Configuration

Edit `inventory/hosts.yml`:
```yaml
uds-tunnel01:
  ansible_host: <IP1>
uds-tunnel02:
  ansible_host: <IP2>    # ← set this
```

Edit `inventory/group_vars/all.yml` — fill in the `CHANGE_ME` values:
```yaml
ha_vip: 103.131.85.190       # unused IP in same subnet
ha_vip_interface: eth0       # check with: ip link show
keepalived_auth_pass: secret
haproxy_stats_pass: secret

# UDS Broker admin credentials (used by register-tunnel.sh)
uds_broker_url: "https://your-uds-broker.example.com"
uds_admin_user: "admin"
uds_admin_password: "{{ vault_uds_admin_password }}"  # use Ansible Vault
```

### Deploy

```bash
cd tunnel-server/deployment/Ansible

# Full HA deployment
ansible-playbook playbooks/deploy_tunnel_ha.yml

# Deploy only the HA layer (HAProxy + Keepalived) without reinstalling tunnel
ansible-playbook playbooks/deploy_tunnel_ha.yml --tags ha

# Dry run
ansible-playbook playbooks/deploy_tunnel_ha.yml --check --diff
```

### Post-deployment

1. In OpenUDS Admin, set the Tunnel Server URL to `https://<ha_vip>:8443`
2. Assign tunnel servers to a **Tunnel Group** in OpenUDS Admin → Connectivity → Tunnels
3. HAProxy stats page: `http://<node-ip>:9000/stats` (admin / `haproxy_stats_pass`)

### Failover Test

```bash
# On MASTER node — kill tunnel service
ssh root@<tunnel01> systemctl stop udstunnel

# Verify VIP moved to BACKUP
ssh root@<tunnel02> ip addr show eth0   # should show VIP

# Restore
ssh root@<tunnel01> systemctl start udstunnel
```

---

## Single-Node Deployment

### Prerequisites

- Ansible on control node, SSH key access to target
- UDS Broker admin credentials (to auto-register tunnel via REST API)
- SSL certificates placed on the target server

### Configuration

Edit `inventory/hosts.yml` with the server IP.  
Edit `inventory/group_vars/all.yml`:

```yaml
# UDS Broker admin credentials for tunnel auto-registration
uds_broker_url: "https://your-uds-broker.example.com"
uds_admin_user: "admin"
uds_admin_password: "{{ vault_uds_admin_password }}"

# Encrypt your password with Ansible Vault:
# ansible-vault encrypt_string '<password>' --name vault_uds_admin_password
```

### Deploy

```bash
cd tunnel-server/deployment/Ansible
ansible-playbook playbooks/deploy_tunnel.yml
```

---

## Tunnel Registration (REST API)

Starting from UDS v3.6+, tunnel servers are **no longer registered by inserting directly into the database**.
Registration is now done via the UDS Broker REST API automatically during deployment.

The `register-tunnel.sh` script (deployed by Ansible to `/usr/local/bin/`) performs:

1. `POST /uds/rest/auth/login` — authenticates with the UDS Broker (admin credentials)
2. `POST /uds/rest/servers/register` — registers the tunnel server (`type=2`) and receives a `token`
3. Writes `uds_token = <token>` into `/etc/openuds-tunnel/udstunnel.conf`
4. Restarts `udstunnel` automatically if the token changed

> **After registration**, assign the tunnel server to a Tunnel Group in OpenUDS Admin:
> `Connectivity → Tunnels → [Your Group] → Servers → Assign`
>
> The Tunnel Group's `host` and `port` (e.g. the HAProxy VIP) are what UDS Clients connect to.

To re-register manually at any time:
```bash
ssh root@<tunnel-host> /usr/local/bin/register-tunnel.sh
```

---

## Performance Tuning

OS-level kernel tuning applied automatically:
- **BBR** congestion control (lower latency)
- **MTU probing** (avoids PMTUD black holes)
- **16 MB kernel buffers** (bursty RDP traffic)
- **TCP Fast Open** (saves 1 RTT)
- **SACK** (faster packet loss recovery)
- **60 s keepalive** (detect dead connections faster)

---

## Service Management

```bash
sudo systemctl status udstunnel
sudo systemctl restart udstunnel
sudo journalctl -u udstunnel -f

sudo systemctl status haproxy
sudo systemctl status keepalived
```

| File | Path |
|---|---|
| Tunnel config | `/etc/openuds-tunnel/udstunnel.conf` |
| Tunnel logs | `/var/log/openuds-tunnel/udstunnel.log` |
| Registration script | `/usr/local/bin/register-tunnel.sh` |
| HAProxy config | `/etc/haproxy/haproxy.cfg` |
| Keepalived config | `/etc/keepalived/keepalived.conf` |
| Code / Venv | `/opt/openuds-tunnel/` |
