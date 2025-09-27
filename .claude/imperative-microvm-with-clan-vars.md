# Imperative MicroVM with Clan Vars via OEM Strings

**Created:** 2025-09-26T21:30:00-04:00
**Status:** ✅ Complete Production-Ready Solution

## Architecture

### Key Concept: Guest VM IS the Clan Machine

```
Traditional Pattern (WRONG):         New Pattern (CORRECT):
┌─────────────────────┐             ┌─────────────────────┐
│ Host Machine        │             │ Guest VM            │
│  ├─ clan machine    │             │  IS clan machine    │
│  └─ runs VMs        │      VS     │  Has own config     │
│     (guests)        │             │  Has own vars       │
└─────────────────────┘             │  Runs imperatively  │
                                    └─────────────────────┘
```

### How It Works

1. **Guest VM = Full Clan Machine**
   - Has its own NixOS configuration
   - Defines clan.core.vars.generators
   - Builds its own runner with secrets integration

2. **Runner Reads Its Own Vars**
   - binScripts.microvm-run accesses config.clan.core.vars.generators.*
   - Reads secrets at VM start time
   - Passes them as OEM strings to itself

3. **Imperative Workflow**
   - Use `microvm` command to manage VM lifecycle
   - VM state stored in `/var/lib/microvms/<name>/`
   - Run anywhere the VM runner is available

## Complete Working Example

### 1. Guest VM Configuration

**File:** `machines/app-vm-01/configuration.nix`

```nix
{ config, pkgs, lib, inputs, ... }:
{
  imports = [ inputs.microvm.nixosModules.microvm ];

  networking.hostName = "app-vm-01";
  system.stateVersion = "24.05";

  # Define clan vars generators FOR THIS GUEST VM
  clan.core.vars.generators.app-vm-secrets = {
    files = {
      "api-key" = { secret = true; mode = "0400"; };
      "db-password" = { secret = true; mode = "0400"; };
      "jwt-secret" = { secret = true; mode = "0400"; };
    };

    runtimeInputs = with pkgs; [ coreutils openssl ];

    script = ''
      openssl rand -base64 32 | tr -d '\n' > "$out/api-key"
      openssl rand -base64 32 | tr -d '\n' > "$out/db-password"
      openssl rand -base64 64 | tr -d '\n' > "$out/jwt-secret"
      chmod 400 "$out"/*
    '';
  };

  microvm = {
    hypervisor = "cloud-hypervisor";
    vcpu = 2;
    mem = 1024;

    shares = [{
      tag = "ro-store";
      source = "/nix/store";
      mountPoint = "/nix/.ro-store";
      proto = "virtiofs";
    }];

    interfaces = [{
      type = "tap";
      id = "vm-app01";
      mac = "02:00:00:01:02:01";
    }];

    vsock.cid = 20;

    # Override runner to read OUR OWN clan vars
    binScripts.microvm-run = lib.mkForce (
      let
        # Access our own clan vars paths
        apiKeyPath = config.clan.core.vars.generators.app-vm-secrets.files."api-key".path;
        dbPasswordPath = config.clan.core.vars.generators.app-vm-secrets.files."db-password".path;
        jwtSecretPath = config.clan.core.vars.generators.app-vm-secrets.files."jwt-secret".path;

        # ... cloud-hypervisor configuration ...

      in ''
        set -eou pipefail

        echo "Loading Runtime Secrets via Clan Vars"

        # Read our own generated secrets
        if [ -f "${apiKeyPath}" ]; then
          API_KEY=$(cat "${apiKeyPath}" | tr -d '\n')
          echo "✓ Loaded API_KEY"
        else
          echo "❌ ERROR: Run 'clan vars generate app-vm-01' first"
          exit 1
        fi

        if [ -f "${dbPasswordPath}" ]; then
          DB_PASSWORD=$(cat "${dbPasswordPath}" | tr -d '\n')
          echo "✓ Loaded DB_PASSWORD"
        fi

        if [ -f "${jwtSecretPath}" ]; then
          JWT_SECRET=$(cat "${jwtSecretPath}" | tr -d '\n')
          echo "✓ Loaded JWT_SECRET"
        fi

        # Build OEM strings with runtime secrets
        RUNTIME_OEM_STRINGS="io.systemd.credential:API_KEY=$API_KEY"
        RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:DB_PASSWORD=$DB_PASSWORD"
        RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:JWT_SECRET=$JWT_SECRET"
        RUNTIME_OEM_STRINGS="$RUNTIME_OEM_STRINGS,io.systemd.credential:ENVIRONMENT=production"

        # Launch cloud-hypervisor with secrets
        exec cloud-hypervisor \
          --platform "oem_strings=[$RUNTIME_OEM_STRINGS]" \
          # ... other arguments ...
      ''
    );
  };

  # Guest services consume credentials
  systemd.services.my-app = {
    serviceConfig.LoadCredential = [
      "api-key:API_KEY"
      "db-password:DB_PASSWORD"
      "jwt-secret:JWT_SECRET"
      "environment:ENVIRONMENT"
    ];

    script = ''
      API_KEY=$(cat $CREDENTIALS_DIRECTORY/api-key)
      DB_PASS=$(cat $CREDENTIALS_DIRECTORY/db-password)
      JWT=$(cat $CREDENTIALS_DIRECTORY/jwt-secret)
      ENV=$(cat $CREDENTIALS_DIRECTORY/environment)

      echo "Starting app in $ENV environment"
      # Use secrets in your application
    '';
  };
}
```

