# Encrypted Terraform State with Clan Vars

This guide explains how to enable automatic encryption of Terraform state files using Clan vars, treating them like any other secret.

## Why Encrypt State?

Terraform state files contain:
- Resource IDs and metadata
- Sometimes sensitive outputs (database passwords, API keys)
- Infrastructure topology information
- All attribute values from your resources

By encrypting state with Clan vars, we get:
- **Same security model** as other secrets (age key encryption)
- **Machine-restricted access** (only authorized machines can decrypt)
- **Git-safe storage** (encrypted state can be committed)
- **Audit trail** through Clan vars system

## Setup

### 1. Create a Clan Generator for State

```bash
# Create a generator specifically for terraform state
clan vars generate terraform-state-infrastructure

# Set the initial state (empty or from existing)
echo '{}' > empty-state.json
clan vars set terraform-state-infrastructure tfstate --from-file=empty-state.json
rm empty-state.json
```

### 2. Enable State Encryption in Configuration

Edit `inventory/services/terranix-devshell.nix`:

```nix
{
  instances = {
    "infrastructure" = {
      roles.deployer = {
        machines."britton-fw" = { };

        settings = {
          # ... existing config ...

          # Enable state encryption
          stateEncryption = {
            enable = true;
            generator = "terraform-state-infrastructure";
          };
        };
      };
    };
  };
}
```

### 3. Deploy the Updated Configuration

```bash
clan machines update britton-fw
```

## How It Works

### Automatic Workflow

When state encryption is enabled, `tfx` commands automatically:

1. **Before operations** (plan/apply/destroy):
   - Check for encrypted state in `/run/secrets/vars/terraform-state-infrastructure/tfstate`
   - Decrypt to `.terraform/terraform.tfstate` if found
   - Use existing local state if no encrypted version exists

2. **After successful operations**:
   - Display instruction to save state back to Clan vars
   - Future: Automatic save-back when Clan supports it

### Manual State Management

#### Save State to Clan Vars
```bash
# After terraform operations, encrypt the state
clan vars set terraform-state-infrastructure tfstate \
  --from-file=.terraform/terraform.tfstate
```

#### Retrieve State from Clan Vars
```bash
# Manually decrypt state if needed
cat /run/secrets/vars/terraform-state-infrastructure/tfstate > .terraform/terraform.tfstate
```

#### Migrate Existing State to Encrypted
```bash
# If you have existing unencrypted state
cd /home/brittonr/git/onix-core/infrastructure

# Save current state to clan vars
clan vars set terraform-state-infrastructure tfstate \
  --from-file=.terraform/terraform.tfstate

# Remove local unencrypted state
rm .terraform/terraform.tfstate
rm .terraform/terraform.tfstate.backup

# Test that encrypted state works
tfx plan  # Should load from encrypted state
```

## Security Model

### Access Requirements

To use encrypted state, you need:
1. **Machine assignment**: Be on a machine with the terranix-devshell
2. **Age key**: Have the decryption key for the state generator
3. **Read permissions**: Access to `/run/secrets/vars/`

### State Access Matrix

| Scenario | Can Read State | Can Modify State |
|----------|---------------|------------------|
| Authorized machine + age key | ✅ | ✅ |
| Authorized machine, no key | ❌ | ❌ |
| Wrong machine | ❌ | ❌ |
| Repo access only | ❌ (encrypted) | ❌ |

### Multi-Environment Setup

For separate state per environment:

```nix
# Dev environment
stateEncryption = {
  enable = true;
  generator = "terraform-state-dev";
};

# Production environment
stateEncryption = {
  enable = true;
  generator = "terraform-state-prod";  # Different generator
};
```

## Benefits

1. **Zero-Trust State**: State never exists unencrypted in git
2. **Consistent Security**: Same age-key encryption as all secrets
3. **Machine Isolation**: Different machines can have different state access
4. **Disaster Recovery**: State backed up with same mechanism as other secrets
5. **Compliance**: Meets requirements for encryption-at-rest

## Current Limitations

1. **Manual Save**: Currently requires manual `clan vars set` after changes
2. **No Locking**: Doesn't provide state locking (use Terraform backend for that)
3. **Single Writer**: Best suited for single-operator or serialized access

## Future Improvements

1. **Automatic Save-Back**: When Clan vars supports updating existing vars
2. **State Versioning**: Keep multiple versions of state
3. **Lock File**: Implement locking mechanism via Clan vars
4. **Pull/Push Commands**: `tfx state pull` and `tfx state push` helpers

## Troubleshooting

### "Using unencrypted local state file"
- State exists locally but not in Clan vars
- Run: `clan vars set terraform-state-infrastructure tfstate --from-file=.terraform/terraform.tfstate`

### "Cannot decrypt state"
- Missing age key or wrong machine
- Check: `ls -la /run/secrets/vars/terraform-state-infrastructure/`
- Verify: Machine has correct age key in `/etc/ssh/ssh_host_ed25519_key`

### "State out of sync"
- Local and encrypted state diverged
- Compare: `diff .terraform/terraform.tfstate /run/secrets/vars/terraform-state-infrastructure/tfstate`
- Choose: Keep local or encrypted version

## Example Workflow

```bash
# 1. Initialize infrastructure
tfx init

# 2. Configure resources in config.nix
vim config.nix

# 3. Plan changes (auto-loads encrypted state if exists)
tfx plan

# 4. Apply changes
tfx apply

# 5. Save state back to Clan vars (encrypted)
clan vars set terraform-state-infrastructure tfstate \
  --from-file=.terraform/terraform.tfstate

# 6. Commit encrypted state reference
git add inventory/vars/
git commit -m "Update encrypted terraform state"
```

This approach treats Terraform state as a first-class secret, ensuring it's protected with the same security measures as API keys and other sensitive data.