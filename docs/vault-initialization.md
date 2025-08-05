# Vault Production Initialization Guide

## Overview
This guide covers initializing Vault in production mode with file-based storage on britton-fw.

## Prerequisites
- Vault service deployed in production mode
- Access to britton-fw via SSH
- Secure location to store unseal keys and root token

## Deployment

1. Deploy the production configuration:
```bash
clan machines update britton-fw
```

2. The Vault service will start but remain sealed.

## Initialization Process

### 1. Check Vault Status
```bash
ssh britton-fw
export VAULT_ADDR='http://127.0.0.1:8200'
vault status
```

You should see:
- `Initialized: false`
- `Sealed: true`

### 2. Initialize Vault
```bash
vault operator init \
  -key-shares=5 \
  -key-threshold=3 \
  -format=json > vault-init.json
```

This will:
- Generate 5 unseal keys (you need 3 to unseal)
- Generate the initial root token
- Save output to `vault-init.json`

### 3. Store Credentials Securely

**CRITICAL**: Store these credentials in multiple secure locations:

1. **Unseal Keys**: Distribute to different trusted individuals
   - Never store all keys together
   - Consider using a password manager
   - Print physical copies for disaster recovery

2. **Root Token**: Store extremely securely
   - Use only for initial setup
   - Create admin policies and tokens with limited scope
   - Consider revoking after setup

### 4. Unseal Vault
```bash
# Repeat 3 times with different keys
vault operator unseal
# Enter unseal key when prompted
```

### 5. Login with Root Token
```bash
vault login
# Enter root token when prompted
```

### 6. Verify Setup
```bash
vault status
```

Should show:
- `Initialized: true`
- `Sealed: false`

## Post-Initialization Setup

### 1. Enable Audit Logging
```bash
vault audit enable file file_path=/var/log/vault/audit.log
```

### 2. Create Admin Policy
```bash
cat > admin-policy.hcl <<EOF
# Admin policy
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

vault policy write admin admin-policy.hcl
```

### 3. Create Admin Token
```bash
vault token create \
  -policy=admin \
  -display-name="Admin Token" \
  -ttl=8h
```

### 4. Enable Authentication Methods
```bash
# Enable userpass auth
vault auth enable userpass

# Create admin user
vault write auth/userpass/users/admin \
  password="secure-password" \
  policies="admin"
```

### 5. Enable Secrets Engines
```bash
# KV v2 secrets engine (already enabled at secret/)
vault secrets enable -path=kv kv-v2

# Database secrets engine (optional)
vault secrets enable database
```

## Access Vault

### Web UI
- URL: https://vault1.blr.dev/
- Login with token or username/password

### CLI
```bash
export VAULT_ADDR='https://vault1.blr.dev'
vault login -method=userpass username=admin
```

## Auto-Unseal Options

For production, consider implementing auto-unseal:

1. **AWS KMS** - For AWS environments
2. **Azure Key Vault** - For Azure environments
3. **Transit Secret Engine** - Using another Vault instance

## Backup Strategy

1. **File Storage Backup**:
```bash
# Stop Vault
sudo systemctl stop vault

# Backup storage
sudo tar -czf vault-backup-$(date +%Y%m%d).tar.gz /var/lib/vault

# Start Vault
sudo systemctl start vault
```

2. **Snapshot (Enterprise)**:
```bash
vault operator raft snapshot save backup.snap
```

## Security Checklist

- [ ] Root token stored securely and not used for daily operations
- [ ] Unseal keys distributed to multiple people
- [ ] Audit logging enabled
- [ ] Admin users created with appropriate policies
- [ ] Regular backups configured
- [ ] Monitoring and alerting set up
- [ ] TLS/HTTPS enabled via reverse proxy
- [ ] Firewall rules restrict direct access

## Troubleshooting

### Vault Won't Start
```bash
sudo journalctl -u vault -f
```

### Permission Issues
```bash
sudo chown -R vault:vault /var/lib/vault
sudo chmod 700 /var/lib/vault
```

### Lost Unseal Keys
- If you lose more than 2 keys (with threshold=3), Vault data is unrecoverable
- Restore from backup and re-initialize

## Next Steps

1. Configure regular backups
2. Set up monitoring (Prometheus metrics already exposed)
3. Implement auto-unseal for better availability
4. Create application-specific policies and tokens
5. Enable additional auth methods (LDAP, OIDC, etc.)