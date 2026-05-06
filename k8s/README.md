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

After deployment, get the external IP:
```bash
kubectl get svc nifi-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Access NiFi at: `https://<external-ip>:8443/nifi`

## Configuration

Edit secrets in `nifi/secrets.yaml.example` before deploying. Update Keycloak URL, realm, client ID/secret.

## Notes

- ZooKeeper uses a StatefulSet with 3 replicas
- NiFi uses a StatefulSet with 3 replicas
- Only HTTPS port (8443) is exposed externally
- Data is persisted using PVCs (update storage size as needed)
