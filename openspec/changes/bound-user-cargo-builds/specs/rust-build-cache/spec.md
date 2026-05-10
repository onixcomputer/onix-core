## MODIFIED Requirements

### Requirement: Initial rollout preserves the shared Cargo target-dir
The workstation Rust build cache profile MUST preserve `britton-desktop`'s existing shared Cargo target directory and baseline Cargo defaults unless a later OpenSpec explicitly migrates them, and it MUST layer any desktop-safe Cargo job limit without removing the existing rustc-wrapper, linker, retry, or terminal behavior.

ID: rustcache.shared-target-compat

#### Scenario: managed Cargo file includes compatibility defaults
ID: rustcache.shared-target-compat.managed-cargo-file
- GIVEN home-manager activates the workstation Rust cache profile on `britton-desktop`
- WHEN the generated Cargo config is inspected
- THEN it keeps `target-dir = "/home/brittonr/.cargo-target"`
- AND it preserves `net.retry = 3` and `term.quiet = false`
- AND it keeps the managed rustc-wrapper and mold linker configuration

#### Scenario: direct Cargo builds have a bounded default job count
ID: rustcache.shared-target-compat.bounded-jobs
- GIVEN `brittonr` runs Cargo directly outside the Nix daemon on `britton-desktop`
- WHEN Cargo reads the managed `~/.cargo/config.toml`
- THEN the default build job count is explicitly bounded for desktop responsiveness
- AND the selected value is documented with the hardware/thread-count rationale

## ADDED Requirements

### Requirement: Heavy direct Cargo builds have a resource-scoped workflow [r[rustcache.resource-scoped-heavy-builds]]
The workstation Rust build environment MUST document a supported workflow for intentionally heavy direct Cargo builds that runs under explicit CPU/IO scheduling constraints instead of relying on an unrestricted foreground shell.

#### Scenario: operator runs a constrained heavy build [r[rustcache.resource-scoped-heavy-builds.systemd-scope]]
- GIVEN the operator needs a large direct Cargo build on `britton-desktop`
- WHEN they follow the documented resource-scoped workflow
- THEN the build runs with explicit CPU and IO resource policy
- AND the workflow preserves the managed rustc-wrapper and sccache behavior

### Requirement: Rust build cache storage is bounded and observable [r[rustcache.storage-policy]]
The Rust build cache profile MUST provide a documented local cache-size policy and an operator-visible way to inspect sccache and shared target-dir disk usage before they create desktop storage pressure.

#### Scenario: cache budget is inspected [r[rustcache.storage-policy.cache-budget]]
- GIVEN the managed sccache profile is active
- WHEN the generated sccache configuration is inspected
- THEN the configured local cache directory and size budget are visible
- AND the budget is documented as the current desktop policy

#### Scenario: target directory growth is inspected [r[rustcache.storage-policy.target-dir-usage]]
- GIVEN the shared Cargo target directory exists at `/home/brittonr/.cargo-target`
- WHEN the operator follows the documented inspection workflow
- THEN they can see current target-dir usage
- AND the documentation identifies whether cleanup, quota, or dataset migration is deferred to a future change
