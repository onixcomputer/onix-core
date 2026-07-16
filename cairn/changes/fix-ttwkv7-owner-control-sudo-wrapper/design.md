# Design: NixOS sudo trampoline for ttWKV7 owner control

## Context

The deployed sudoers file contains the three reviewed argument-exact commands, but the helper embeds `/nix/store/...-sudo-.../bin/sudo`. Nix store files do not carry the setuid transition required by sudo, so validation fails with `must be owned by uid 0 and have the setuid bit set` before any grant is checked.

NixOS exposes setuid programs through root-owned wrappers under `/run/wrappers/bin`. The helper must use that runtime trampoline while preserving immutable store paths for the privileged systemctl and lsof commands authorized by sudoers.

## Goals

- Make non-interactive grant validation work on an activated NixOS host.
- Preserve the exact unit, device path, command arguments, and fail-closed lifecycle.
- Reject regression to a raw store sudo executable during device-free machine checks.
- Complete activation without service isolation or hardware access.

## Non-Goals

- Expanding sudoers permissions.
- Invoking `isolate`, `restore`, or a hardware probe during deployment validation.
- Repairing or rotating unrelated SOPS material.

## Decisions

### Use `/run/wrappers/bin/sudo`

The package embeds the canonical absolute NixOS setuid wrapper path. This path is mutable only by root-managed activation and supplies the privilege transition that raw store binaries intentionally lack.

### Keep privileged targets immutable

Systemctl and lsof remain fixed Nix store paths, and sudoers continues to match their complete argument vectors. Changing the sudo entrypoint does not authorize additional commands.

### Validate both sides of the boundary

Device-free checks require the canonical wrapper path, reject the raw `pkgs.sudo` path, and retain existing exact-command and broad-grant rejection. Activated-host validation runs only the helper's `validate` mode, which uses `sudo -n -l` and does not mutate service state.

### Accept activation only on converged evidence

Because an unrelated SOPS secret is known to fail, the switch command's status alone is insufficient. Acceptance requires the new `/run/current-system` and system profile, `visudo` success, active polkit and owner units, unchanged owner restart count, HTTP health, positive helper validation, and rejection of an unauthorized restart command.

## Risks and Mitigations

- **Runtime sudo wrapper is absent or damaged**: Absolute invocation fails before systemctl or lsof; validation reports the blocker.
- **Policy broadens during repair**: Existing evaluated and rendered-sudoers negative checks reject wildcard, restart, unrelated-unit/device, group-inherited, or `ALL` grants.
- **Activation partially applies around SOPS failure**: Verify every acceptance invariant and restore the previous profile if convergence fails.

## Validation Plan

1. Record the activated failure and verify owner/polkit health.
2. Gate the Cairn artifacts.
3. Replace the raw store sudo reference and strengthen positive/negative checks.
4. Rebuild the accelerator inventory and complete host closure.
5. Activate from the exact reviewed commit through fingerprint-pinned loopback root SSH.
6. Validate profile/current-system convergence, sudoers, helper grants, unauthorized-command rejection, owner health, and HTTP health.
7. Sync, archive, and commit the evidence without hardware access.
