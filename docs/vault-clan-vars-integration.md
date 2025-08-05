# Vault Clan Vars Integration

This document explains how Vault keys are managed with clan vars in our setup.

## Overview

Vault must generate its own cryptographic keys for security reasons. Our integration allows these Vault-generated keys to be stored in clan vars for management.

## Key Generators

We have two clan vars generators for Vault:

1. **vault-init**: Creates placeholder values for initial setup
2. **vault-keys**: Retrieves Vault-generated keys from the local machine

## Workflow

### 1. Initial Setup

When setting up Vault for the first time:

```bash
# Deploy Vault with auto-initialization enabled
clan machines update <machine>
```

The auto-init service will:
- Initialize Vault automatically
- Generate cryptographic keys
- Save keys to `/var/lib/vault/init-keys/`
- Auto-unseal Vault using the generated keys

### 2. Retrieving Keys

After Vault initialization, retrieve the keys for clan vars:

```bash
# Option 1: SSH to the machine and run locally
ssh root@<machine>
cd /path/to/clan/repo
clan vars generate <machine> --generator vault-keys --regenerate

# Option 2: Use the retrieve script (from your local machine)
./scripts/retrieve-vault-keys.sh <machine>
```

### 3. Verifying Keys

Check that keys are properly stored:

```bash
clan vars get <machine> vault-keys
```

### 4. Auto-Unseal on Restart

When the machine restarts, the vault-auto-init service will:
1. Check if Vault is initialized
2. If sealed, look for unseal keys in:
   - `/var/lib/vault/init-keys/unseal_keys` (local file)
   - Clan vars (fallback)
3. Automatically unseal Vault

## Manual Key Retrieval

If you need to manually retrieve keys from a machine:

```bash
# Get root token
ssh root@<machine> cat /var/lib/vault/init-keys/root_token

# Get unseal keys  
ssh root@<machine> cat /var/lib/vault/init-keys/unseal_keys
```

## Security Notes

- Vault-generated keys are stored encrypted in clan vars using SOPS
- The vault-init generator creates only placeholder values
- Real keys must be retrieved after Vault initialization
- For production, consider using HSM-based auto-unseal instead of Shamir keys

## Troubleshooting

### Keys not found in clan vars

If the vault-keys generator shows placeholder values:
1. Ensure Vault is initialized on the target machine
2. Check that keys exist in `/var/lib/vault/init-keys/`
3. Run the generator on the machine where Vault is installed

### Auto-unseal not working

1. Check vault-auto-init service logs: `journalctl -u vault-auto-init`
2. Verify keys exist in expected locations
3. Ensure Vault service is running: `systemctl status vault`