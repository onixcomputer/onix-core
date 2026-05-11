## Phase 1: Declarative policy

- [x] [serial] Write the OpenSpec package for bounded desktop Nix builds.
- [x] [serial] Implement bounded `max-jobs`, explicit `cores`, and `use-cgroups` for `britton-desktop`.
- [x] [serial] Add `nix-daemon.service` resource controls for CPU/IO priority and memory pressure.
- [x] [depends:desktop-build.cpu-isolation] Decide whether to enable CPU affinity, and document topology evidence if enabled.

## Phase 2: Verification

- [x] [depends:desktop-build.nix-parallelism] Evaluate the resolved `britton-desktop` Nix settings and record the local build budget.
- [x] [depends:desktop-build.daemon-resources] Evaluate the resolved `nix-daemon.serviceConfig` resource controls.
- [x] [depends:phase-1] Build the `britton-desktop` toplevel with the new settings.
- [x] [depends:phase-2] Capture a runtime sanity check showing constrained daemon cgroup placement during a representative build. ✅ `systemctl show nix-daemon.service` reported `CPUWeight=25`, `IOWeight=25`, `MemoryHigh=150323855360`, and `ControlGroup=/system.slice/nix-daemon.service`; `systemd-cgls` during active Rust/Nix builds showed `nix-build-uid-*` children under the constrained daemon cgroup.
