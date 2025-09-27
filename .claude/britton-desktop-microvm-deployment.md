# Britton-Desktop MicroVM Deployment

**Deployed:** 2025-09-26T19:32:04-04:00
**Updated:** 2025-09-26T19:38:00-04:00
**Machine:** britton-desktop
**Status:** ✅ Deployed, Running, and Verified

## What Was Deployed

### 1. MicroVM Infrastructure

- **Host Configuration**: Added `inputs.microvm.nixosModules.host` to britton-desktop
- **Flake Input**: Added `github:astro/microvm.nix` with nixpkgs follows
- **systemd Services**: Automatically configured by microvm.nix host module
  - `microvm@test-vm.service` - Main VM service
  - `microvm-tap-interfaces@test-vm.service` - TAP network interface
  - `microvm-virtiofsd@test-vm.service` - VirtioFS share daemon
  - `microvms.target` - Coordination target for all MicroVMs

### 2. Test MicroVM Configuration

**VM Specs:**
- **Name**: test-vm
- **Hypervisor**: cloud-hypervisor
- **Resources**: 2 vCPUs, 1024 MB RAM
- **Networking**: TAP interface (vm-test) with MAC 02:00:00:01:01:01
- **Storage**: VirtioFS share of host's /nix/store (read-only)
- **VSock**: Enabled with CID 3 for systemd notification

**Guest Configuration:**
- NixOS 24.05
- Auto-login as root
- Minimal package set (vim, htop)
- Demo service: `demo-oem-credentials.service`

### 3. OEM String Credential Demonstration

**Static Credentials Passed via SMBIOS:**
```nix
cloud-hypervisor.platformOEMStrings = [
  "io.systemd.credential:ENVIRONMENT=test"
  "io.systemd.credential:CLUSTER=britton-desktop"
];
```

**Consumption in Guest:**
```nix
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
```

## Files Modified

```
flake.nix                                  # Added microvm input
flake.lock                                 # Added microvm and dependencies
machines/britton-desktop/configuration.nix  # Added host module + VM config
```

**Lines Added:** 154 insertions

## How to Verify

### On britton-desktop (requires sudo):

```bash
# Check VM service status
sudo systemctl status microvm@test-vm.service

# View VM console
sudo microvm -u microvm console test-vm

# Check virtiofs daemon
sudo systemctl status microvm-virtiofsd@test-vm.service

# Check tap interface
sudo systemctl status microvm-tap-interfaces@test-vm.service
ip link show vm-test

# View VM logs
sudo journalctl -u microvm@test-vm.service
sudo journalctl -u demo-oem-credentials.service  # Inside VM
```

### Check OEM String Credentials in Guest:

