## Why

The reviewed ttWKV7 one-shot runbook failed closed before service isolation because the non-interactive agent cannot satisfy a general sudo authentication prompt. Broad passwordless sudo, wildcard systemctl access, mutable manual sudoers edits, and dependence on an interactive credential cache would weaken the host security and reproducibility boundaries. The managed host needs a durable least-privilege capability for only the device-1 owner lifecycle and read-only ownership check.

## What Changes

- Declare passwordless sudo permissions for exactly `start` and `stop` of the device-1 P150 owner unit plus read-only `lsof` of `/dev/tenstorrent/1`.
- Install an immutable `ttwkv7-owner-control` wrapper with `validate`, `isolate`, and `restore` modes, fixed command paths, fixed unit/device targets, and automatic restoration when isolation validation fails.
- Add positive and negative machine checks that require the exact capability while rejecting wildcard systemctl, restart, unrelated-unit, arbitrary-device, and broad passwordless rules.
- Document that owner control grants no probe authorization and remains separate from runtime preflight and one-shot hardware review.

## Impact

- **Files**: `pkgs/ttwkv7-owner-control/`, `machines/britton-desktop/configuration.nix`, `flake-outputs/_machine-checks.nix`, and the Tenstorrent runtime Cairn specification
- **Security**: `brittonr` gains non-interactive control of one existing service and read-only ownership inspection of one existing device; no arbitrary root command, wildcard unit, restart verb, or probe execution is authorized
- **Validation**: baseline and final accelerator inventory, complete host closure, wrapper positive/negative CLI checks, exact sudo capability evaluation, formatting, and Cairn gates
- **Operations**: no deployment, service mutation, device access, or hardware authorization is part of this change
