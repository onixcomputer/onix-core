# MicroVM Runtime Secrets Configuration Guide

This guide explains how to configure runtime secrets for microVMs using clan vars generators, systemd LoadCredential, and OEM strings. The implementation enables secure injection of host-generated secrets into guest VMs at runtime.

## Overview

The microVM runtime secrets system consists of four interconnected components:

1. **Clan Vars Generator** - Generates secrets on the host
2. **SystemD LoadCredential** - Makes secrets available to the microVM systemd service
3. **MicroVM credentialFiles** - Declares which credentials to inject via OEM strings
4. **Guest Service Configuration** - Consumes credentials inside the VM

## Step-by-Step Configuration

### Step 1: Define Secrets with Clan Vars Generator

Create a clan vars generator that produces the secrets your microVM needs:

```nix
# In your machine configuration.nix
clan.core.vars.generators.test-vm-secrets = {
  files = {
    "api-key" = {
      secret = true;
      mode = "0400";
    };
    "db-password" = {
      secret = true;
      mode = "0400";
    };
    "jwt-secret" = {
      secret = true;
      mode = "0400";
    };
  };

  runtimeInputs = with pkgs; [
    coreutils
    openssl
  ];

  script = ''
    openssl rand -base64 32 | tr -d '\n' > "$out/api-key"
    openssl rand -base64 32 | tr -d '\n' > "$out/db-password"
    openssl rand -base64 64 | tr -d '\n' > "$out/jwt-secret"

    chmod 400 "$out"/*
  '';
};
```

**What this does:**
- Creates three secret files with restricted permissions (0400)
- Uses OpenSSL to generate cryptographically secure random values
- Files are stored in the Nix store with unique paths per generation

**Important:** The generator name (`test-vm-secrets`) should match your microVM name for clarity.

### Step 2: Connect Secrets to SystemD Service with LoadCredential

Configure the microVM's systemd service to load the generated secrets:

```nix
systemd.services."microvm@test-vm".serviceConfig.LoadCredential = [
  "host-api-key:${config.clan.core.vars.generators.test-vm-secrets.files."api-key".path}"
  "host-db-password:${config.clan.core.vars.generators.test-vm-secrets.files."db-password".path}"
  "host-jwt-secret:${config.clan.core.vars.generators.test-vm-secrets.files."jwt-secret".path}"
];
```

**What this does:**
- Makes secrets available to the microVM systemd service
- Creates credential names with `host-` prefix to distinguish from guest credentials
- SystemD manages secure access and cleanup of credentials

**Naming Convention:** Use `host-<secret-name>` format for LoadCredential names.

### Step 3: Declare credentialFiles in MicroVM Config

Tell the microVM which credentials to inject as OEM strings:

```nix
microvm.vms.test-vm = {
  config = { ... }: {
    microvm = {
      # ... other microVM config ...

      credentialFiles = {
        "host-api-key" = { };
        "host-db-password" = { };
        "host-jwt-secret" = { };
      };

      # Optional: Add static OEM strings for non-secret config
      cloud-hypervisor.platformOEMStrings = [
        "io.systemd.credential:ENVIRONMENT=test"
        "io.systemd.credential:CLUSTER=britton-desktop"
      ];
    };
  };
};
```

**What this does:**
- Declares which LoadCredential entries to inject into the VM
- Creates OEM strings in the format `io.systemd.credential:UPPERCASE_NAME=content`
- Static OEM strings can be added for non-secret configuration

**Critical:** credentialFiles names MUST exactly match LoadCredential names.

### Step 4: Configure Guest Services to Consume Credentials

Inside the guest VM, configure services to load the injected credentials:

```nix
# Inside the microVM config
systemd.services.demo-oem-credentials = {
  description = "Service that uses injected credentials";
  wantedBy = [ "multi-user.target" ];

  serviceConfig = {
    Type = "oneshot";
    LoadCredential = [
      # Static credentials from OEM strings
      "environment:ENVIRONMENT"
      "cluster:CLUSTER"
      # Runtime secrets from OEM strings (note: no 'host-' prefix)
      "api-key:API_KEY"
      "db-password:DB_PASSWORD"
      "jwt-secret:JWT_SECRET"
    ];
  };

  script = ''
    echo "Environment: $(cat $CREDENTIALS_DIRECTORY/environment)"
    echo "API Key length: $(wc -c < $CREDENTIALS_DIRECTORY/api-key) bytes"
    # Use secrets for your application...
  '';
};
```

**What this does:**
- SystemD automatically loads credentials from OEM strings
- Credentials are available via `$CREDENTIALS_DIRECTORY/credential-name`
- SystemD handles secure cleanup when service stops

## Naming Convention Requirements

The naming transformation follows this pattern:

