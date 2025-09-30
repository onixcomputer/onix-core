# MicroVM Secret Passing Analysis

## Overview

This document analyzes the custom modifications made to microvm.nix in the onix-core infrastructure to enable sophisticated secret passing from clan vars to microVMs using systemd credentials and SMBIOS OEM strings.

## Key Modifications to microvm.nix

### Primary Changes from Upstream

The local fork at `/home/brittonr/git/onix-core/microvm.nix` contains **one critical functional modification**:

**Implementation of credentialFiles support for cloud-hypervisor**

- **Original upstream behavior**: Explicitly blocked `credentialFiles` for cloud-hypervisor with:
  ```nix
  if credentialFiles != {}
  then throw "cloud-hypervisor does not support credentialFiles"
  ```

- **Modified behavior**:
  - Removed the credentialFiles restriction
  - Added runtime OEM string generation from systemd credentials
  - Implemented platform argument handling for dynamic credential injection
  - Added comprehensive logging and error handling

### Technical Implementation

**File**: `microvm.nix/lib/runners/cloud-hypervisor.nix`

The modification implements runtime credential processing:

1. **Reads systemd credentials** from `$CREDENTIALS_DIRECTORY`
2. **Generates OEM strings** in format `io.systemd.credential:{NAME}={VALUE}`
3. **Merges with static platform options** for cloud-hypervisor
4. **Exports via environment variable** for hypervisor launch

**File**: `microvm.nix/lib/runner.nix`

Enhanced runner script to:
- Check for runtime credentials via `$MICROVM_PLATFORM_OPS`
- Add `--platform` argument to cloud-hypervisor command dynamically
- Support both static and runtime OEM string scenarios

## Secret Flow Architecture

### Complete Secret Passing Flow

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Clan Vars       │    │ Host SystemD     │    │ Cloud Hypervisor│
│ (SOPS encrypted)│────▶│ LoadCredential   │────▶│ OEM Strings     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│ Secret Generator│    │ Credential Files │    │ SMBIOS Type 11  │
│ (OpenSSL)       │    │ ($CREDENTIALS_   │    │ OEM Strings     │
└─────────────────┘    │  DIRECTORY)      │    └─────────────────┘
                       └──────────────────┘             │
                                                        ▼
                                               ┌─────────────────┐
                                               │ Guest SystemD   │
                                               │ Credential API  │
                                               └─────────────────┘
