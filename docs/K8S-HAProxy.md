# HAProxy with Provided Certificate

## Using Provided Certificate

Place your certificate file (PEM format with cert+key combined) in the appropriate location:

### Ansible Deployment
1. Copy your `nifi.pem` to `files/nifi.pem`
2. Set `haproxy_ssl_termination: true` in `group_vars/haproxy.yml`
3. Set `haproxy_provided_cert: "nifi.pem"` (default)
4. Deploy: `ansible-playbook -i inventory/hosts.ini site.yml --limit haproxy`

### Kubernetes Deployment
1. Create the secret with your provided certificate:
```bash
kubectl create secret generic haproxy-certs --from-file=nifi.pem=path/to/nifi.pem
```

2. Deploy HAProxy:
```bash
kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
```

### Podman Script (for K8s)
1. Place your `nifi.pem` at `/etc/haproxy/certs/nifi.pem`
2. Run:
```bash
./podman-deploy.sh <k8s-nifi-service-ip>
```

## Certificate Format

The PEM file should contain:
```
-----BEGIN CERTIFICATE-----
...
-----END CERTIFICATE-----
-----BEGIN PRIVATE KEY-----
...
-----END PRIVATE KEY-----
```

Or use the combined format:
```bash
cat your-cert.crt your-key.key > nifi.pem
```

## Notes

- HAProxy will terminate SSL when using provided certificate
- Backend communication to NiFi remains over HTTPS (pass-through mode not needed since HAProxy decrypts)
- Stats page remains on HTTP (8404) for monitoring