| Component | Format | Example |
|-----------|--------|---------|
| Generator file | `kebab-case` | `api-key` |
| LoadCredential | `host-kebab-case` | `host-api-key` |
| credentialFiles | `host-kebab-case` | `host-api-key` |
| OEM string | `io.systemd.credential:UPPER_CASE` | `io.systemd.credential:API_KEY` |
| Guest LoadCredential | `kebab-case:UPPER_CASE` | `api-key:API_KEY` |

**Why names must match:**
1. **LoadCredential → credentialFiles**: Must match exactly for injection to work
2. **Generator file → LoadCredential**: Path reference must be correct
3. **credentialFiles → OEM string**: Automatic transformation strips `host-` and uppercases
4. **OEM string → Guest LoadCredential**: Guest service maps OEM credential to local name

## Minimal Working Example

Here's the absolute minimum configuration needed:

```nix
# 1. Generate secret
clan.core.vars.generators.my-vm-secrets = {
  files."secret-key" = { secret = true; mode = "0400"; };
  script = ''echo "my-secret-value" > "$out/secret-key"'';
};

# 2. Load into systemd service
systemd.services."microvm@my-vm".serviceConfig.LoadCredential = [
  "host-secret-key:${config.clan.core.vars.generators.my-vm-secrets.files."secret-key".path}"
];

# 3. Declare for injection
microvm.vms.my-vm.config.microvm.credentialFiles."host-secret-key" = { };

# 4. Use in guest
# Guest service with LoadCredential = [ "secret-key:SECRET_KEY" ];
# Access via: cat $CREDENTIALS_DIRECTORY/secret-key
```

## Adding More Credentials

To add a new credential:

1. **Add to generator files section:**
   ```nix
   "new-secret" = { secret = true; mode = "0400"; };
   ```

2. **Add generation logic:**
   ```nix
   script = ''
     # ... existing logic ...
     openssl rand -base64 32 > "$out/new-secret"
   '';
   ```

3. **Add LoadCredential entry:**
   ```nix
   "host-new-secret:${config.clan.core.vars.generators.test-vm-secrets.files."new-secret".path}"
   ```

4. **Add credentialFiles entry:**
   ```nix
   credentialFiles."host-new-secret" = { };
   ```

5. **Use in guest service:**
   ```nix
   LoadCredential = [ "new-secret:NEW_SECRET" ];
   ```

## Common Pitfalls to Avoid

### 1. Name Mismatches
- **Problem**: credentialFiles name doesn't match LoadCredential name
- **Error**: Secret not injected into VM
- **Solution**: Ensure exact name matching between LoadCredential and credentialFiles

### 2. Missing host- Prefix
- **Problem**: Using generator file name directly in LoadCredential
- **Error**: Confusing naming between host and guest credentials
- **Solution**: Always use `host-` prefix for LoadCredential names

### 3. Incorrect Guest Mapping
- **Problem**: Guest LoadCredential maps wrong OEM credential name
- **Error**: Secret not available in guest service
- **Solution**: Use `local-name:OEM_UPPER_CASE` format in guest LoadCredential

### 4. Forgetting to Generate Secrets
- **Problem**: Secrets not generated before VM starts
- **Error**: Empty or missing credential files
- **Solution**: Run `clan vars generate --machine <machine-name>` after configuration

### 5. Wrong File Permissions
- **Problem**: Generator doesn't set proper file permissions
- **Error**: SystemD can't read credential files
- **Solution**: Always set mode = "0400" and chmod in generator script

## Debugging Tips

### Check Secret Generation
```bash
# Verify secrets were generated
clan vars list --machine <machine-name>

# Regenerate if needed
clan vars generate --machine <machine-name>
```

### Check SystemD Service
```bash
# Check if credentials are loaded
systemctl show microvm@test-vm | grep LoadCredential

# Check service status
systemctl status microvm@test-vm
```

### Check Guest Credentials
```bash
# Inside the guest VM
systemd-creds --system list

# Check specific credential
systemd-creds cat API_KEY
```

### Check OEM Strings
```bash
# Inside the guest VM
dmidecode -t 11 | grep "String [0-9]"
```

## Security Considerations

1. **File Permissions**: Always use mode "0400" for secret files
2. **Service Isolation**: Guest services with LoadCredential run in isolated environments
3. **Cleanup**: SystemD automatically cleans up credentials when services stop
4. **Access Control**: Only services with LoadCredential can access specific credentials
5. **Transport Security**: OEM strings are injected at VM creation, not over network

## Integration with Clan Infrastructure

This pattern integrates with clan-core's secret management:

- **SOPS Integration**: Clan vars can use SOPS for encrypted storage
- **Machine-Specific Secrets**: Each machine can have unique credential sets
- **Deployment**: Secrets are generated and deployed with `clan machines update`
- **Access Control**: SOPS access control determines who can regenerate secrets

The microVM runtime secrets system provides a secure, declarative way to inject host-managed secrets into guest VMs while maintaining the isolation and security properties of both systemd credentials and microVM technology.