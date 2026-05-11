# rust-build-cache Specification

## Purpose
Define the workstation Rust build cache and direct Cargo build policy for `britton-desktop`, including shared target-dir compatibility, bounded foreground build parallelism, sccache fail-open behavior, and storage observability.

## Requirements
### Requirement: Initial rollout preserves the shared Cargo target-dir
The workstation Rust build cache profile MUST preserve `britton-desktop`'s existing shared Cargo target directory and baseline Cargo defaults unless a later OpenSpec explicitly migrates them, and it MUST layer any desktop-safe Cargo job limit without removing the existing rustc-wrapper, linker, retry, or terminal behavior.

#### Scenario: managed Cargo file includes compatibility defaults
- **WHEN** home-manager activates the workstation Rust cache profile on `britton-desktop`
- **THEN** the generated Cargo config MUST keep `target-dir = "/home/brittonr/.cargo-target"`
- **AND** it MUST preserve `net.retry = 3` and `term.quiet = false`
- **AND** it MUST keep the managed rustc-wrapper and mold linker configuration

#### Scenario: direct Cargo builds have a bounded default job count
- **WHEN** `brittonr` runs Cargo directly outside the Nix daemon on `britton-desktop`
- **THEN** the default build job count MUST be explicitly bounded for desktop responsiveness
- **AND** the selected value MUST be documented with the hardware/thread-count rationale

### Requirement: Heavy direct Cargo builds have a resource-scoped workflow
The workstation Rust build environment MUST document a supported workflow for intentionally heavy direct Cargo builds that runs under explicit CPU/IO scheduling constraints instead of relying on an unrestricted foreground shell.

#### Scenario: operator runs a constrained heavy build
- **WHEN** the operator needs a large direct Cargo build on `britton-desktop`
- **THEN** the documented workflow MUST run the build with explicit CPU and IO resource policy
- **AND** the workflow MUST preserve the managed rustc-wrapper and sccache behavior

### Requirement: Rust build cache storage is bounded and observable
The Rust build cache profile MUST provide a documented local cache-size policy and an operator-visible way to inspect sccache and shared target-dir disk usage before they create desktop storage pressure.

#### Scenario: cache budget is inspected
- **WHEN** the generated sccache configuration is inspected
- **THEN** the configured local cache directory and size budget MUST be visible
- **AND** the budget MUST be documented as the current desktop policy

#### Scenario: target directory growth is inspected
- **WHEN** the operator follows the documented inspection workflow
- **THEN** they MUST be able to see current target-dir usage for `/home/brittonr/.cargo-target`
- **AND** the documentation MUST identify whether cleanup, quota, or dataset migration is deferred to a future change