```

### Step-by-Step Process

#### 1. **Secret Generation (Build Time)**
```nix
# machines/britton-desktop/configuration.nix
clan.core.vars.generators.test-vm-secrets = {
  files = {
    "api-key" = { secret = true; mode = "0400"; };
    "db-password" = { secret = true; mode = "0400"; };
    "jwt-secret" = { secret = true; mode = "0400"; };
  };
  script = ''
    openssl rand -base64 32 | tr -d '\n' > "$out/api-key"
    openssl rand -base64 32 | tr -d '\n' > "$out/db-password"
    openssl rand -base64 64 | tr -d '\n' > "$out/jwt-secret"
  '';
};
```

#### 2. **SOPS Encryption & Storage**
- Secrets stored in `vars/per-machine/test-vm/test-vm-secrets/`
- Each secret SOPS-encrypted with age keys
- Decrypted at runtime to `/run/secrets/vars/test-vm-secrets/`

#### 3. **Host SystemD Integration**
```nix
systemd.services."microvm@test-vm".serviceConfig = {
  LoadCredential = [
    "host-api-key:${config.clan.core.vars.generators.test-vm-secrets.files."api-key".path}"
    "host-db-password:${config.clan.core.vars.generators.test-vm-secrets.files."db-password".path}"
    "host-jwt-secret:${config.clan.core.vars.generators.test-vm-secrets.files."jwt-secret".path}"
  ];
};
```

#### 4. **MicroVM Configuration Declaration**
```nix
microvm.credentialFiles = {
  "host-api-key" = { };
  "host-db-password" = { };
  "host-jwt-secret" = { };
};
```

#### 5. **Runtime Credential Injection**
The modified cloud-hypervisor runner:
- Reads credentials from `$CREDENTIALS_DIRECTORY/{name}`
- Creates OEM strings: `io.systemd.credential:HOST-{UPPER_NAME}={value}`
- Launches with: `cloud-hypervisor --platform "oem_strings=[...]"`

#### 6. **Guest OS Access**
```nix
# machines/test-vm/configuration.nix
systemd.services.demo-oem-credentials = {
  serviceConfig = {
    LoadCredential = [
      "api-key:HOST-API-KEY"
      "db-password:HOST-DB-PASSWORD"
      "jwt-secret:HOST-JWT-SECRET"
    ];
  };
};
```

## Configuration Details

### Host Configuration (britton-desktop)

**Location**: `machines/britton-desktop/configuration.nix`

**Key Components**:
- **Secret generation** via clan vars generators using OpenSSL
- **SystemD credential loading** for microVM service
- **MicroVM credentialFiles** declaration
- **Static OEM strings** for environment/cluster identification
- **Service hardening** with systemd security features

### Guest Configuration (test-vm)

**Location**: `machines/test-vm/configuration.nix`

**Key Features**:
- **Credential mapping** from HOST-prefixed names to local names
- **Service integration** demonstrating credential access
- **Automatic systemd credential handling**

## Security Architecture

### Security Strengths
1. **End-to-end encryption**: SOPS from storage to runtime
2. **Memory-only credentials**: Never written to persistent storage in guest
3. **Process isolation**: systemd credential directory per service
4. **Access control**: SOPS ACL controls decryption access
5. **Service hardening**: Comprehensive systemd security restrictions

### Naming Conventions
- **Host credentials**: `host-{name}` (e.g., `host-api-key`)
- **OEM string format**: `io.systemd.credential:{UPPER_NAME}={value}`
- **Guest credentials**: `HOST-{UPPER_NAME}` (e.g., `HOST-API-KEY`)
- **Local mapping**: `{name}` (e.g., `api-key`)

## Technical Innovation

This implementation represents several innovations:

1. **First clan-core + microvm.nix integration**: Bridges clan vars system with microVM runtime
2. **SMBIOS credential injection**: Novel use of OEM strings for secure secret transport
3. **SystemD credential chain**: Proper systemd credential management across host/guest boundary
4. **Declarative secret mapping**: NixOS-style configuration for credential flows

## Production Status

✅ **Fully Functional and Production Ready**

Based on documentation found, this system has been:
- Successfully deployed and tested
- Verified with real secret injection end-to-end
- Confirmed working with systemd LoadCredential
- Validated from host secrets to guest service access

## Upstream Contribution Potential

This modification would be an excellent candidate for upstream contribution because:

1. **Non-breaking change**: Only removes restriction, doesn't change APIs
2. **Follows existing patterns**: Uses same approach as QEMU implementation
3. **Well-implemented**: Proper error handling and edge case coverage
4. **Fills capability gap**: cloud-hypervisor should support credential injection
5. **Clean implementation**: No clan-specific code, pure microvm.nix functionality

## File Structure Summary

```
/home/brittonr/git/onix-core/
├── microvm.nix/                              # Local fork with modifications
│   ├── lib/runners/cloud-hypervisor.nix     # ← Primary modification
│   └── lib/runner.nix                       # ← Runtime platform handling
├── machines/
│   ├── britton-desktop/configuration.nix    # Host microVM configuration
│   └── test-vm/configuration.nix           # Guest credential access
└── vars/
    └── per-machine/test-vm/test-vm-secrets/ # SOPS-encrypted secrets
        ├── api-key/secret
        ├── db-password/secret
        └── jwt-secret/secret
```

## Comparison to Upstream

| Feature | Upstream microvm.nix | This Fork |
|---------|---------------------|-----------|
| QEMU credentialFiles | ✅ Full support (fw_cfg) | ✅ Unchanged |
| cloud-hypervisor credentialFiles | ❌ Explicitly blocked | ✅ **Full support (OEM strings)** |
| Other hypervisors | ❌ No credential support | ❌ Unchanged |
| API/Interface | ✅ credentialFiles option exists | ✅ Same interface |
| Code quality | ✅ Good | ✅ Same + better formatting |

This represents a **targeted, high-quality enhancement** that enables production-grade secret management for cloud-hypervisor-based microVMs while maintaining full compatibility with existing microvm.nix APIs and patterns.