## Context

Observed live state on `britton-desktop` showed a Ryzen 9 9950X3D with 32 hardware threads, 186 GiB RAM, zram swap, `/nix` on ZFS/NVMe, `max-jobs = 32`, `cores = 0`, `use-cgroups = false`, and no configured `nix-daemon.service` resource weights. Under Rust/Nix load, the system reported very high load averages and many concurrent `rustc`/Cargo processes under `nix-daemon.service`.

## Goals / Non-Goals

**Goals:**
- Bound local Nix parallelism so the desktop remains responsive during routine builds.
- Prefer declarative NixOS/systemd controls over ad hoc shell aliases.
- Keep an explicit validation path that checks resolved config, not just file syntax.
- Leave enough throughput for normal workstation development.

**Non-Goals:**
- Permanently disable local builds.
- Tune every project-specific Cargo profile.
- Repartition storage or migrate `/nix`.
- Claim a universal best setting for all future hardware.

## Decisions

### 1. Start with conservative Nix parallelism

**Choice:** Set `nix.settings.max-jobs` and `nix.settings.cores` for `britton-desktop` instead of leaving `cores = 0`.

**Rationale:** Nix documents worst-case consumed cores as `max-jobs * NIX_BUILD_CORES`; with `cores = 0`, each derivation can see all cores. A conservative starting point such as `max-jobs = 8` and `cores = 2` limits the requested local build width while preserving parallel derivation scheduling.

**Alternative:** Keep `max-jobs = 32` and rely only on scheduler fairness. Rejected because live evidence already showed excessive build pressure.

### 2. Use systemd resource controls for desktop protection

**Choice:** Configure `nix-daemon.service` with lower CPU/IO weight and memory pressure limits.

**Rationale:** `max-jobs`/`cores` reduce planned build concurrency, while systemd cgroup properties protect the desktop when individual builders ignore requested cores or hit memory-heavy phases.

**Alternative:** Use only `nice`/`ionice` wrappers. Rejected because daemon-managed builds and child processes need a declarative service-level boundary.

### 3. Treat CPU affinity as tunable hardware policy

**Choice:** Allow implementation to reserve one CCD or a high-preference CPU set for interactive desktop work, verified against `britton-desktop` CPU topology before rollout.

**Rationale:** The 9950X3D exposes two CCD-sized CPU groups. Pinning Nix builds away from the preferred/high-clock interactive set can improve UI responsiveness, but it must remain a documented/tunable policy rather than a magic constant.

**Alternative:** Hard-code affinity without evidence. Rejected because BIOS/kernel topology can change and needs validation.

## Risks / Trade-offs

**Longer local builds** → Start conservative, document how to raise `cores` or use remote-only builds for large runs.

**Affinity misclassification** → Verify CPU topology and resolved systemd `AllowedCPUs`; keep the setting host-specific.

**Memory cap kills legitimate builds** → Use `MemoryHigh` as pressure first and set any hard `MemoryMax` with enough headroom for Rust/Nix workloads.
