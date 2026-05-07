# Ansible NiFi + ZooKeeper Cluster Deployment (Podman)

This Ansible project deploys a NiFi cluster connected to a ZooKeeper cluster using Podman containers, with HAProxy as load balancer.

## Prerequisites

- Ansible installed on control machine
- SSH access to all target servers
- Ubuntu/Debian based servers (for RHEL/CentOS change apt to dnf/yum)
- Podman will be installed automatically

## Inventory Configuration

Edit `inventory/hosts.ini` and update:
- IP addresses for ZooKeeper servers (zk1, zk2, zk3)
- IP addresses for NiFi servers (nifi1, nifi2, nifi3)
- IP address for HAProxy server (haproxy1)
- SSH user and key path

## Setup Ansible Vault (first time):
```bash
ansible-vault create group_vars/all/vault.yml
# Copy variables from the example in VAULT.md
```

## Usage

### Deploy entire stack:
```bash
ansible-playbook -i inventory/hosts.ini --ask-vault-pass site.yml
```

### Deploy only ZooKeeper:
```bash
ansible-playbook -i inventory/hosts.ini site.yml --limit zookeeper
```

### Deploy only NiFi:
```bash
ansible-playbook -i inventory/hosts.ini site.yml --limit nifi
```

### Deploy only HAProxy:
```bash
ansible-playbook -i inventory/hosts.ini site.yml --limit haproxy
```

### Cleanup (remove everything):
```bash
ansible-playbook -i inventory/hosts.ini --ask-vault-pass cleanup.yml
```

### Check container status:
```bash
ansible zookeeper -i inventory/hosts.ini -m shell -a "podman ps | grep zookeeper"
ansible nifi -i inventory/hosts.ini -m shell -a "podman ps | grep nifi"
ansible haproxy -i inventory/hosts.ini -m shell -a "podman ps | grep haproxy"
```

### View logs:
```bash
ansible nifi -i inventory/hosts.ini -m shell -a "podman logs nifi"
```

## Configuration

### ZooKeeper Variables (`group_vars/zookeeper.yml`):
- `zookeeper_version`: ZooKeeper image version (default: 3.9.5)
- `zookeeper_client_port`: Client connection port (default: 2181)
- `zookeeper_ssl_enabled`: Enable SSL/TLS for ZooKeeper (default: false)
- `zookeeper_keystore_password`: Keystore password (stored in vault)
- `zookeeper_truststore_password`: Truststore password (stored in vault)
- Place `keystore.jks` and `truststore.jks` in `files/` directory

### NiFi Variables (`group_vars/nifi.yml`):
- `nifi_version`: NiFi image version (default: 2.9.0)
- `nifi_web_http_port`: HTTP port (default: 8080)
- `nifi_use_keycloak`: Enable Keycloak OIDC authentication (default: false)
- `keycloak_url`: Keycloak server URL (e.g., https://keycloak.example.com)
- `keycloak_realm`: Keycloak realm name (default: nifi)
- `keycloak_client_id`: Keycloak client ID (default: nifi-client)
- `keycloak_client_secret`: Keycloak client secret (stored in vault)
- `nifi_initial_admin`: Keycloak user to set as initial NiFi admin
- `nifi_sensitive_props_key`: Sensitive props key (stored in vault)

### HAProxy Variables (`group_vars/haproxy.yml`):
- `haproxy_stats_port`: Stats page port (default: 8404)
- `haproxy_frontend_port`: Frontend port (default: 8443)
- `haproxy_ssl_termination`: Enable SSL termination (default: false)
- `haproxy_stats_password`: Stats page password (stored in vault)

## Access

After deployment:
- ZooKeeper: `server_ip:2181`
- NiFi UI (without Keycloak): `http://nifi_server_ip:8080/nifi`
- NiFi UI (with Keycloak): `https://nifi_server_ip:8443/nifi`
- NiFi UI (via HAProxy): `https://haproxy_server_ip:8443/nifi`
- HAProxy stats: `http://haproxy_server_ip:8404/stats` (requires auth)

Note: When Keycloak authentication is enabled, only the HTTPS port (8443) is exposed. HTTP port (8080) is not accessible.

## HAProxy SSL Certificate

To use a provided SSL certificate with HAProxy (Ansible deployment):
1. Place your `nifi.pem` (cert+key combined) in `files/nifi.pem`
2. Set `haproxy_ssl_termination: true` in `group_vars/haproxy.yml`
3. Deploy: `ansible-playbook -i inventory/hosts.ini site.yml --limit haproxy`

For Kubernetes HAProxy, see [k8s/haproxy/README.md](k8s/haproxy/README.md)

## Security Features

- **Ansible Vault**: All passwords stored encrypted in `group_vars/all/vault.yml`
- **Firewall (UFW)**: Ports restricted to specific source IPs
  - ZooKeeper ports only accessible from NiFi nodes and other ZooKeeper nodes
  - NiFi HTTPS only accessible from HAProxy
  - HAProxy stats page restricted to admin network (default: localhost)
- **Strong passwords**: Default passwords changed to strong ones (stored in vault)
- **HAProxy stats auth**: Stats page requires username/password

## Log Rotation

Log rotation is automatically configured for:
- Podman container logs (7 days retention)
- Application logs (ZooKeeper, NiFi, HAProxy - 7 days retention)

## Kubernetes Deployment

See [k8s/README.md](k8s/README.md) for deploying the clusters on Kubernetes using native manifests. Includes HAProxy as load balancer.

Quick start:
```bash
kubectl apply -f k8s/zookeeper/
kubectl apply -f k8s/nifi/
kubectl apply -f k8s/haproxy/
```

## Notes

- Minimum 3 servers recommended for ZooKeeper quorum
- NiFi cluster requires ZooKeeper to be running first
- The playbook handles the dependency order automatically
- Podman is daemonless, containers run as systemd services via --restart always
- Data is persisted using bind mounts
- Adjust resources based on your server capacity
- SSL files in `files/` are not committed to git (see .gitignore)
- Firewall rules are applied automatically via UFW role
