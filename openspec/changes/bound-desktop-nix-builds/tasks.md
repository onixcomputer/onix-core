## Phase 1: Declarative policy

- [x] [serial] Write the OpenSpec package for bounded desktop Nix builds.
- [ ] [serial] Implement bounded `max-jobs`, explicit `cores`, and `use-cgroups` for `britton-desktop`.
- [ ] [serial] Add `nix-daemon.service` resource controls for CPU/IO priority and memory pressure.
- [ ] [depends:desktop-build.cpu-isolation] Decide whether to enable CPU affinity, and document topology evidence if enabled.

## Phase 2: Verification

- [ ] [depends:desktop-build.nix-parallelism] Evaluate the resolved `britton-desktop` Nix settings and record the local build budget.
- [ ] [depends:desktop-build.daemon-resources] Evaluate the resolved `nix-daemon.serviceConfig` resource controls.
- [ ] [depends:phase-1] Build the `britton-desktop` toplevel with the new settings.
- [ ] [depends:phase-2] Capture a runtime sanity check showing constrained daemon cgroup placement during a representative build.
