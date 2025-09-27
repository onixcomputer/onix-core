# MicroVM Secret Access Solutions
**Timestamp:** 2025-09-26
**Problem:** microvm service cannot read clan vars secrets (Permission denied)

## Solution 1: Immediate Fix (Add Group Permissions)

### Changes Required

**File:** `machines/britton-desktop/configuration.nix:73-102`

```nix
# Generate secrets for test-vm on the HOST
clan.core.vars.generators.test-vm-secrets = {
  files = {
    "api-key" = {
      secret = true;
      owner = "root";      # ADD THIS
      group = "kvm";       # ADD THIS - microvm user is in kvm group
      mode = "0440";       # CHANGE FROM 0400 - enable group read
    };
    "db-password" = {
      secret = true;
      owner = "root";      # ADD THIS
      group = "kvm";       # ADD THIS
      mode = "0440";       # CHANGE FROM 0400
    };
    "jwt-secret" = {
      secret = true;
      owner = "root";      # ADD THIS
      group = "kvm";       # ADD THIS
      mode = "0440";       # CHANGE FROM 0400
    };
  };
  # ... rest stays the same
};
```

### Why This Works
- microvm service runs as user `microvm` with group `kvm`
- Setting `group = "kvm"` allows kvm group members to access
- Mode `0440` = read for owner (root) and group (kvm), no world access
- Minimal changes to existing configuration

### Deployment
```bash
# Rebuild configuration
build britton-desktop

# Deploy
clan machines update britton-desktop

# Or local nixos-rebuild
sudo nixos-rebuild switch --flake .#britton-desktop

# Verify permissions
ls -la /run/secrets/vars/test-vm-secrets/

# Should show: -r--r----- root kvm for each secret
```

### Pros & Cons
✅ Minimal code change
✅ Works immediately
✅ No refactoring needed
⚠️  Still using manual runner script
⚠️  Doesn't leverage clan service infrastructure

---

## Solution 2: Migrate to Clan Service Module (Recommended)

### Architecture Overview

**Current:** Manual microvm configuration in machine config
```
machines/britton-desktop/configuration.nix
  ├─ Manual clan.core.vars.generators definition
  ├─ Manual microvm.vms configuration
  └─ Custom microvm-run script with hardcoded logic
```

**Proposed:** Use clan service module pattern
```
inventory/services/test-vm.nix (NEW)
  ├─ Uses modules/microvm/default.nix
  ├─ Declares runtimeSecrets
  └─ Module handles everything automatically

modules/microvm/default.nix
  ├─ Auto-creates clan vars generator
  ├─ Auto-sets correct permissions (NEEDS FIX)
  ├─ Generates runtime injection script
  └─ Passes secrets via OEM strings
```

### Step 1: Fix Module Permission Handling

**File:** `modules/microvm/default.nix:374-379`

**Current:**
```nix
files = lib.mapAttrs (_name: _secret: {
  secret = true;
  deploy = true;
  mode = "0400";
}) secretsWithGenerators;
```

**Fixed:**
```nix
files = lib.mapAttrs (_name: _secret: {
  secret = true;
  deploy = true;
  owner = "root";
  group = "kvm";  # microvm service group
  mode = "0440";  # group-readable
}) secretsWithGenerators;
```

### Step 2: Create Inventory Service Configuration

**File:** `inventory/services/test-vm.nix` (NEW)

```nix
{ }:
{
  instances = {
    "test-vm" = {
      module.name = "microvm";
      module.input = "self";

      roles.guest = {
        machines.britton-desktop = {
          config = {
            # Hypervisor configuration
            hypervisor = "cloud-hypervisor";
            vcpu = 2;
            mem = 1024;

            # Runtime secrets - automatically managed!
            runtimeSecrets = {
              api-key = {
                oemCredentialName = "API_KEY";
                generateSecret = true;
              };
              db-password = {
                oemCredentialName = "DB_PASSWORD";
                generateSecret = true;
              };
              jwt-secret = {
                oemCredentialName = "JWT_SECRET";
                generateSecret = true;
              };
            };

            # Static configuration via OEM strings
            staticOEMStrings = [
              "io.systemd.credential:ENVIRONMENT=test"
              "io.systemd.credential:CLUSTER=britton-desktop"
            ];

            # Network configuration
            interfaces = [{
              type = "tap";
              id = "vm-test";
              mac = "02:00:00:01:01:01";
            }];

            # Nix store sharing
            shares = [{
              tag = "ro-store";
              source = "/nix/store";
              mountPoint = "/nix/.ro-store";
              proto = "virtiofs";
            }];

            # Enable vsock for systemd notify
            vsock.cid = 3;
          };
        };
      };
    };
  };
}
```

### Step 3: Register Service in Inventory

**File:** `inventory/services/default.nix`

Add:
```nix
imports = [
  # ... existing imports ...
  ./test-vm.nix
];
```

### Step 4: Create Guest Configuration Module

**File:** `machines/test-vm/configuration.nix` (NEW)

