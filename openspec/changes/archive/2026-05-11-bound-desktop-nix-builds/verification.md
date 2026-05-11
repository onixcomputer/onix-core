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

## Runtime sanity check

The bounded daemon policy is now active at runtime. During a representative local Nix/Rust build, `nix-daemon.service` reported the configured CPU/IO/memory controls and active build users remained below the daemon service cgroup:

```text
ActiveState=active
ControlGroup=/system.slice/nix-daemon.service
CPUWeight=25
IOWeight=25
MemoryHigh=150323855360
IOSchedulingClass=3
IOSchedulingPriority=7
CPUSchedulingPolicy=3
```

`systemd-cgls --no-pager /system.slice/nix-daemon.service` showed multiple active `nix-build-uid-*` cgroups containing Rust/Cargo build processes under `/system.slice/nix-daemon.service`, for example:

```text
CGroup /system.slice/nix-daemon.service:
├─nix-build-uid-872939520
│ ├─420111 bash -e /nix/store/...-source-stdenv.sh...
│ ├─421394 /nix/store/...-cargo-1.97.0-nightly-.../bin/cargo ...
│ └─504307 rustc --crate-name h2 --edition=2021 ...
├─nix-build-uid-872480768
│ ├─420013 bash -e /nix/store/...-source-stdenv.sh...
│ ├─461667 /nix/store/...-cargo-1.97.0-nightly-.../bin/cargo ...
│ └─505123 rustc --crate-name hickory_resolver --edition=2021 ...
```

This satisfies the runtime placement check: active builder processes are children of the constrained daemon cgroup while the service has the lower CPU/IO weights and memory-pressure guard resolved above.