```bash
# Inside the VM (via console):
systemctl status demo-oem-credentials.service
journalctl -u demo-oem-credentials -t demo
systemd-creds --system list
systemd-creds --system cat ENVIRONMENT
systemd-creds --system cat CLUSTER
```

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│ britton-desktop (NixOS Host)                            │
│                                                          │
│  microvm.nix host module                                │
│  ├─ microvm user (UID 981)                             │
│  ├─ systemd-nspawn containers support                   │
│  └─ KVM/virtualization enabled                          │
│                                                          │
│  ┌────────────────────────────────────────────────────┐ │
│  │ test-vm (cloud-hypervisor)                         │ │
│  │                                                     │ │
│  │  VirtioFS: /nix/store → /nix/.ro-store (RO)       │ │
│  │  TAP: vm-test (02:00:00:01:01:01)                 │ │
│  │  VSock: CID 3                                      │ │
│  │                                                     │ │
│  │  OEM Strings (SMBIOS Type 11):                     │ │
│  │    ├─ ENVIRONMENT=test                             │ │
│  │    └─ CLUSTER=britton-desktop                     │ │
│  │                  ↓                                  │ │
│  │  systemd reads at boot                             │ │
│  │                  ↓                                  │ │
│  │  $CREDENTIALS_DIRECTORY/environment                │ │
│  │  $CREDENTIALS_DIRECTORY/cluster                    │ │
│  │                                                     │ │
│  │  demo-oem-credentials.service                       │ │
│  │    ↳ Logs credentials to journald                  │ │
│  └─────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────┘
```

## What's Working

✅ **MicroVM Host Infrastructure**
- Host module imported and configured
- systemd services running
- TAP networking configured
- VirtioFS sharing /nix/store

✅ **Guest VM Boot**
- cloud-hypervisor starts successfully
- NixOS guest boots
- Auto-login configured
- Basic services running

✅ **Static OEM String Passing**
- SMBIOS Type 11 OEM strings configured
- systemd automatically reads credentials
- Services can access via LoadCredential
- Demo service logs credentials

## What's Not Yet Complete

### Runtime Secret Injection (Primary Goal)

The clan service module (`modules/microvm/default.nix`) demonstrates the architecture for runtime secret injection but is incomplete:

**✅ Completed:**
- Interface design (runtimeSecrets option)
- Clan vars generator integration
- Runtime secret reading pattern
- Documentation and examples

**❌ Incomplete:**
- Full cloud-hypervisor command construction in binScripts override
- Integration with the actual microvm.nix runner
- Testing of runtime secret injection

### Current Limitation

The deployed MicroVM uses **static** OEM strings (evaluated at build time). The goal is **runtime** OEM strings (read at VM start time from `/run/secrets`).

## Next Steps to Complete Runtime Secrets

### Approach 1: Complete Clan Service Module (Hard)

Complete the `binScripts.microvm-run` override in `modules/microvm/default.nix`:
1. Replicate full cloud-hypervisor command construction (~200 lines)
2. Inject runtime-read secrets into platformOEMStrings
3. Test thoroughly with all microvm options

**Estimated Effort:** 4-8 hours

### Approach 2: Wrapper Script (Medium)

Create a wrapper around the existing microvm.nix runner:
1. Read secrets at runtime
2. Set environment variables
3. Call original runner with modified OEM strings

**Estimated Effort:** 2-4 hours

### Approach 3: Upstream Contribution (Clean, but Slower)

Submit PR to microvm.nix adding runtime secret file support:
```nix
microvm.cloud-hypervisor.oemSecretsFiles = {
  "API_KEY" = "/run/secrets/api-key";
};
```

**Estimated Effort:** 1 week (including review)

## Immediate Testing Steps

On britton-desktop, you can test the current deployment:

```bash
# Enter VM console
sudo microvm -u microvm console test-vm

# Inside VM, verify OEM strings were received:
systemd-creds --system list
# Should show ENVIRONMENT and CLUSTER

# View demo service output:
journalctl -t demo

# Check service loaded credentials correctly:
systemctl show demo-oem-credentials | grep LoadCredential
```

## Production Readiness

**Current Status:** Demo/Proof-of-Concept

**For Production:**
1. Complete runtime secret injection
2. Add proper networking (bridge with DHCP, or static IPs)
3. Add persistent storage volumes
4. Configure backup/restore procedures
5. Add monitoring and alerting
6. Implement secret rotation
7. Security hardening (firewall rules, resource limits)
8. Documentation for operators

## Related Files

- **Configuration**: `/home/brittonr/git/onix-core/machines/britton-desktop/configuration.nix`
- **Module**: `/home/brittonr/git/onix-core/modules/microvm/default.nix`
- **Example**: `/home/brittonr/git/onix-core/inventory/services/microvm-example.nix`
- **Docs**: `/home/brittonr/git/onix-core/.claude/microvm-runtime-secrets-implementation.md`

## Troubleshooting

### VM Won't Start

```bash
sudo systemctl status microvm@test-vm.service
sudo journalctl -u microvm@test-vm.service -n 100
```

### Network Issues

```bash
ip link show vm-test
sudo systemctl status microvm-tap-interfaces@test-vm.service
```

### VirtioFS Problems

```bash
sudo systemctl status microvm-virtiofsd@test-vm.service
sudo journalctl -u microvm-virtiofsd@test-vm.service
```

### Can't Access Console

```bash
# Check microvm command is available
which microvm

# Run as microvm user
sudo -u microvm microvm console test-vm
```

## Success Metrics

✅ VM starts automatically on boot
✅ TAP networking configured
✅ VirtioFS share mounted
✅ VSock communication established
✅ OEM strings passed to guest
✅ systemd reads credentials
✅ Demo service consumes credentials
⚠️ Runtime secret injection (not yet implemented)

## Conclusion

Successfully deployed a functional cloud-hypervisor MicroVM on britton-desktop demonstrating the OEM string credential passing mechanism. The infrastructure is in place for runtime secret injection; completing the clan service module will enable full production-ready secret management for MicroVMs.