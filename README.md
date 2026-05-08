# Ansible NiFi + ZooKeeper Cluster Deployment (Podman)

Deploy a NiFi cluster connected to ZooKeeper with HAProxy as load balancer, all using Podman containers. Supports Keycloak OIDC authentication, custom SSL certificates, and includes security hardening with Ansible Vault, UFW firewall, and log rotation.

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Inventory Configuration](#inventory-configuration)
- [Ansible Vault Setup](#ansible-vault-setup)
- [Usage](#usage)
- [Configuration](#configuration)
- [Security Features](#security-features)
- [Secret Rotation](#secret-rotation)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Backup and Restore](#backup-and-restore)
- [Troubleshooting](#troubleshooting)
- [License](#license)

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  ZooKeeper  │     │  ZooKeeper  │     │  ZooKeeper  │
│    zk1      │─────│    zk2      │─────│    zk3      │
│   :2181     │     │   :2181     │     │   :2181     │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                    │                    │
       └────────────────────┼────────────────────┘
                            │
       ┌────────────────────┼────────────────────┐
       │                    │                    │
┌──────▼──────┐     ┌──────▼──────┐     ┌──────▼──────┐
│    NiFi     │     │    NiFi     │     │    NiFi     │
│   nifi1    │─────│   nifi2    │─────│   nifi3    │
│  :8080/8443│     │  :8080/8443│     │  :8080/8443│
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                    │                    │
       └────────────────────┼────────────────────┘
                            │
                    ┌───────▼───────┐
                    │    HAProxy    │
                    │   :8443/:8404│
                    └───────┬───────┘
                            │
                    ┌───────▼───────┐
                    │   Keycloak   │
                    │  (external)  │
                    └───────────────┘
```

## Prerequisites

- Ansible >= 2.15 installed on control machine
- SSH access to all target servers
- Ubuntu/Debian based servers (for RHEL/CentOS change `apt` to `dnf`/`yum` in roles)
- Podman will be installed automatically by the playbook
- At least 3 servers for ZooKeeper quorum
- At least 1 server for HAProxy (can be separate or shared)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/Giwi/nifi-cluster-ansible.git
cd nifi-cluster-ansible

# Setup vault (see Ansible Vault Setup below)
ansible-vault create group_vars/all/vault.yml

# Place SSL certificates in files/ directory (if using SSL)
# See VAULT.md for required vault variables

# Deploy entire stack
ansible-playbook -i inventory/hosts.ini --ask-vault-pass site.yml
```

## Inventory Configuration

Edit `inventory/hosts.ini` and configure your servers:

```ini
[zookeeper]
zk1 ansible_host=192.168.1.10
zk2 ansible_host=192.168.1.11
zk3 ansible_host=192.168.1.12

[nifi]
nifi1 ansible_host=192.168.1.20
nifi2 ansible_host=192.168.1.21
nifi3 ansible_host=192.168.1.22

[haproxy]
haproxy1 ansible_host=192.168.1.30

[all:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=~/.ssh/id_rsa
```

## Ansible Vault Setup

Create the vault file with all required passwords:

```bash
ansible-vault create group_vars/all/vault.yml
```

Required vault variables (see `docs/VAULT.md` for complete example):

```yaml
---
vault_zookeeper_keystore_password: "StrongPassword123!"
vault_zookeeper_truststore_password: "StrongPassword123!"
vault_nifi_keystore_password: "StrongPassword123!"
vault_nifi_truststore_password: "StrongPassword123!"
vault_nifi_sensitive_props_key: "32-byte-base64-encoded-key=="
vault_keycloak_client_secret: "keycloak-client-secret"
vault_haproxy_stats_password: "ha-stats-password"
vault_grafana_admin_password: "grafana-password"  # if monitoring enabled
```

The vault password file is stored in `.vault_pass` (automatically added to `.gitignore`).

## Usage

### Deploy Entire Stack
```bash
ansible-playbook -i inventory/hosts.ini --ask-vault-pass site.yml
```

### Deploy Specific Components
```bash
# Only ZooKeeper
ansible-playbook -i inventory/hosts.ini site.yml --limit zookeeper --tags zookeeper

# Only NiFi
ansible-playbook -i inventory/hosts.ini site.yml --limit nifi --tags nifi

# Only HAProxy
ansible-playbook -i inventory/hosts.ini site.yml --limit haproxy --tags haproxy
```

### Validate Deployment
```bash
ansible-playbook -i inventory/hosts.ini --ask-vault-pass validate.yml
```

### Cleanup (Remove Everything)
```bash
ansible-playbook -i inventory/hosts.ini --ask-vault-pass cleanup.yml
```

### Check Container Status
```bash
ansible zookeeper -i inventory/hosts.ini -m shell -a "podman ps | grep zookeeper"
ansible nifi -i inventory/hosts.ini -m shell -a "podman ps | grep nifi"
ansible haproxy -i inventory/hosts.ini -m shell -a "podman ps | grep haproxy"
```

### View Logs
```bash
ansible nifi -i inventory/hosts.ini -m shell -a "podman logs nifi"
ansible zookeeper -i inventory/hosts.ini -m shell -a "podman logs zookeeper"
```

## Configuration

### ZooKeeper Variables (`group_vars/zookeeper.yml`)
- `zookeeper_version`: ZooKeeper image version (default: `3.9.5`)
- `zookeeper_client_port`: Client connection port (default: `2181`)
- `zookeeper_ssl_enabled`: Enable SSL/TLS (default: `false`)
- Place `keystore.jks` and `truststore.jks` in `files/` directory

### NiFi Variables (`group_vars/nifi.yml`)
- `nifi_version`: NiFi image version (default: `2.9.0`)
- `nifi_web_http_port`: HTTP port (default: `8080`)
- `nifi_web_https_port`: HTTPS port (default: `8443`)
- `nifi_use_keycloak`: Enable Keycloak OIDC (default: `false`)
- `keycloak_url`: Keycloak server URL
- `keycloak_realm`: Keycloak realm name (default: `nifi`)
- `keycloak_client_id`: Keycloak client ID (default: `nifi-client`)
- `nifi_initial_admin`: Keycloak user for initial admin
- `nifi_sensitive_props_key`: Stored in vault (passed via file, not env var)

### HAProxy Variables (`group_vars/haproxy.yml`)
- `haproxy_stats_port`: Stats page port (default: `8404`)
- `haproxy_frontend_port`: Frontend port (default: `8443`)
- `haproxy_ssl_termination`: Enable SSL termination (default: `false`)
- `haproxy_stats_password`: Stats page password (stored in vault)

## Security Features

- **Ansible Vault**: All passwords encrypted in `group_vars/all/vault.yml`
- **Firewall (UFW)**: Ports restricted to specific source IPs
  - ZooKeeper ports only accessible from NiFi and other ZooKeeper nodes
  - NiFi HTTPS only accessible from HAProxy
  - HAProxy stats page restricted to admin network (default: localhost)
- **Strong Passwords**: Defaults changed, stored in vault
- **HAProxy Stats Auth**: Stats page requires authentication
- **No Anonymous Login**: `ALLOW_ANONYMOUS_LOGIN=no` for ZooKeeper
- **Container Resource Limits**: Memory and CPU limits applied
- **Health Checks**: Configured for all containers
- **Sensitive Props via File**: NiFi sensitive properties passed via `nifi.properties` file, not environment variables
- **Secret Rotation**: Automated secret rotation available (see below)

## Secret Rotation

### Automated Secret Rotation

The playbook includes a secret rotation mechanism for NiFi:

```bash
# Setup secret rotation (runs weekly on Sundays at 2am)
ansible-playbook -i inventory/hosts.ini --ask-vault-pass site.yml --tags security
```

### Manual Secret Rotation

Run the rotation script manually:

```bash
# On NiFi servers
/opt/nifi/scripts/rotate-nifi-secrets.sh

# Or rotate all secrets across the cluster
./scripts/rotate-all-secrets.sh
```

The rotation script:
1. Generates new sensitive properties key
2. Updates vault with new key
3. Restarts NiFi to apply changes

## Kubernetes Deployment

Deploy on Kubernetes using native manifests:

```bash
# Apply manifests in order
kubectl apply -f k8s/zookeeper/
kubectl apply -f k8s/nifi/
kubectl apply -f k8s/haproxy/
```

### K8s Manifests Structure
- `k8s/zookeeper/statefulset.yaml` - ZooKeeper StatefulSet
- `k8s/nifi/statefulset.yaml` - NiFi StatefulSet
- `k8s/haproxy/deployment.yaml` - HAProxy Deployment
- `k8s/*/configmap.yaml` - Configuration files
- `k8s/network-policies.yaml` - Network policies

See `docs/K8S.md` for detailed K8s deployment instructions.

## Backup and Restore

### Automated Backups

Backups are scheduled automatically via cron:
- ZooKeeper: Daily at 2:00 AM
- NiFi: Daily at 3:00 AM
- Old backups cleaned up after 7 days

### Manual Backup
```bash
ansible-playbook -i inventory/hosts.ini --ask-vault-pass site.yml --tags backup -e "run_backup=true"
```

### Restore from Backup
```bash
ansible-playbook -i inventory/hosts.ini --ask-vault-pass restore.yml -e "restore_file=/opt/backups/nifi/backup.tar.gz"
```

## Troubleshooting

### ZooKeeper Quorum Issues
```bash
# Check ZooKeeper status on each node
ansible zookeeper -i inventory/hosts.ini -m shell -a "echo stat | nc localhost 2181 | grep Mode"

# Expected output: one "leader", others "follower"
```

### NiFi Not Starting
```bash
# Check NiFi logs
ansible nifi -i inventory/hosts.ini -m shell -a "podman logs nifi --tail 50"

# Verify ZooKeeper connectivity
ansible nifi -i inventory/hosts.ini -m shell -a "podman exec nifi bash -c 'echo stat | nc zk1 2181'"
```

### HAProxy Stats Page Unreachable
```bash
# Check HAProxy configuration
ansible haproxy -i inventory/hosts.ini -m shell -a "podman exec haproxy cat /usr/local/etc/haproxy/haproxy.cfg"

# Verify stats port
ansible haproxy -i inventory/hosts.ini -m shell -a "podman exec haproxy netstat -tlnp | grep 8404"
```

### Keycloak OIDC Issues
1. Verify Keycloak URL is accessible from NiFi servers
2. Check client ID and secret in vault
3. Ensure `nifi.initial.admin` user exists in Keycloak
4. Check NiFi logs for OIDC errors

### YAML Lint Errors
```bash
# Run yamllint to check for YAML syntax errors
yamllint /home/xavier/workspace/ansible-nifi-zk

# Fix common issues:
# - Replace "yes"/"no" with "true"/"false"
# - Break lines longer than 80 characters
# - Ensure 2-space indentation in K8s manifests
```

### Container Health Check Failures
```bash
# Check health status
ansible nifi -i inventory/hosts.ini -m shell -a "podman healthcheck run nifi"
ansible zookeeper -i inventory/hosts.ini -m shell -a "podman healthcheck run zookeeper"
```

## Testing

The project includes Molecule tests for each role:

```bash
# Test ZooKeeper role
cd roles/zookeeper && molecule test

# Test NiFi role
cd roles/nifi && molecule test

# Test HAProxy role
cd roles/haproxy && molecule test
```

## Project Structure

```
.
├── group_vars/
│   ├── all/vault.yml      # Encrypted secrets (create with ansible-vault)
│   ├── zookeeper.yml      # ZooKeeper configuration
│   ├── nifi.yml           # NiFi configuration
│   └── haproxy.yml        # HAProxy configuration
├── roles/
│   ├── zookeeper/         # ZooKeeper deployment role
│   ├── nifi/              # NiFi deployment role
│   └── haproxy/           # HAProxy deployment role
├── k8s/                   # Kubernetes manifests
│   ├── zookeeper/
│   ├── nifi/
│   └── haproxy/
├── files/                  # SSL certificates (not committed)
├── scripts/                # Utility scripts
├── site.yml               # Main deployment playbook
├── validate.yml           # Validation playbook
├── restore.yml            # Restore playbook
├── cleanup.yml            # Cleanup playbook
└── README.md
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin feature/my-feature`)
5. Create a Pull Request

## Notes

- Minimum 3 servers recommended for ZooKeeper quorum
- NiFi cluster requires ZooKeeper to be running first
- Podman is daemonless; containers run with `--restart always`
- Data is persisted using bind mounts
- Adjust resources (memory, CPU) based on server capacity
- SSL files in `files/` are not committed to git (see `.gitignore`)
- Firewall rules are applied automatically via UFW in each role
- For flow version management, use GitLab (NiFi Registry not included)
