# Ansible Vault Setup

This project uses Ansible Vault to encrypt sensitive data.

## Initial Setup

1. Create the vault file with passwords:
```bash
ansible-vault create group_vars/all/vault.yml
```

2. Copy the content from `group_vars/all/vault.yml` (if already created unencrypted)

3. Or encrypt an existing file:
```bash
ansible-vault encrypt group_vars/all/vault.yml
```

## Required Vault Variables

The following variables must be defined in the vault:

- `vault_nifi_keystore_password`: NiFi keystore password
- `vault_nifi_truststore_password`: NiFi truststore password
- `vault_nifi_sensitive_props_key`: NiFi sensitive properties key
- `vault_keycloak_client_secret`: Keycloak client secret
- `vault_zookeeper_keystore_password`: ZooKeeper keystore password
- `vault_zookeeper_truststore_password`: ZooKeeper truststore password
- `vault_haproxy_stats_password`: HAProxy stats page password

## Usage

### Running playbook with vault:
```bash
ansible-playbook -i inventory/hosts.ini --ask-vault-pass site.yml
```

### Using vault password file (for automation):
```bash
echo "your-vault-password" > .vault_pass
ansible-playbook -i inventory/hosts.ini --vault-password-file .vault_pass site.yml
```

### Editing vault:
```bash
ansible-vault edit group_vars/all/vault.yml
```

## Note

The vault file `group_vars/all/vault.yml` is already in `.gitignore` and won't be committed.
You need to manually create and encrypt it on each deployment target or share it securely.
