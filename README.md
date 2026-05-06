# Ansible NiFi + ZooKeeper Cluster Deployment (Podman)

This Ansible project deploys a NiFi cluster connected to a ZooKeeper cluster using Podman containers.

## Prerequisites

- Ansible installed on control machine
- SSH access to all target servers
- Ubuntu/Debian based servers (for RHEL/CentOS change apt to dnf/yum)
- Podman will be installed automatically

## Inventory Configuration

Edit `inventory/hosts.ini` and update:
- IP addresses for ZooKeeper servers (zk1, zk2, zk3)
- IP addresses for NiFi servers (nifi1, nifi2, nifi3)
- SSH user and key path

## Usage

### Deploy entire stack:
```bash
ansible-playbook -i inventory/hosts.ini site.yml
```

### Deploy only ZooKeeper:
```bash
ansible-playbook -i inventory/hosts.ini site.yml --limit zookeeper
```

### Deploy only NiFi:
```bash
ansible-playbook -i inventory/hosts.ini site.yml --limit nifi
```

### Check container status:
```bash
ansible zookeeper -i inventory/hosts.ini -m shell -a "podman ps | grep zookeeper"
ansible nifi -i inventory/hosts.ini -m shell -a "podman ps | grep nifi"
```

### View logs:
```bash
ansible nifi -i inventory/hosts.ini -m shell -a "podman logs nifi"
```

### Execute commands in container:
```bash
ansible nifi -i inventory/hosts.ini -m shell -a "podman exec nifi bash -c 'echo stat | nc localhost 2181'"
```

## Configuration

### ZooKeeper Variables (`group_vars/zookeeper.yml`):
- `zookeeper_version`: ZooKeeper image version (default: 3.9.2)
- `zookeeper_client_port`: Client connection port (default: 2181)

### NiFi Variables (`group_vars/nifi.yml`):
- `nifi_version`: NiFi image version (default: 1.25.0)
- `nifi_web_http_port`: HTTP port (default: 8080)
- `nifi_use_keycloak`: Enable Keycloak OIDC authentication (default: false)
- `keycloak_url`: Keycloak server URL (e.g., https://keycloak.example.com)
- `keycloak_realm`: Keycloak realm name (default: nifi)
- `keycloak_client_id`: Keycloak client ID (default: nifi-client)
- `keycloak_client_secret`: Keycloak client secret
- `nifi_initial_admin`: Keycloak user to set as initial NiFi admin

## Access

After deployment:
- ZooKeeper: `server_ip:2181`
- NiFi UI (without Keycloak): `http://nifi_server_ip:8080/nifi`
- NiFi UI (with Keycloak): `https://nifi_server_ip:8443/nifi`

Note: When Keycloak authentication is enabled, only the HTTPS port (8443) is exposed. HTTP port (8080) is not accessible.

## Keycloak Integration

To enable Keycloak OIDC authentication:

1. Set `nifi_use_keycloak: true` in `group_vars/nifi.yml`
2. Configure Keycloak settings:
   - `keycloak_url`: Your Keycloak server URL
   - `keycloak_realm`: Realm name in Keycloak
   - `keycloak_client_id`: Client ID configured in Keycloak
   - `keycloak_client_secret`: Client secret from Keycloak
   - `nifi_initial_admin`: Keycloak user email to grant admin rights
3. In Keycloak, create a client with:
   - Client ID matching `keycloak_client_id`
   - Access Type: `confidential`
   - Valid Redirect URIs: `https://nifi_server_ip:8443/*`
   - Enable "Standard Flow" and "Direct Access Grants"
4. Deploy NiFi: `ansible-playbook -i inventory/hosts.ini site.yml --limit nifi`

## Custom SSL Keystore/Truststore

When using Keycloak authentication, custom SSL certificates are required for HTTPS.

1. Place your `keystore.jks` and `truststore.jks` files in the `files/` directory
2. Update the following variables in `group_vars/nifi.yml`:
   - `nifi_keystore_password`: Your keystore password
   - `nifi_truststore_password`: Your truststore password
   - `nifi_keystore_type`: Keystore type (JKS, PKCS12, etc.)
   - `nifi_truststore_type`: Truststore type
3. The files will be automatically copied to `/opt/nifi/ssl/` on each NiFi server and mounted into the container

Note: SSL files in `files/` are not committed to git (see .gitignore)

## Cluster Architecture

```
ZooKeeper Cluster (3 nodes as Podman containers)
    ├── zk1:2181
    ├── zk2:2181
    └── zk3:2181

NiFi Cluster (3 nodes as Podman containers)
    ├── nifi1:8080 (connected to ZK)
    ├── nifi2:8080 (connected to ZK)
    └── nifi3:8080 (connected to ZK)
```

## Container Images Used

- ZooKeeper: `bitnami/zookeeper`
- NiFi: `apache/nifi`

## Notes

- Minimum 3 servers recommended for ZooKeeper quorum
- NiFi cluster requires ZooKeeper to be running first
- The playbook handles the dependency order automatically
- Podman is daemonless, containers run as systemd services via --restart always
- Data is persisted using bind mounts
- Adjust resources based on your server capacity

## Kubernetes Deployment

See [k8s/README.md](k8s/README.md) for deploying the clusters on Kubernetes using native manifests. Includes HAProxy as load balancer.

Quick start:
```bash
kubectl apply -f k8s/zookeeper/
kubectl apply -f k8s/nifi/
kubectl apply -f k8s/haproxy/
```