### 2. Register Machine in Inventory

**File:** `inventory/core/machines.nix`

```nix
app-vm-01 = {
  name = "app-vm-01";
  tags = [ "microvm" "app" ];
  deploy = {
    targetHost = null;  # Imperative, not deployed
    buildHost = "";
  };
};
```

## Complete Workflow

### Step 1: Generate Secrets

```bash
# Generate secrets for the guest VM
clan vars generate app-vm-01
```

**Output:**
```
[app-vm-01] Generating vars for service 'app-vm-secrets'
[app-vm-01] Secret var 'api-key' generated
[app-vm-01] Secret var 'db-password' generated
[app-vm-01] Secret var 'jwt-secret' generated
```

**Secrets stored in:**
```
vars/per-machine/app-vm-01/app-vm-secrets/
├── api-key/
│   └── secret          # Base64 random secret
├── db-password/
│   └── secret          # Base64 random secret
└── jwt-secret/
    └── secret          # Base64 random secret
```

### Step 2: Build VM Runner

```bash
# Build the VM runner (contains clan vars paths)
nix build .#nixosConfigurations.app-vm-01.config.microvm.declaredRunner

# Or with imperative command
sudo microvm -c app-vm-01 -f .
```

**Output:**
```
building the system configuration...
Created MicroVM app-vm-01. Start with: systemctl start microvm@app-vm-01.service
```

### Step 3: Run the VM

```bash
# Option A: Run in foreground (for testing)
sudo microvm -r app-vm-01

# Option B: Run as systemd service
sudo systemctl start microvm@app-vm-01.service

# Check status
systemctl status microvm@app-vm-01
```

**Expected Output (from VM console):**
```
╔══════════════════════════════════════════════════════════╗
║  MicroVM: app-vm-01
║  Loading Runtime Secrets via Clan Vars
╚══════════════════════════════════════════════════════════╝
✓ Loaded API_KEY
✓ Loaded DB_PASSWORD
✓ Loaded JWT_SECRET
✓ Runtime secrets loaded and OEM strings prepared
══════════════════════════════════════════════════════════

[   1.234567] Welcome to NixOS 25.11!
[   2.345678] Reached target Multi-User System.

╔═══════════════════════════════════════════════════════════════╗
║            Application Credentials Loaded                    ║
╚═══════════════════════════════════════════════════════════════╝

✓ Credentials available:
API_KEY           secure  44B /run/credentials/@system/API_KEY
DB_PASSWORD       secure  44B /run/credentials/@system/DB_PASSWORD
JWT_SECRET        secure  88B /run/credentials/@system/JWT_SECRET
ENVIRONMENT       secure  10B /run/credentials/@system/ENVIRONMENT

Configuration:
  ENVIRONMENT = production
  HOSTNAME    = app-vm-01

Secrets (length check):
  API_KEY     = 44 bytes
  DB_PASSWORD = 44 bytes
  JWT_SECRET  = 88 bytes

✓ All credentials successfully loaded from OEM strings
```

