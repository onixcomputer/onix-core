# Root Cause Analysis: MicroVM Secret Loading Never Worked
**Timestamp:** 2025-09-27 01:52:00 EDT
**Status:** 🔴 BOTH configurations were broken

## Timeline Reconstruction

### Phase 1: Early Failures (00:41-00:44)
**Configuration:** Custom microvm-run with DIRECT file reading
```bash
# Previous runner was trying:
cat /run/secrets/vars/test-vm-secrets/api-key
```

**Result:**
- Permission denied (microvm user can't read root:root 0400 files)
- VM crash-looped every ~7 seconds
- Service NEVER successfully started
- Logs show continuous restart attempts

**Evidence:**
```
Sep 27 00:41:39 britton-desktop microvm@test-vm[6981]: cat: /run/secrets/vars/test-vm-secrets/api-key: Permission denied
Sep 27 00:41:39 britton-desktop systemd[1]: microvm@test-vm.service: Failed with result 'exit-code'.
```

### Phase 2: Current State (01:33+)
**Configuration:** Default microvm-run (NO secret loading)
**Result:**
- VM starts successfully
- No credential loading attempted
- Guest receives NO secrets
- Service runs but credentials empty (0 bytes)

**Evidence:**
```
Sep 27 01:33:03: API_KEY = 0 bytes, DB_PASSWORD = 0 bytes, JWT_SECRET = 0 bytes
```

## What Changed at /var/lib/microvms Deletion

**Before Deletion:**
- `/var/lib/microvms/test-vm/current` pointed to custom-built runner
- Custom runner had secret-loading logic (but broken due to permissions)
- Source of this custom runner: UNKNOWN (not in git)

**After Deletion + clan m update:**
- `/var/lib/microvms/test-vm/current` regenerated from system closure
- System closure contains DEFAULT runner (no customization)
- Points to: `/nix/store/mc5gi9pjf5a2a19c0syr42ahddslg5a9-microvm-test-vm-microvm-run`

## Why binScripts Customization Doesn't Work

**Attempted Configuration:**
```nix
microvm.vms.test-vm = {
  config = { ... }: {
    microvm.binScripts.microvm-run = lib.mkForce ''
      # Custom script with LoadCredential reading
    '';
  };
};
```

**Problem:** For declarative VMs (`microvm.vms.<name>`), the `binScripts` defined inside the guest `config` function does NOT affect the host's runner generation.

**Architecture Explanation:**
1. Host evaluates `microvm.vms` definitions
2. Creates runner scripts for host systemd service
3. Guest config is evaluated separately
4. Guest's `binScripts` only affects guest-internal behavior (if at all)
5. Host runner is already generated before guest config is fully evaluated

**Proof:**
- Multiple rebuilds with `binScripts` customization
- System closure NEVER changes
- Always points to same default runner
- New scripts with customization ARE built but NOT referenced

## Source of Previous Custom Runner

**Mystery:** Where did the previous custom runner come from?

**Possibilities:**
1. **Manual imperative build:** User manually built and symlinked a custom runner
2. **Lost uncommitted work:** Configuration existed locally but never committed
3. **Different branch:** Was on a branch with working configuration, switched branches
4. **Manual file placement:** Directly edited /var/lib/microvms/test-vm/current

**Evidence Against Git Source:**
- Diff shows ALL microvm config was added in THIS session
- Original commit 3216733 had NO microvm.vms configuration
- No stashes contain working microvm configuration

## Solution Path Forward

Since `binScripts` in declarative VMs doesn't work, options are:

### Option A: Convert to Imperative Pattern ✅ RECOMMENDED
Like app-vm-01 (which DOES work):
- Machine itself IS the microvm
- binScripts at top-level
- Direct evaluation, no host/guest split

### Option B: SystemD ExecStart Override
Replace entire service command at HOST level:
```nix
systemd.services."microvm@test-vm".serviceConfig.ExecStart = lib.mkForce [
  ""
  "${customRunnerScript}"
];
```

### Option C: Wrapper Script
Create wrapper that:
1. Reads from $CREDENTIALS_DIRECTORY
2. Builds OEM strings
3. Calls cloud-hypervisor directly (not via microvm-run)

## Conclusion

**User's question:** "Why was this working before?"

**Answer:** **IT WASN'T.** Previous configuration was crash-looping with permission errors. Current configuration runs but without secrets. Neither ever successfully loaded secrets into the guest VM.

The custom runner that existed in /var/lib/microvms was from an unknown source (not git) and was broken (permission denied). When cleared and regenerated, it was replaced with the default runner from the system closure, which also doesn't load secrets but at least doesn't crash.

**Next steps:** Implement Option A (imperative pattern) or Option B (ExecStart override) to actually get working secret injection.