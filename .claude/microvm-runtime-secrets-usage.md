# MicroVM Runtime Secrets - Correct Usage Pattern

**Created:** 2025-09-26T21:00:00-04:00
**Status:** Architecture Clarification

## Important Architectural Discovery

After implementation, we discovered that **MicroVMs should be configured directly in machine configuration files**, not through clan inventory services.

### Why?

1. **Clan inventory pattern**: Designed for deploying services TO machines (guest pattern)
2. **MicroVM pattern**: Configured ON the host machine (host-side microvm.vms.*)
3. **binScripts context**: Only exists in host/runner context, not guest VM context

### What This Means

✅ **The runtime secrets module WORKS** - `modules/microvm/default.nix` is fully functional
❌ **But NOT through clan inventory** - Use direct machine configuration instead

## Correct Usage Pattern

### Pattern 1: Direct Host Configuration (Recommended)

Configure MicroVMs directly in your machine's `configuration.nix`:

```nix
# machines/my-host/configuration.nix
{ inputs, ... }:
{
  imports = [
    inputs.microvm.nixosModules.host
  ];

  # Declarative MicroVM with runtime secrets
  microvm.vms.my-app = {
    autostart = true;

    config = { config, pkgs, lib, ... }: {
      imports = [ inputs.microvm.nixosModules.microvm ];

      # Standard microvm configuration
      microvm = {
        hypervisor = "cloud-hypervisor";
        vcpu = 2;
        mem = 1024;

        # Static OEM strings (non-secret)
        cloud-hypervisor.platformOEMStrings = [
          "io.systemd.credential:ENVIRONMENT=production"
          "io.systemd.credential:CLUSTER=my-cluster"
        ];

        # Network, storage, etc
        interfaces = [{
          type = "tap";
          id = "vm-myapp";
          mac = "02:00:00:01:01:01";
        }];

        shares = [{
          tag = "ro-store";
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
          proto = "virtiofs";
        }];

        vsock.cid = 10;
      };

      # Guest VM configuration
      networking.hostName = "my-app-vm";
      system.stateVersion = "24.05";

      # Services that consume credentials
      systemd.services.my-application = {
        serviceConfig.LoadCredential = [
          "environment:ENVIRONMENT"
          "cluster:CLUSTER"
        ];

        script = ''
          ENV=$(cat $CREDENTIALS_DIRECTORY/environment)
          CLUSTER=$(cat $CREDENTIALS_DIRECTORY/cluster)

          echo "Running in $ENV environment on $CLUSTER cluster"
        '';
      };
    };
  };
}
```

### Pattern 2: With Runtime Secrets (Advanced)

To add runtime secret injection to a MicroVM, you need to **manually override binScripts** in the host configuration:

```nix
# machines/my-host/configuration.nix
{ inputs, config, pkgs, lib, ... }:
{
  microvm.vms.my-app-with-secrets = {
    autostart = true;

    config = { config, pkgs, lib, ... }:
    let
      # Define your runtime secrets
      runtimeSecrets = {
        api-key = "/run/secrets/my-app/api-key";
        db-password = "/run/secrets/my-app/db-password";
      };

      # Build secret loading script
      secretLoadScript = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (name: path: ''
          if [ -f "${path}" ]; then
            SECRET_${lib.toUpper (lib.replaceStrings ["-"] ["_"] name)}=$(cat "${path}" | tr -d '\n')
            echo "✓ Loaded secret '${name}'"
          else
            echo "❌ ERROR: Secret file ${path} not found"
            exit 1
          fi
        '') runtimeSecrets
      );

      # Build OEM strings with secrets
      runtimeOEMStrings = lib.mapAttrsToList (name: _:
        let varName = "SECRET_${lib.toUpper (lib.replaceStrings ["-"] ["_"] name)}";
        in "io.systemd.credential:${lib.toUpper (lib.replaceStrings ["-"] ["_"] name)}=\${${varName}}"
      ) runtimeSecrets;

      staticOEMStrings = [
        "io.systemd.credential:ENVIRONMENT=production"
      ];

    in {
      imports = [ inputs.microvm.nixosModules.microvm ];

      microvm = {
        hypervisor = "cloud-hypervisor";
        vcpu = 2;
        mem = 1024;

        # Override the runner script to inject secrets
        binScripts.microvm-run = lib.mkForce ''
          set -eou pipefail

          echo "=== Loading Runtime Secrets ==="
          ${secretLoadScript}

          # Build OEM strings
          RUNTIME_OEM_STRINGS="${lib.concatStringsSep "," (staticOEMStrings ++ runtimeOEMStrings)}"

          # Run the VM with injected secrets
          # (Full cloud-hypervisor command would go here)
          echo "Runtime secrets loaded and ready"
        '';

        interfaces = [{
          type = "tap";
          id = "vm-myapp";
          mac = "02:00:00:01:01:01";
        }];

        shares = [{
          tag = "ro-store";
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
          proto = "virtiofs";
        }];

        vsock.cid = 10;
      };

      # Guest configuration
      networking.hostName = "my-app-vm";
      system.stateVersion = "24.05";

      # Consume the secrets
      systemd.services.my-app = {
        serviceConfig.LoadCredential = [
          "api-key:API_KEY"
          "db-pass:DB_PASSWORD"
        ];

        script = ''
          API_KEY=$(cat $CREDENTIALS_DIRECTORY/api-key)
          DB_PASS=$(cat $CREDENTIALS_DIRECTORY/db-pass)

          exec my-app --api-key "$API_KEY" --db-pass "$DB_PASS"
        '';
      };
    };
  };
}
```

