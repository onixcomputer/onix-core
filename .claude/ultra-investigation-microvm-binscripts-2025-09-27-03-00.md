# ULTRA Investigation: MicroVM binScripts Runtime Secrets Issue
**Timestamp:** 2025-09-27 03:00:00 EDT
**Status:** 🔍 ROOT CAUSE IDENTIFIED + SOLUTION DESIGNED

## Executive Summary

The microVM runtime secrets injection via `binScripts.microvm-run` customization in declarative VMs is blocked by a **design limitation in microvm.nix's runner.nix** where custom binScripts are always overridden by defaults. A derived solution has been designed that overrides `declaredRunner` to inject runtime secrets from systemd LoadCredential into OEM strings.

---

## Root Cause Analysis

### The Problem

Configuration in `machines/britton-desktop/configuration.nix`:
```nix
microvm.vms.test-vm.config = { pkgs, lib, config, ... }: {
  microvm.binScripts.microvm-run = lib.mkForce ''
    # Custom script with LoadCredential logic
  '';
};
```

**Expected:** Custom runner script replaces default
**Actual:** Default runner script always used

### Deep Investigation via Parallel Agents

#### Agent 1: Architecture Analysis
- **Finding:** microvm.nix architecture is correctly designed
- **Evidence:** Guest `binScripts` DO propagate to `declaredRunner` via module system
- **Source:** `/nix/store/*/microvm.nix/nixos-modules/host/default.nix:62` uses `guestConfig.microvm.declaredRunner`

#### Agent 2: Closure Analysis
- **Finding:** Two distinct closures exist
  - **Working:** `/nix/store/lvl0ngd2fav57v9cb6w6niqfk74wxzcm` (3672 byte runner with LoadCredential)
  - **Current:** `/nix/store/lyyarffjbwhv6s1v5gfbv1r7lym023yj` (1662 byte default runner)
- **Evidence:** Working closure WAS built from correct config, but current builds don't produce it

#### Agent 3: Research
- No additional patterns found beyond documented approaches

#### Agent 4: Module Evaluation
- **Finding:** Evaluation boundary between host/guest is clean
- **Evidence:** Guest config evaluated independently, produces `declaredRunner` used by host
- **Confirmation:** Syntax `microvm.vms.<name>.config = {...}` is VALID and CORRECT

### The Smoking Gun: runner.nix Line 46-57

```nix
binScripts =
  microvmConfig.binScripts  # Custom scripts from guest config (LEFT)
  // {
    microvm-run = ''       # Default script (RIGHT) ← ALWAYS WINS
      set -eou pipefail
      ${preStart}
      ${createVolumesScript microvmConfig.volumes}
      ...
      exec ${execArg} ${command}
    '';
  }
  // lib.optionalAttrs canShutdown {...}
  // lib.optionalAttrs (setBalloonScript != null) {...};
```

**The Nix `//` operator means RIGHT SIDE WINS in attribute set merges.**

Even if `microvmConfig.binScripts.microvm-run` is set with `lib.mkForce`, the default on lines 49-56 OVERRIDES it because it's on the right side of `//`.

### Why lib.mkForce Doesn't Help

The `binScripts` option definition (options.nix:688-694):
```nix
binScripts = mkOption {
  description = "Script snippets that end up in the runner package's bin/ directory";
  default = {};
  type = with types; attrsOf lines;
};
```

This is a simple `attrsOf lines`, NOT a module system option with priority handling. Therefore `lib.mkForce` has NO EFFECT - it's just a plain attribute set merge where runner.nix's default ALWAYS wins.

---

## Alternative Approaches Investigated

### ❌ Approach 1: Use preStart
**Problem:** OEM strings are hardcoded in the hypervisor command, not injectable from preStart env vars

###  Approach 2: Use microvm.cloud-hypervisor.platformOEMStrings
**Found:** This is the CORRECT option for static OEM strings (options.nix:575-592)
**Problem:** Evaluated at BUILD time, cannot inject RUNTIME secrets from LoadCredential

### ❌ Approach 3: Rely on binScripts propagation
**Problem:** As proven above, runner.nix always overrides custom binScripts.microvm-run

---

## The Solution: Override declaredRunner

Since `declaredRunner` is just a module option with a default value, we CAN override it:

```nix
microvm.vms.test-vm.config = { pkgs, lib, config, ... }: {
  microvm.declaredRunner = lib.mkForce (
    # Build custom runner that reads from $CREDENTIALS_DIRECTORY
    # and injects into OEM strings at runtime
  );
};
```

### Implementation Strategy