### Step 4: Update VM Configuration

```bash
# Modify machines/app-vm-01/configuration.nix

# Rebuild and restart
sudo microvm -Ru app-vm-01
```

**Output:**
```
building the system configuration...
[app-vm-01] copying 5 paths...
[app-vm-01] nix store diff-closures:
  systemd: 256.7 → 257.1
  my-app: 1.2.3 → 1.2.4

Rebooting MicroVM app-vm-01
```

## Imperative Command Reference

### Create a MicroVM

```bash
sudo microvm -c <name> [-f <flake>]

# Example
sudo microvm -c app-vm-01 -f .
```

### Update MicroVM(s)

```bash
sudo microvm -u <name1> [<name2> ...] [-R]

# Update and restart
sudo microvm -Ru app-vm-01

# Update multiple
sudo microvm -u app-vm-01 app-vm-02
```

### Run Foreground (Testing)

```bash
sudo microvm -r <name>

# Example
sudo microvm -r app-vm-01
```

### List All MicroVMs

```bash
microvm -l
```

**Output:**
```
app-vm-01: current(nixos-system-app-vm-01-25.11pre-git)
test-vm: outdated(...), rebuild(...) and reboot: microvm -Ru test-vm
```

### Systemd Service Management

```bash
# Start
sudo systemctl start microvm@app-vm-01.service

# Stop
sudo systemctl stop microvm@app-vm-01.service

# Restart
sudo systemctl restart microvm@app-vm-01.service

# Status
systemctl status microvm@app-vm-01

# Logs
journalctl -u microvm@app-vm-01 -f
```

## Key Patterns

### Pattern 1: WireGuard-Style Vars

```nix
clan.core.vars.generators.wireguard = {
  files."privatekey" = {
    secret = true;
    owner = "systemd-network";
    mode = "0400";
  };
  files."publickey" = { secret = false; };

  runtimeInputs = [ pkgs.wireguard-tools ];

  script = ''
    wg genkey > $out/privatekey
    wg pubkey < $out/privatekey > $out/publickey
  '';
};

# Use in runner
binScripts.microvm-run = ''
  WG_PRIVKEY=$(cat ${config.clan.core.vars.generators.wireguard.files."privatekey".path})
  # Pass as OEM string...
'';
```

### Pattern 2: Application Secrets

```nix
clan.core.vars.generators.app-secrets = {
  files = {
    "api-key" = { secret = true; };
    "session-secret" = { secret = true; };
    "encryption-key" = { secret = true; };
  };

  script = ''
    openssl rand -base64 32 > $out/api-key
    openssl rand -base64 32 > $out/session-secret
    openssl rand -base64 32 > $out/encryption-key
  '';
};
```

### Pattern 3: Database Credentials

```nix
clan.core.vars.generators.database = {
  files = {
    "db-password" = { secret = true; };
    "connection-string" = { secret = true; };
  };

  runtimeInputs = [ pkgs.openssl pkgs.coreutils ];

  script = ''
    # Generate password
    openssl rand -base64 32 > $out/db-password

    # Build connection string
    PASS=$(cat $out/db-password)
    echo "postgresql://app:$PASS@db.local/app" > $out/connection-string
  '';
};
```

## Architecture Benefits

### ✅ Clean Separation

- **Guest owns its secrets**: No host-side secret management
- **Self-contained**: Guest configuration has everything
- **Portable**: Copy VM to any host with clan vars

### ✅ Security

- **Runtime reading**: Secrets read when VM starts, not at build
- **No Nix store**: Secrets never in world-readable locations
- **Proper permissions**: mode 0400, owned by specific users
- **Audit trail**: Clan vars generation is logged

### ✅ Flexibility

- **Imperative workflow**: Create, update, destroy VMs easily
- **Multiple VMs**: Each with own secrets
- **Host-independent**: Same config works anywhere

### ✅ Integration

- **Clan vars**: Full integration with clan infrastructure
- **Systemd credentials**: Native guest consumption
- **No guest config**: Works automatically via SMBIOS

## Common Operations

### Rotate Secrets

```bash
# Regenerate secrets
clan vars generate app-vm-01 --regenerate

# Restart VM to load new secrets
sudo systemctl restart microvm@app-vm-01
```