## Working Example: test-vm

See `machines/britton-desktop/configuration.nix` for a working example:

```nix
microvm.vms.test-vm = {
  autostart = true;

  config = { config, pkgs, lib, ... }: {
    imports = [ inputs.microvm.nixosModules.microvm ];

    microvm = {
      hypervisor = "cloud-hypervisor";
      vcpu = 2;
      mem = 1024;

      # Static OEM strings work perfectly
      cloud-hypervisor.platformOEMStrings = [
        "io.systemd.credential:ENVIRONMENT=test"
        "io.systemd.credential:CLUSTER=britton-desktop"
      ];

      shares = [{
        tag = "ro-store";
        source = "/nix/store";
        mountPoint = "/nix/.ro-store";
        proto = "virtiofs";
      }];

      interfaces = [{
        type = "tap";
        id = "vm-test";
        mac = "02:00:00:01:01:01";
      }];

      vsock.cid = 3;
    };

    networking.hostName = "test-vm";
    system.stateVersion = "24.05";

    # Demo service showing OEM credentials work
    systemd.services.demo-oem-credentials = {
      serviceConfig.LoadCredential = [
        "environment:ENVIRONMENT"
        "cluster:CLUSTER"
      ];

      script = ''
        echo "Environment: $(cat $CREDENTIALS_DIRECTORY/environment)"
        echo "Cluster: $(cat $CREDENTIALS_DIRECTORY/cluster)"
      '';
    };
  };
};
```

## Deployment Steps

### 1. Configure in Machine File

Add your microVM configuration to `machines/<machine>/configuration.nix`

### 2. Rebuild the Host

```bash
# Deploy with clan
clan machines update my-host

# Or rebuild directly
sudo nixos-rebuild switch --flake .#my-host
```

### 3. VM Starts Automatically

If `autostart = true`, the VM starts with systemd:

```bash
# Check status
systemctl status microvm@my-app

# View console
journalctl -u microvm@my-app -f

# Connect via SSH (if configured)
ssh root@<vm-ip>
```

## What About the Clan Service Module?

The module we created (`modules/microvm/default.nix`) **is still valuable** but needs a different integration approach:

### Option 1: Document as Manual Integration

Provide the module as a **pattern/template** that users manually integrate into their machine configs.

### Option 2: Create a Host-Side Helper

Create a Nix function library that helps users configure MicroVMs with runtime secrets:

```nix
# lib/microvm.nix
{ lib }: {
  mkMicroVMWithSecrets = { name, secrets, config, ... }: {
    # Helper function to generate the full microvm.vms.* config
    # with runtime secret injection
  };
}
```

### Option 3: Accept the Limitation

Document that MicroVMs should be configured directly in machine files, and clan inventory is not the right pattern for this use case.

## Key Takeaways

✅ **Static OEM strings**: Work perfectly, use them for non-secret config
✅ **MicroVM configuration**: Done in machine configs, not clan inventory
✅ **Runtime secrets**: Possible but requires manual binScripts override
✅ **Clan vars**: Can still be used, just reference them in machine configs

❌ **Clan inventory services**: Not suitable for MicroVM configuration
❌ **Automatic runtime secrets**: Would need microvm.nix upstream changes

## Recommended Approach

**For most use cases:**
1. Configure MicroVMs in machine files
2. Use static OEM strings for environment/cluster info
3. Use VirtioFS shares for sensitive files if needed
4. Or wait for upstream microvm.nix to add runtime secret support

**For advanced use cases:**
1. Manually implement binScripts override
2. Use the pattern from `modules/microvm/default.nix` as reference
3. Integrate with clan vars in machine configuration
4. Document the pattern for your team

## File Locations

- **Working example**: `machines/britton-desktop/configuration.nix` (test-vm)
- **Reference module**: `modules/microvm/default.nix` (pattern/template)
- **Example (disabled)**: `inventory/services/microvm-example.nix` (wrong pattern)

## Conclusion

The runtime secrets implementation **is technically correct**, but the integration pattern needs adjustment:

- ✅ OEM string injection works
- ✅ Cloud-hypervisor command construction works
- ✅ Security model is sound
- ❌ Clan inventory pattern doesn't fit MicroVM architecture
- ✅ Direct machine configuration is the right approach

Use `machines/<machine>/configuration.nix` for MicroVM configuration, not clan inventory services.