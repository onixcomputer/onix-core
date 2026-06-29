# nix-rust-build-cache Specification

## Purpose

Define an opt-in, Nix-owned kache integration for sandboxed Rust builds without inheriting user Cargo configuration or user cache state.

## Requirements

### Requirement: Opt-in Nix Rust cache pilot

r[onix.nix_rust_cache.scope] The Nix Rust kache integration MUST be disabled by default and MUST require an explicit Onix setting, derivation override, or package-level helper to opt in.

#### Scenario: Default Nix Rust builds stay unwrapped

r[onix.nix_rust_cache.scope.default]
- GIVEN a Rust derivation does not opt in to the Nix kache pilot
- WHEN the derivation is evaluated and built
- THEN it uses the normal Nix Rust compiler path
- AND it does not reference the kache wrapper package

#### Scenario: Pilot opt-in is explicit

r[onix.nix_rust_cache.scope.opt_in]
- GIVEN a selected Rust derivation opts in to the Nix kache pilot
- WHEN its compiler package is constructed
- THEN the derivation receives the Nix-owned kache wrapper or wrapped Rust package

### Requirement: Nix-owned rustc wrapper

r[onix.nix_rust_cache.wrapper] The pilot MUST provide Nix-owned Rust compiler wrappers that delegate to kache with the real Nix rustc path and preserve compatibility with Cargo/Crane and direct `buildRustCrate`-style toolchain use.

#### Scenario: Cargo wrapper delegates to kache

r[onix.nix_rust_cache.wrapper.delegates]
- GIVEN a Crane or Cargo derivation sets the Nix-owned `RUSTC_WRAPPER`
- WHEN Cargo invokes the wrapper with the real rustc path and rustc arguments
- THEN the wrapper invokes kache with the real rustc path and original rustc arguments

#### Scenario: Wrapped rust package delegates to kache

r[onix.nix_rust_cache.wrapper.toolchain]
- GIVEN the kache-wrapped Rust package is on a builder `PATH`
- WHEN direct toolchain consumers invoke `rustc`
- THEN the wrapper invokes kache with the real rustc path and original rustc arguments

#### Scenario: Rustdoc compatibility is preserved

r[onix.nix_rust_cache.wrapper.rustdoc]
- GIVEN a derivation uses the wrapped Rust package
- WHEN documentation or metadata tooling needs `rustdoc`
- THEN `rustdoc` resolves to a compatible tool from the same underlying Rust toolchain

### Requirement: Sandbox-owned cache path

r[onix.nix_rust_cache.sandbox] The pilot MUST use a machine-owned cache directory that is explicitly exposed to Nix builders and MUST NOT use `/home/brittonr/.cache/kache` or user Cargo configuration from the sandbox.

#### Scenario: Sandbox sees only the pilot cache

r[onix.nix_rust_cache.sandbox.cache_path]
- GIVEN a pilot-enabled NixOS machine
- WHEN a sandboxed Rust derivation runs
- THEN the derivation can access the configured machine-owned kache cache path
- AND it cannot rely on `/home/brittonr/.cargo/config.toml`

#### Scenario: Missing sandbox access fails safe

r[onix.nix_rust_cache.sandbox.missing_access]
- GIVEN the wrapper is enabled but the configured cache path is not available to the builder
- WHEN the wrapped rustc is invoked
- THEN the build fails with an actionable diagnostic or falls back only through an explicit disabled-cache mode

### Requirement: Nix toolchain cache-key salt

r[onix.nix_rust_cache.key_salt] The wrapper MUST include the real rustc store path and relevant compiler/linker store paths in the kache key salt, and SHOULD append an operator-provided pilot salt when configured.

#### Scenario: Toolchain changes change cache keys

r[onix.nix_rust_cache.key_salt.toolchain]
- GIVEN two builds use different Rust toolchain store paths
- WHEN both builds compile the same crate through kache
- THEN their kache keys differ

#### Scenario: Pilot salt is appended

r[onix.nix_rust_cache.key_salt.operator]
- GIVEN an operator configures an additional pilot salt
- WHEN the wrapper computes `KACHE_KEY_SALT`
- THEN the final salt includes both Nix toolchain identity and the operator-provided value

### Requirement: Changebot Crane integration example

r[onix.nix_rust_cache.changebot] The pilot SHOULD provide a checked `../changebot` Crane integration example that injects the Nix-owned wrapper without editing `../changebot`.

#### Scenario: Selected changebot example uses wrapped Cargo rustc

r[onix.nix_rust_cache.changebot.selected]
- GIVEN the `../changebot` Crane package is selected for the pilot
- WHEN the example expression is imported with kache enabled
- THEN the derivation sets `RUSTC_WRAPPER` to the Nix-owned kache wrapper
- AND the derivation sets `KACHE_NIX_CACHE_DIR` to the machine-owned cache path

#### Scenario: Disabled changebot example stays unwrapped

r[onix.nix_rust_cache.changebot.disabled]
- GIVEN the `../changebot` Crane example is imported with kache disabled
- WHEN the derivation is inspected
- THEN `RUSTC_WRAPPER` remains unset
- AND the normal unwrapped changebot package is used

### Requirement: Positive and negative validation

r[onix.nix_rust_cache.validation] The pilot MUST include validation evidence for wrapped builds, unwrapped fallback builds, sandbox access behavior, and cache activity telemetry.

#### Scenario: Wrapped pilot path records cache invocation

r[onix.nix_rust_cache.validation.cache_activity]
- GIVEN a selected pilot derivation uses the Nix-owned wrapper with an available cache path
- WHEN wrapper telemetry is inspected
- THEN the wrapper records kache invocation, rustc identity, cache directory, and key salt

#### Scenario: Unwrapped fallback avoids kache

r[onix.nix_rust_cache.validation.fallback_unwrapped]
- GIVEN the pilot is disabled for the same derivation
- WHEN the derivation builds
- THEN no kache wrapper invocation is observed

#### Scenario: User Cargo config is not used

r[onix.nix_rust_cache.validation.no_user_cargo]
- GIVEN a sandboxed Nix builder has `HOME=/homeless-shelter`
- WHEN the pilot build runs
- THEN success does not depend on `/home/brittonr/.cargo/config.toml`

### Requirement: Rollback and cleanup

r[onix.nix_rust_cache.rollback] The pilot MUST provide a rollback path that disables the wrapper and leaves only removable machine-owned cache state behind.

#### Scenario: Pilot disabled restores normal build path

r[onix.nix_rust_cache.rollback.disable]
- GIVEN the pilot setting is disabled
- WHEN the selected derivation is evaluated
- THEN it uses the normal unwrapped Nix Rust compiler path

#### Scenario: Cache cleanup is explicit

r[onix.nix_rust_cache.rollback.cleanup]
- GIVEN an operator decides to remove the pilot cache
- WHEN cleanup instructions are followed
- THEN only the configured machine-owned kache cache directory is removed
- AND user kache state is untouched