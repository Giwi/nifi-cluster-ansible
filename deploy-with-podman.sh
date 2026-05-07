#!/bin/bash
set -e

# Script to deploy NiFi+ZooKeeper cluster using a containerized Ansible (via Podman)
# Usage: ./deploy-with-podman.sh [ansible-playbook options]

# Check if Podman is installed
if ! command -v podman &> /dev/null; then
    echo "Error: Podman is not installed. Please install Podman first."
    exit 1
fi

# Ansible container image (official Ansible image with SSH client)
ANSIBLE_IMAGE="ansible/ansible:2.16"

# Check if vault password file exists
VAULT_PASS_FILE=".vault_pass"
if [ ! -f "$VAULT_PASS_FILE" ]; then; then
    echo "Warning: Vault password file '$VAULT_PASS_FILE' not found."
    echo "Create it with: echo 'your-password' > $VAULT_PASS_FILE"
    echo "Or run with: $0 --vault-password-file=/path/to/passfile"
    exit 1
fi

# Pull the Ansible image
echo "Pulling Ansible container image..."
podman pull "$ANSIBLE_IMAGE"

# Mount project directory and SSH keys into the container, then run playbook
echo "Starting deployment with containerized Ansible..."
podman run --rm \
    -v "$(pwd):/workspace:z" \
    -v ~/.ssh:/root/.ssh:ro,z \
    -v "$(pwd)/$VAULT_PASS_FILE:/vault_pass:ro,z" \
    -w /workspace \
    --network=host \
    "$ANSIBLE_IMAGE" \
    ansible-playbook -i inventory/hosts.ini --vault-password-file /vault_pass "$@" site.yml
