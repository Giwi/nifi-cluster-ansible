#!/bin/bash
set -e

# Script to deploy HAProxy as a Podman container to load balance Kubernetes-deployed NiFi
# Usage: ./podman-deploy.sh [kubernetes-nifi-service-ip]

K8S_NIFI_IP="${1:-$(kubectl get svc nifi-external -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo 'CHANGE_ME')}"

if [ "$K8S_NIFI_IP" == "CHANGE_ME" ]; then
    echo "Warning: Could not get Kubernetes NiFi service IP. Please provide it as argument."
    echo "Usage: $0 <kubernetes-nifi-service-ip>"
    exit 1
fi

echo "Deploying HAProxy with Podman to load balance to Kubernetes NiFi at: $K8S_NIFI_IP"

# Create HAProxy config
mkdir -p /etc/haproxy
cat > /etc/haproxy/haproxy.cfg <<EOF
global
    log stdout format raw local0
    maxconn 4096
    daemon

defaults
    log     global
    mode    tcp
    option  tcplog
    option  dontlognull
    timeout connect 5000ms
    timeout client  50000ms
    timeout server  50000ms

frontend nifi_frontend
    bind *:8443
    mode tcp
    default_backend nifi_backend

backend nifi_backend
    mode tcp
    option ssl-hello-chk
    balance roundrobin
    server nifi-k8s $K8S_NIFI_IP:8443 check

listen stats
    bind *:8404
    mode http
    stats enable
    stats uri /stats
    stats refresh 10s
    stats admin if TRUE
EOF

# Stop existing container
podman stop haproxy 2>/dev/null || true
podman rm haproxy 2>/dev/null || true

# Deploy HAProxy container
podman run -d \
    --name haproxy \
    -p 8443:8443 \
    -p 8404:8404 \
    -v /etc/haproxy/haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro \
    --restart always \
    haproxy:2.8

echo "HAProxy deployed successfully!"
echo "Access NiFi at: https://localhost:8443/nifi"
echo "HAProxy stats at: http://localhost:8404/stats"
