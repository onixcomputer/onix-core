## Why

`britton-desktop` currently permits Nix to oversubscribe build work: `max-jobs = 32` with `cores = 0` lets each derivation see all 32 hardware threads, and live Rust builds produced very high load while the desktop needed to stay interactive. The workstation needs a declarative build-resource policy that preserves throughput without starving the compositor, browser, editor, and input path.

## What Changes

- Add a `britton-desktop` Nix build-resource policy for bounded local parallelism.
- Enable Nix build cgroups so per-build accounting/limits can work.
- Apply systemd resource controls to `nix-daemon.service` for CPU, IO, memory pressure, and optional CPU affinity.
- Preserve remote-builder/substituter use so large builds can move off the desktop when needed.

## Capabilities

### New Capabilities
- `desktop-build-resources`: Desktop-safe Nix build execution for `britton-desktop`.

## Impact

- **Files**: `machines/britton-desktop/configuration.nix` and any shared host/profile module chosen during implementation.
- **APIs**: NixOS configuration only; no public runtime API.
- **Dependencies**: No new package dependency required.
- **Testing**: Evaluate `nixosConfigurations.britton-desktop` resource settings and build the toplevel with the desktop-safe Nix options.
