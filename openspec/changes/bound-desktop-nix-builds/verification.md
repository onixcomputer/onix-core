# Verification

## Hardware baseline

Captured from `britton-desktop` before implementation:

- CPU: AMD Ryzen 9 9950X3D 16-Core Processor
- Hardware threads: 32 (`Thread(s) per core: 2`, `Core(s) per socket: 16`)
- Memory: 186 GiB total, 124 GiB available during capture
- Topology: one socket, one NUMA node, CPUs `0-31`

## Implemented desktop-safe Nix budget

Resolved evaluation after the change:

```json
{"cores":4,"maxJobs":4,"nixDaemon":{"CPUSchedulingPolicy":"batch","CPUWeight":25,"IOSchedulingClass":"idle","IOSchedulingPriority":7,"IOWeight":25,"MemoryHigh":"140G"},"useCgroups":true}
```

The local Nix budget is `max-jobs * cores = 4 * 4 = 16` build threads, which leaves half of the 32 hardware threads available for interactive desktop workloads. `use-cgroups = true` enables daemon-managed build accounting.

## CPU affinity decision

CPU affinity is intentionally not enabled in this slice. The 9950X3D exposes 32 online CPUs in one NUMA node and `amd_pstate=active` is already configured, so the first safety boundary should be scheduler/cgroup pressure (`max-jobs`, `cores`, `CPUWeight`, `IOWeight`, `MemoryHigh`) rather than hard-pinning the daemon to a possibly stale CCD/thread set. If lag remains after deploying these bounded settings, the next slice should capture CPPC/preferred-core evidence and evaluate an explicit `AllowedCPUs` reservation.

## Build proof

Command:

```bash
nix build --impure --option allow-import-from-derivation true .#nixosConfigurations.britton-desktop.config.system.build.toplevel --no-link --print-out-paths
```

Result:

```text
/nix/store/p9s93rlrq7xicbn3slhk5sflizx8c2r8-nixos-system-britton-desktop-26.05.20260507.68a8af9
```

## Runtime deployment blocker

The runtime cgroup-placement check is not captured yet because this Hermes session does not have passwordless sudo (`sudo: a password is required`), so it cannot apply the new system profile or restart `nix-daemon.service`. Current live daemon settings still show the old unbounded runtime state:

```text
ControlGroup=/system.slice/nix-daemon.service
CPUWeight=[not set]
IOWeight=[not set]
MemoryHigh=infinity
```

After deployment, rerun a representative daemon-managed Nix build and verify `systemctl show nix-daemon.service -p CPUWeight -p IOWeight -p MemoryHigh -p ControlGroup` plus `systemd-cgls /system.slice/nix-daemon.service` while the build is active.
