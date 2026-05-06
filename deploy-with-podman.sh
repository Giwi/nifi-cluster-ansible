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

# Pull the Ansible image
echo "Pulling Ansible container image..."
podman pull "$ANSIBLE_IMAGE"

# Mount project directory and SSH keys into the container, then run playbook
echo "Starting deployment with containerized Ansible..."
podman run --rm \
    -v "$(pwd):/workspace:z" \
    -v ~/.ssh:/root/.ssh:ro,z \
    -w /workspace \
    --network=host \
    "$ANSIBLE_IMAGE" \
    ansible-playbook -i inventory/hosts.ini --ask-vault-pass "$@" site.yml