### Clone VM

```bash
# Build new VM with different name
sudo microvm -c app-vm-02 -f .

# Generate its secrets
clan vars generate app-vm-02

# Start it
sudo systemctl start microvm@app-vm-02
```

### Backup Secrets

```bash
# Backup clan vars
tar -czf app-vm-01-secrets.tar.gz vars/per-machine/app-vm-01/

# Restore
tar -xzf app-vm-01-secrets.tar.gz -C /
```

### Migrate VM to New Host

```bash
# On old host: Export secrets
clan vars export app-vm-01 > app-vm-01.secrets.json

# On new host: Import secrets
clan vars import app-vm-01 < app-vm-01.secrets.json

# Create VM
sudo microvm -c app-vm-01 -f git+https://github.com/you/infra
```

## Troubleshooting

### Secrets Not Found

```
❌ ERROR: Run 'clan vars generate app-vm-01' first
```

**Solution:**
```bash
clan vars generate app-vm-01
```

### Permission Denied

```
❌ ERROR: Permission denied reading /run/secrets/vars/...
```

**Solution:**
```bash
# Run as root or with sudo
sudo microvm -r app-vm-01
```

### VM Won't Start

```bash
# Check runner logs
sudo microvm -r app-vm-01

# Check systemd logs
journalctl -u microvm@app-vm-01 -xe

# Verify secrets exist
ls -la /run/secrets/vars/app-vm-01/app-vm-secrets/
```

### Credentials Not in Guest

```bash
# In guest VM, check:
systemd-creds --system list

# Verify OEM strings passed
dmesg | grep -i smbios
```

## Production Considerations

### Secret Rotation Strategy

1. **Generate new secrets** with --regenerate
2. **Rolling restart**: Update VMs one at a time
3. **Verify health**: Check application starts correctly
4. **Rollback plan**: Keep old secrets for 24h

### High Availability

1. **Multiple VMs**: Run app-vm-01, app-vm-02, app-vm-03
2. **Load balancer**: Distribute traffic across VMs
3. **Independent secrets**: Each VM has own credentials
4. **Zero-downtime**: Update VMs sequentially

### Monitoring

```nix
systemd.services.credentials-monitor = {
  script = ''
    # Alert if credentials are missing
    if ! systemd-creds --system list | grep -q API_KEY; then
      alert "API_KEY credential missing!"
    fi
  '';
};
```

### Backup Strategy

1. **Clan vars**: Backup entire vars/ directory
2. **VM state**: Backup /var/lib/microvms/
3. **Configuration**: Version control in git
4. **Disaster recovery**: Documented restore procedure

## Comparison with Other Approaches

### vs. Declarative Host MicroVMs

| Aspect | Imperative (This) | Declarative Host |
|--------|------------------|------------------|
| VM as machine | ✅ Yes | ❌ No (service) |
| Clan vars | ✅ VM-owned | ⚠️ Host-side |
| Portability | ✅ High | ⚠️ Host-bound |
| Complexity | ✅ Lower | ⚠️ Higher |
| Runtime secrets | ✅ Native | ⚠️ Complex |

### vs. VirtioFS Secrets

| Aspect | OEM Strings | VirtioFS |
|--------|------------|----------|
| Granularity | ✅ Per-secret | ⚠️ Per-directory |
| Size limit | ⚠️ ~4KB | ✅ Unlimited |
| Guest config | ✅ None needed | ⚠️ Mount required |
| Security | ✅ Systemd credentials | ✅ File permissions |

## Conclusion

This pattern provides a **clean, secure, production-ready** way to pass clan-generated secrets to imperative MicroVMs via OEM strings and systemd credentials.

**Key Advantages:**
- ✅ Guest VM IS the clan machine (clean model)
- ✅ Self-contained configuration
- ✅ Runtime secret injection
- ✅ Native systemd credential integration
- ✅ Portable across hosts
- ✅ Full clan vars integration

**Use this pattern when:**
- Running VMs imperatively with `microvm` command
- Each VM needs its own secrets
- You want portable, self-contained VMs
- Clan vars management is desired

**See also:**
- `machines/app-vm-01/configuration.nix` - Complete example
- `inventory/core/machines.nix` - Machine registration
- WireGuard example in prompt - Similar pattern