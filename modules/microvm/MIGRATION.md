# Migration Guide: Converting Direct MicroVM Config to Clan Service Module

This guide explains how to migrate from direct microvm configuration to the new clan service module.

## Current Direct Configuration (britton-desktop)

The current `machines/britton-desktop/configuration.nix` has a direct microvm configuration:

```nix
microvm.vms = {
  test-vm = {
    autostart = true;
    config = { ... };
  };
};

systemd.services."microvm@test-vm".serviceConfig = {
  LoadCredential = [...];
  # Hardening options...
};

clan.core.vars.generators.test-vm-secrets = { ... };
```

## New Clan Service Configuration

To use the clan service module, create an instance in `inventory/services/microvm.nix`:

```nix
{
  instances = {
    "test-vm" = {
      module.name = "microvm";
      module.input = "self";
      roles.server = {
        machines.britton-desktop = {
          vmName = "test-vm";
          autostart = true;

          # Resources
          vcpu = 2;
          mem = 1024;

          # Network
          interfaces = [{
            type = "tap";
            id = "vm-test";
            mac = "02:00:00:01:01:01";
          }];

          vsockCid = 3;

          # Credentials mapping
          credentials = {
            api-key = {
              source = config.clan.core.vars.generators."test-vm-secrets".files."api-key".path;
              destination = "API-KEY";
            };
            db-password = {
              source = config.clan.core.vars.generators."test-vm-secrets".files."db-password".path;
              destination = "DB-PASSWORD";
            };
            jwt-secret = {
              source = config.clan.core.vars.generators."test-vm-secrets".files."jwt-secret".path;
              destination = "JWT-SECRET";
            };
          };

          # Static OEM strings
          staticOemStrings = [
            "io.systemd.credential:ENVIRONMENT=test"
            "io.systemd.credential:CLUSTER=britton-desktop"
          ];

          # Service hardening
          serviceHardening = {
            enable = true;
            protectProc = "invisible";
            procSubset = "pid";
            restrictAddressFamilies = [
              "AF_UNIX" "AF_VSOCK" "AF_INET" "AF_INET6"
            ];
          };

          # Guest configuration
          rootPassword = "test";
          enableSsh = true;

          guestModules = [
            # Your guest-specific configuration here
          ];
        };
      };
    };
  };
}
```

## Migration Steps

### Step 1: Enable the Service Module

1. Ensure `modules/microvm` is registered in `modules/default.nix`
2. Add microvm to `inventory/services/default.nix`

### Step 2: Create Service Instance

Copy the configuration from above into `inventory/services/microvm.nix`, adjusting:

- VM name and resources
- Network configuration
- Credential mappings
- Guest modules

### Step 3: Remove Direct Configuration

From `machines/britton-desktop/configuration.nix`, remove:

1. The `microvm.vms.test-vm` configuration
2. The `systemd.services."microvm@test-vm"` overrides
3. The `clan.core.vars.generators.test-vm-secrets` (if moving to module)

Keep:
- The `inputs.microvm.nixosModules.host` import (module handles this)

### Step 4: Deploy

```bash
# Build to test
build britton-desktop

# Deploy if successful
clan machines update britton-desktop
```

## Key Differences

### Credential Management

**Before:**
```nix
systemd.services."microvm@test-vm".serviceConfig = {
  LoadCredential = [
    "host-api-key:${path}"
  ];
};
```

**After:**
```nix
credentials = {
  api-key = {
    source = "/path/to/secret";
    destination = "API-KEY";  # Becomes HOST-API-KEY
  };
};
```

### Guest Configuration

**Before:**
```nix
config = { pkgs, lib, ... }: {
  # Inline configuration
};
```

**After:**
```nix
guestModules = [
  ({ pkgs, lib, ... }: {
    # Modular configuration
  })
];
```

### Service Hardening

**Before:** Applied directly to systemd service
**After:** Configured via `serviceHardening` option

## Benefits of Migration

1. **Declarative Management**: VMs defined alongside other clan services
2. **Consistency**: Follows clan service patterns
3. **Reusability**: Easy to deploy similar VMs across machines
4. **Secret Integration**: Automatic clan vars integration
5. **Modularity**: Clean separation of host and guest config

## Troubleshooting Migration

### VM Won't Start After Migration

- Check that all paths are absolute
- Verify credential source paths exist
- Ensure network interface names don't conflict

### Credentials Not Working

- Verify the credential prefix (default: "HOST-")
- Check that LoadCredential names match
- Ensure clan vars are generated

### Configuration Errors

- Use `nix flake check` to validate
- Check `journalctl -u microvm@test-vm` for runtime errors
- Verify module is properly registered

## Rollback Plan

If issues arise, you can temporarily:

1. Comment out the microvm service instance
2. Re-add the direct configuration
3. Redeploy

The module and direct configuration can coexist during transition.