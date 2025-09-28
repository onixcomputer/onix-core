# MicroVM binScripts Not Applied - Root Cause Analysis
**Date:** 2025-09-27 01:51:00 EDT
**Status:** 🔴 BLOCKED - binScripts customization not working

## Problem

The `binScripts.microvm-run` customization in `machines/britton-desktop/configuration.nix:148-230` is NOT being applied to the generated runner script.

### Evidence

1. **Current deployed script:** `/nix/store/mc5gi9pjf5a2a19c0syr42ahddslg5a9-microvm-test-vm-microvm-run`
   - Contains default template
   - Does NOT have "Loading Runtime Secrets" logic

2. **New built scripts exist:** `/nix/store/2fa1lq73q9c0509hxwdxkyq2kywj5z7k-microvm-test-vm-microvm-run`
   - Contains credential loading logic
   - But NOT referenced by system closure

3. **System closure unchanged:** `/nix/store/aga6qnphnjzwvxg0zp9cp6szfldl9jjk-nixos-system-britton-desktop-25.11.20250921.a1f79a1`
   - Still references OLD script
   - Multiple rebuilds produce same closure
   - Even after committing changes

## Configuration Structure

```nix
# HOST: machines/britton-desktop/configuration.nix
microvm.vms = {
  test-vm = {
    autostart = true;
    config = { pkgs, lib, config, ... }: {
      imports = [ inputs.microvm.nixosModules.microvm ];

      microvm = {
        hypervisor = "cloud-hypervisor";
        # ...

        binScripts.microvm-run = lib.mkForce (
          let microvmCfg = config.microvm; in
          ''
            # Custom script with credential loading
            ...
          ''
        );
      };
    };
  };
};
```

## Hypothesis

For `microvm.vms.<name>` (declarative VMs), the `binScripts` customization inside the guest `config` function may not affect the host-side runner generation.

### Why This Might Fail

1. **Evaluation Order:** Host evaluates `microvm.vms` definitions before guest configs are fully evaluated
2. **Module Scope:** `binScripts` in guest config doesn't propagate back to host's runner generation
3. **Different Pattern:** Declarative VMs may need runner customization at HOST level, not guest level

### Comparison

**app-vm-01 (WORKS):**
- Is itself a microvm (not using `microvm.vms`)
- `binScripts` at top-level of machine config
- Direct evaluation, no host/guest split

**test-vm in britton-desktop (FAILS):**
- Declared via `microvm.vms.test-vm`
- `binScripts` inside guest `config` function
- Host evaluates runner before guest config applies

## Attempted Fixes

1. ✅ Added `let microvmCfg = config.microvm` binding → No change
2. ✅ Merged `networking` attributes → No change
3. ✅ Committed changes to git → No change
4. ✅ Clean rebuild → No change

## Next Steps Required

### Option A: Move binScripts to Host Level

Instead of customizing inside guest config, override at host level AFTER microvm.vms evaluation:

```nix
microvm.vms.test-vm = { ... };  # Keep existing config

# Override the runner at HOST level
systemd.services."microvm@test-vm".serviceConfig.ExecStart = lib.mkForce [
  ""  # Clear default
  "/path/to/custom-runner"
];
```

### Option B: Use preStart Hook

Inject credential loading via `preStart` instead of replacing entire runner:

```nix
systemd.services."microvm@test-vm".serviceConfig.ExecStartPre = [
  "+/path/to/load-credentials-script"  # "+" means run as root
];
```

### Option C: Custom SystemD Unit

Create entirely custom unit that doesn't use microvm.vms pattern.

## Immediate Workaround

Since LoadCredential IS configured correctly, the issue is ONLY that the runner doesn't read from $CREDENTIALS_DIRECTORY.

**Manual test:** Run VM with custom script that reads credentials.

##Recommendation

Investigate how `microvm.vms` generates runners and whether `binScripts` customization is supported for declarative VMs. May need upstream microvm.nix module support or different configuration pattern.