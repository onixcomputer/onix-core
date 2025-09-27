# MicroVM LoadCredential Solution
**Timestamp:** 2025-09-26
**Status:** Implemented, Ready to Deploy

## Problem

microvm@test-vm service runs as user `microvm` (group `kvm`) and cannot read secrets owned by `root:root 0400`.

## Solution: systemd LoadCredential

Use systemd's `LoadCredential=` directive which:
- Reads files as root (before dropping privileges)
- Copies them to `$CREDENTIALS_DIRECTORY` owned by service user
- Provides secure, isolated access without changing file permissions

## Implementation

### 1. Service Configuration
**File:** `machines/britton-desktop/configuration.nix:102-106`

```nix
systemd.services."microvm@test-vm".serviceConfig.LoadCredential = [
  "host-api-key:${config.clan.core.vars.generators.test-vm-secrets.files."api-key".path}"
  "host-db-password:${config.clan.core.vars.generators.test-vm-secrets.files."db-password".path}"
  "host-jwt-secret:${config.clan.core.vars.generators.test-vm-secrets.files."jwt-secret".path}"
];
```

### 2. Runner Script Update
**File:** `machines/britton-desktop/configuration.nix:152-229`

Changed from reading `/run/secrets/vars/...` directly to reading from `$CREDENTIALS_DIRECTORY`:

```bash
# Read secrets from systemd credentials directory
if [ -n "${CREDENTIALS_DIRECTORY:-}" ]; then
  if [ -f "$CREDENTIALS_DIRECTORY/host-api-key" ]; then
    API_KEY=$(cat "$CREDENTIALS_DIRECTORY/host-api-key" | tr -d '\n')
    echo "✓ Loaded API_KEY from credentials"
  else
    echo "❌ ERROR: host-api-key not found in credentials directory"
    exit 1
  fi
  # ... same for db-password and jwt-secret
fi
```

## How It Works

```
┌─────────────────────────────────────────────────────────┐
│ systemd (runs as root)                                  │
│   ↓                                                      │
│ LoadCredential reads:                                   │
│   /run/secrets/vars/test-vm-secrets/api-key            │
│   (root:root 0400 - OK, systemd is root)               │
│   ↓                                                      │
│ systemd copies to:                                      │
│   /run/credentials/microvm@test-vm.service/host-api-key │
│   (microvm:root 0400 - owned by service user)          │
│   ↓                                                      │
│ systemd sets CREDENTIALS_DIRECTORY env var              │
│   ↓                                                      │
│ systemd drops to user=microvm, group=kvm                │
│   ↓                                                      │
│ microvm-run script executes as microvm user             │
│   ↓                                                      │
│ Script reads $CREDENTIALS_DIRECTORY/host-api-key        │
│   (SUCCESS - file is owned by microvm)                  │
└─────────────────────────────────────────────────────────┘
```

## Benefits

✅ **No Permission Changes Required**
- Secrets stay root:root 0400
- No group modifications needed
- Follows security best practices

✅ **Systemd Native**
- Uses built-in systemd feature
- Automatic lifecycle management
- Process isolation

✅ **Secure**
- Credentials isolated per-service
- Copied to memory-backed /run
- Cleaned up automatically on service stop

✅ **Works for All Services**
- Standard pattern across NixOS
- Used by garage, dyndns, and other clan services
- Well-documented and supported

## Deployment

```bash
# Build configuration
build britton-desktop

# Deploy (will update systemd units and scripts)
clan machines update britton-desktop

# Or local deployment
sudo nixos-rebuild switch --flake .#britton-desktop

# Verify service has LoadCredential
systemctl cat microvm@test-vm | grep LoadCredential

# Check credentials directory at runtime
systemctl status microvm@test-vm
# Look for CREDENTIALS_DIRECTORY in environment
```

## Verification

After deployment:

```bash
# Check service status
systemctl status microvm@test-vm

# View credentials being loaded (from journalctl)
journalctl -u microvm@test-vm -n 50

# Should see:
# ✓ Loaded API_KEY from credentials
# ✓ Loaded DB_PASSWORD from credentials
# ✓ Loaded JWT_SECRET from credentials
```

## Comparison to Alternative Solutions

| Approach | Pros | Cons |
|----------|------|------|
| **LoadCredential** (This solution) | ✅ No permission changes<br>✅ Systemd native<br>✅ Automatic cleanup | None significant |
| Change file group to kvm | ❌ Broader access<br>❌ All kvm users can read | ✅ Simple |
| Use microvm module | ❌ Requires refactoring<br>❌ Module needs fixing | ✅ Declarative pattern |

## Why This Is Better

1. **Security**: Credentials are isolated per-service instance, not shared across all kvm group members
2. **Standard Practice**: This is how clan-core services (garage, dyndns) handle secrets
3. **No Side Effects**: Doesn't change file permissions system-wide
4. **Maintainable**: Uses well-documented systemd features

## References

- systemd.exec(5) - LoadCredential= documentation
- https://systemd.io/CREDENTIALS/
- Clan-core examples:
  - `/home/brittonr/git/clan-core/clanServices/garage/default.nix:20-32`
  - `/home/brittonr/git/clan-core/clanServices/dyndns/default.nix:254-255`

## Future Enhancements

If migrating to the microvm clan service module (`modules/microvm/default.nix`), add LoadCredential support there:

```nix
# In modules/microvm/default.nix perInstance
systemd.services."microvm@${instanceName}".serviceConfig.LoadCredential =
  lib.mapAttrsToList (name: secret:
    "${name}:${if secret.secretPath != null
                then secret.secretPath
                else config.clan.core.vars.generators.${generatorName}.files.${name}.path}"
  ) runtimeSecrets;
```

This would make LoadCredential automatic for all microvm instances.