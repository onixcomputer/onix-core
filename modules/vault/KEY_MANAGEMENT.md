# Vault Key Management with Clan

This document explains how Vault key management works with our clan service implementation.

## How It Works

### 1. Key Generation Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Vault Service   │────▶│ Vault Generates  │────▶│ Keys Saved to   │
│ First Start     │     │ Master Key &     │     │ /var/lib/vault/ │
│                 │     │ Unseal Keys      │     │ init-keys/      │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                           │
                                                           ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ Keys in Clan    │◀────│ Clan Vars Pull   │◀────│ Manual: Run     │
│ Secrets (SOPS) │     │ Keys from Remote │     │ clan vars gen   │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

### 2. Why Vault Must Generate the Keys

- **Master Key**: Vault generates a cryptographically secure 256-bit master key
- **Encryption**: This master key encrypts all data in Vault's storage
- **Shamir Splitting**: The master key is split into 5 shares (unseal keys)
- **Threshold**: Any 3 of the 5 keys can reconstruct the master key
- **Security**: We cannot create valid unseal keys without the master key

### 3. Key Storage Locations

1. **During Initialization** (temporary):
   - `/var/lib/vault/init-keys/root_token`
   - `/var/lib/vault/init-keys/unseal_keys`

2. **In Clan Vars** (permanent, encrypted):
   - Stored in SOPS-encrypted files in your git repository
   - Deployed to `/run/secrets.d/*/vars/vault-init/` on machines

## Workflows

### A. Fresh Installation

```bash
# 1. Deploy Vault with auto-init enabled
clan machines update britton-fw

# 2. Vault automatically:
#    - Generates master key
#    - Splits into 5 unseal keys
#    - Saves to /var/lib/vault/init-keys/
#    - Auto-unseals itself

# 3. Pull keys into clan vars
clan vars generate britton-fw --generator vault-init --regenerate

# 4. Verify keys were retrieved
clan vars list britton-fw | grep vault-init

# 5. Deploy again to use clan-managed keys
clan machines update britton-fw
```

### B. Existing Vault (Keys Known)

If you have an existing Vault and know the keys:

```bash
# 1. Save keys to the remote machine
./save-vault-keys.sh 'hvs.YourRootToken' '["key1","key2","key3","key4","key5"]'

# 2. Pull into clan vars
clan vars generate britton-fw --generator vault-init --regenerate

# 3. Deploy to enable auto-unseal
clan machines update britton-fw
```

### C. Reset and Re-initialize

**WARNING: This destroys all data in Vault!**

```bash
# 1. Stop and wipe Vault
ssh root@britton-fw 'systemctl stop vault && rm -rf /var/lib/vault/*'

# 2. Start fresh
ssh root@britton-fw 'systemctl start vault'

# 3. The auto-init service will initialize and save new keys
# 4. Follow "Fresh Installation" steps 3-5
```

## Auto-Unseal Behavior

Once keys are properly stored, the vault-auto-init service will:

1. **On Vault start**: Check if sealed
2. **If sealed**: Read keys from `/var/lib/vault/init-keys/` or clan vars
3. **Auto-unseal**: Use first 3 keys to unseal
4. **If unsealed**: Do nothing

## Security Considerations

1. **Root Token**: Should only be used for initial setup
   - Create policies and additional tokens
   - Revoke or secure the root token

2. **Unseal Keys**: 
   - Store securely (clan vars uses SOPS encryption)
   - Distribute to multiple trusted parties
   - Never store all keys in one location in production

3. **Backup Strategy**:
   - Keep offline copies of unseal keys
   - Test recovery procedures
   - Consider using auto-unseal (AWS KMS, etc.) for production

## Troubleshooting

### Keys Not Found
```bash
# Check if keys exist on remote
ssh root@britton-fw 'ls -la /var/lib/vault/init-keys/'

# Check clan vars
clan vars list britton-fw | grep vault-init
```

### Manual Unseal
```bash
# If auto-unseal fails
ssh root@britton-fw
export VAULT_ADDR=http://127.0.0.1:8200
vault operator unseal <key1>
vault operator unseal <key2>
vault operator unseal <key3>
```

### View Logs
```bash
# Check initialization logs
ssh root@britton-fw 'journalctl -u vault-auto-init -n 50'

# Check Vault logs
ssh root@britton-fw 'journalctl -u vault -n 50'
```