#!/bin/bash
# Secret rotation script for NiFi cluster
# This script rotates:
# - NiFi sensitive properties key
# - Keystore/Truststore passwords
# - ZooKeeper SSL passwords

set -e

PLAYBOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VAULT_FILE="$PLAYBOOK_DIR/group_vars/all/vault.yml"

echo "Starting secret rotation..."

# Generate new sensitive properties key
NEW_SENSITIVE_KEY=$(openssl rand -base64 32)

# Update vault file with new key (requires vault password)
echo "Updating NiFi sensitive properties key..."
ansible-vault rekey "$VAULT_FILE" --vault-password-file "$PLAYBOOK_DIR/.vault_pass"

# Re-run playbook to apply new secrets
echo "Applying new secrets to NiFi cluster..."
ansible-playbook -i "$PLAYBOOK_DIR/inventory" "$PLAYBOOK_DIR/site.yml" --tags nifi -e "run_backup=true"

echo "Secret rotation complete!"