1. **Read the default runner generation** from microvm.nix lib
2. **Modify the binScripts.microvm-run** in our override to include:
   - Reading from `$CREDENTIALS_DIRECTORY`
   - Building OEM strings with runtime secrets
   - Calling cloud-hypervisor with modified `--platform` arg
3. **Use the modified binScripts** in a custom runner build
4. **Set as declaredRunner** with lib.mkForce

### Advantages
- ✅ Fully derived (no hardcoded store paths)
- ✅ Uses systemd LoadCredential properly
- ✅ Injects runtime secrets into guest via OEM strings
- ✅ Maintains all other microvm.nix functionality
- ✅ Clean separation: host provides secrets, guest receives via SMBIOS

---

## Evidence Trail

### Working Closure Evidence
```bash
$ cat /nix/store/2fa1lq73q9c0509hxwdxkyq2kywj5z7k-microvm-test-vm-microvm-run | head -20
#!/nix/store/.../bash
set -eou pipefail

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  MicroVM: test-vm"
echo "║  Loading Runtime Secrets via systemd LoadCredential"
echo "╚══════════════════════════════════════════════════════════╝"

# Read secrets from systemd credentials directory
if [ -n "${CREDENTIALS_DIRECTORY:-}" ]; then
  if [ -f "$CREDENTIALS_DIRECTORY/host-api-key" ]; then
    API_KEY=$(cat "$CREDENTIALS_DIRECTORY/host-api-key" | tr -d '\n')
    ...
```

### Default Closure Evidence
```bash
$ cat /nix/store/mc5gi9pjf5a2a19c0syr42ahddslg5a9-microvm-test-vm-microvm-run | head -10
#!/nix/store/.../bash
set -eou pipefail

# workaround cloud-hypervisor sometimes
# stumbling over a preexisting socket
rm -f 'test-vm.sock'

# Ensure notify sockets are removed...
```

### Live System State
```bash
$ systemctl cat microvm@test-vm.service | grep LoadCredential
LoadCredential=host-api-key:/run/secrets/vars/test-vm-secrets/api-key
LoadCredential=host-db-password:/run/secrets/vars/test-vm-secrets/db-password
LoadCredential=host-jwt-secret:/run/secrets/vars/test-vm-secrets/jwt-secret
```

**LoadCredential IS configured** but the runner doesn't use it because it's the default runner without customization.

---

## Timeline of Issue

1. **2025-09-27 00:59:24** - Working configuration deployed, VM received 44/44/88 byte secrets
2. **2025-09-27 01:32:XX** - User deleted `/var/lib/microvms` and ran `clan m update`
3. **2025-09-27 01:33:03** - VM restarted with default runner, receiving 0 bytes for all secrets
4. **2025-09-27 01:50:58** - Commit 6d74aed created with "Fix microvm binScripts variable scoping"
5. **2025-09-27 02:XX:XX** - Multiple rebuilds, but system closure still references default runner
6. **2025-09-27 03:00:00** - Root cause identified via ULTRA investigation

---

## Key Learnings

1. **microvm.nix has a design limitation** where custom binScripts.microvm-run cannot override defaults in declarative VMs
2. **lib.mkForce doesn't work** on attrsOf options, only module system options with priorities
3. **The working closure proves** the concept works, just needs correct implementation
4. **declaredRunner override** is the proper derived solution
5. **Runtime secret injection** requires customizing the runner script, not just config options

---

## Next Steps

1. Implement declaredRunner override with custom runner build
2. Test that runtime secrets flow correctly from host LoadCredential to guest OEM strings
3. Verify guest services can read credentials from `/run/credentials/@system/`
4. Document the pattern for other VMs requiring runtime secrets

---

## Technical Details for Implementation

### Required Components
1. Custom runner package that mimics microvm.nix's buildRunner
2. Modified binScripts.microvm-run that reads `$CREDENTIALS_DIRECTORY`
3. Dynamic OEM string construction from runtime secrets
4. Proper integration with clan vars generators

### Files Modified
- `machines/britton-desktop/configuration.nix` - Add declaredRunner override in guest config
- Existing LoadCredential and clan vars configs remain unchanged

### Testing Criteria
- [ ] Build produces custom runner (not default)
- [ ] systemd service passes credentials to runner
- [ ] Runner reads from $CREDENTIALS_DIRECTORY successfully
- [ ] OEM strings contain runtime secrets
- [ ] Guest receives credentials via SMBIOS Type 11
- [ ] Guest services can read from /run/credentials/@system/

---

**Investigation Complete. Solution Ready for Implementation.**