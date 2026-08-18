## Why

Interactive Rust builds on `britton-desktop` now use kache through the managed Cargo `rustc-wrapper`, but sandboxed Nix Rust builds do not inherit `~/.cargo/config.toml`. A local probe confirmed that a Nix builder runs with `HOME=/homeless-shelter`, does not see `/home/brittonr/.cargo/config.toml`, and invokes `rustc` directly.

That isolation is good for purity, but it means repeated Nix Rust rebuilds cannot benefit from kache unless Onix provides a Nix-owned integration. `../changebot` is the selected example for this slice: it is a Crane-built Rust workspace, so the pilot proves an opt-in Nix-owned Cargo `RUSTC_WRAPPER` path for Crane while also providing a wrapped `rust` package helper for future `buildRustCrate` consumers.

## What Changes

- Add an opt-in Nix-owned kache Rust compiler wrapper for sandboxed Nix builders.
- Add machine-owned cache directory and sandbox access settings for selected NixOS hosts.
- Add a checked `../changebot`/Crane example that injects the Nix-owned wrapper through derivation environment rather than Cargo user config.
- Keep the pilot local-only, rollbackable, and isolated from `/home/brittonr/.cache/kache`.
- Add validation that proves wrapped builds use kache, unwrapped fallback still works, and missing sandbox/cache access fails safely.

## Impact

- **Scope**: Opt-in NixOS Rust builds, initially the `../changebot` Crane package example on `britton-desktop`.
- **Risk**: kache cache-key behavior must include the active rustc/toolchain and relevant linker inputs; sandbox access to a mutable cache must not compromise build reproducibility.
- **Non-goals**: Do not make global nixpkgs or all Onix Rust derivations use kache in the first slice. Do not use the user Home Manager Cargo wrapper inside Nix builders. Do not depend on a user kache daemon from sandboxed builds.
- **Testing**: Validate Cairn artifacts, evaluate NixOS sandbox settings, run positive and negative wrapper checks, and run `../changebot` evidence for wrapped and unwrapped Crane paths.