```nix
{ pkgs, lib, ... }:
{
  networking.hostName = "test-vm";
  system.stateVersion = "24.05";

  # Network configuration
  networking.interfaces.eth0.useDHCP = lib.mkDefault true;
  networking.firewall.allowedTCPPorts = [ 22 ];

  # SSH access
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "yes";
      PasswordAuthentication = true;
    };
  };

  # Test password (for testing only!)
  users.users.root.initialPassword = "test";

  # Auto-login
  services.getty.autologinUser = "root";

  # Demo service showing OEM credentials
  systemd.services.demo-oem-credentials = {
    description = "Demo OEM credentials from runtime secrets";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StandardOutput = "journal+console";
      StandardError = "journal+console";
      LoadCredential = [
        "environment:ENVIRONMENT"
        "cluster:CLUSTER"
        "api-key:API_KEY"
        "db-password:DB_PASSWORD"
        "jwt-secret:JWT_SECRET"
      ];
    };

    script = ''
      echo "╔═══════════════════════════════════════════════════════════╗"
      echo "║  OEM String Credentials Loaded (test-vm)                ║"
      echo "╚═══════════════════════════════════════════════════════════╝"

      # Show available credentials
      ${pkgs.systemd}/bin/systemd-creds --system list | \
        grep -E "API_KEY|DB_PASSWORD|JWT_SECRET|ENVIRONMENT|CLUSTER" || \
        echo "  (no credentials found)"

      # Verify secret sizes
      echo ""
      echo "Static Config:"
      echo "  ENVIRONMENT = $(cat $CREDENTIALS_DIRECTORY/environment)"
      echo "  CLUSTER     = $(cat $CREDENTIALS_DIRECTORY/cluster)"
      echo ""
      echo "Runtime Secrets (length):"
      echo "  API_KEY     = $(wc -c < $CREDENTIALS_DIRECTORY/api-key) bytes"
      echo "  DB_PASSWORD = $(wc -c < $CREDENTIALS_DIRECTORY/db-password) bytes"
      echo "  JWT_SECRET  = $(wc -c < $CREDENTIALS_DIRECTORY/jwt-secret) bytes"

      if [ $(wc -c < $CREDENTIALS_DIRECTORY/api-key) -gt 10 ]; then
        echo ""
        echo "✅ Runtime secrets successfully injected via OEM strings!"
      fi
    '';
  };

  # Minimal packages
  environment.systemPackages = with pkgs; [
    vim
    htop
  ];
}
```

### Step 5: Update Machine Configuration

**File:** `machines/britton-desktop/configuration.nix`

Remove entire test-vm section (lines 72-314), add:

```nix
{
  imports = [
    inputs.grub2-themes.nixosModules.default
    inputs.microvm.nixosModules.host
  ];

  # Rest of configuration stays the same...
  # The test-vm is now configured via inventory/services/test-vm.nix
}
```

### Step 6: Register Machine in Inventory

**File:** `inventory/core/machines.nix`

Add test-vm entry:
```nix
test-vm = {
  nixpkgs.system = "x86_64-linux";
  tags = [ "all" ];
  # No deployment - it's a VM hosted on britton-desktop
};
```

### Deployment Process

```bash
# 1. Generate secrets for the microvm
clan vars generate --machine britton-desktop

# 2. Build to verify
build britton-desktop

# 3. Deploy host
clan machines update britton-desktop

# 4. Check VM status
systemctl status microvm@test-vm

# 5. View logs
journalctl -u microvm@test-vm -f

# 6. SSH into guest (once running)
ssh root@<test-vm-ip>

# 7. Verify credentials in guest
systemd-creds --system list
```

### Benefits

✅ **Automatic Secret Management**
- Module generates clan vars automatically
- Correct permissions set by module
- No manual secret path wiring

✅ **Declarative Configuration**
- All config in inventory/services
- Follows clan patterns
- Easier to add more VMs

✅ **Runtime Secret Injection**
- Secrets never on disk in guest
- OEM strings pass directly to systemd
- Ephemeral credentials

✅ **Maintainability**
- No custom runner scripts
- Module handles complexity
- Updates automatically with module

✅ **Security**
- Secrets protected at rest (SOPS)
- Group-isolated on host
- Memory-only in guest

### Module Capabilities

The microvm module supports:
- ✅ Runtime secret injection via OEM strings
- ✅ Automatic clan vars generator creation
- ✅ Static OEM strings for config
- ✅ All standard microvm options (freeformType)
- ✅ Multi-instance support

---

## Recommendation

### For Immediate Fix
Use **Solution 1** - just add group permissions to your current config

### For Production / Long-term
Implement **Solution 2** - migrate to the clan service module

The module pattern provides:
- Better separation of concerns
- Reusable across multiple VMs
- Automatic secret lifecycle management
- Integration with clan inventory system
- Follows established patterns in your codebase

## Security Note

Both solutions use OEM strings to pass secrets to the guest. This is appropriate for your use case because:

✅ Host is trusted (you control the physical machine)
✅ Hypervisor is trusted (runs on the same machine)
✅ Secrets are ephemeral in guest (memory-only)
✅ Protected at rest on host (SOPS encryption)

If you needed confidential computing (untrusted hypervisor), you would need:
- AMD SEV-SNP or Intel TDX
- Encrypted credentials (SetCredentialEncrypted)
- Guest attestation

But for your infrastructure, OEM strings provide good security with excellent usability.