# Kubernetes Deployment

Deploy ZooKeeper and NiFi clusters on Kubernetes.

## Prerequisites

- Kubernetes cluster (1.24+)
- kubectl configured
- Keystore and truststore files in `files/` directory

## Deploy

1. Create NiFi secrets:
```bash
kubectl apply -f nifi/secrets.yaml.example
kubectl create secret generic nifi-ssl --from-file=../files/keystore.jks --from-file=../files/truststore.jks
```

2. Deploy ZooKeeper:
```bash
kubectl apply -f zookeeper/
```

3. Deploy NiFi:
```bash
kubectl apply -f nifi/configmap.yaml
kubectl apply -f nifi/statefulset.yaml
```

4. Check status:
```bash
kubectl get pods -l app=zookeeper
kubectl get pods -l app=nifi
kubectl get svc nifi-external
```

## Access

After deployment, get the HAProxy external IP:
```bash
kubectl get svc haproxy -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Access NiFi at: `https://<external-ip>:8443/nifi`

View HAProxy stats at: `http://<external-ip>:8404/stats`

## HAProxy Podman (Ansible)

For deploying HAProxy as a Podman container on a separate server (not Kubernetes), see the Ansible role:
```bash
ansible-playbook -i inventory/hosts.ini site.yml --limit haproxy
```

## Configuration

Edit secrets in `nifi/secrets.yaml.example` before deploying. Update Keycloak URL, realm, client ID/secret.

## Deploy with HAProxy

1. Deploy ZooKeeper and NiFi:
```bash
kubectl apply -f zookeeper/
kubectl apply -f nifi/configmap.yaml
kubectl apply -f nifi/statefulset.yaml
```

2. Create HAProxy SSL certs (optional):
```bash
kubectl create secret generic haproxy-certs --from-file=nifi.pem
```

3. Deploy HAProxy:
```bash
kubectl apply -f haproxy/configmap.yaml
kubectl apply -f haproxy/deployment.yaml
```

## Notes

- ZooKeeper uses a StatefulSet with 3 replicas
- NiFi uses a StatefulSet with 3 replicas
- HAProxy acts as reverse proxy/load balancer for NiFi
- Only HTTPS port (8443) is exposed externally via HAProxy
- Data is persisted using PVCs (update storage size as needed)
- NiFi external service changed to ClusterIP (access via HAProxy)
