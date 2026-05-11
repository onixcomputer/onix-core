## Why

Nix daemon controls do not cover every Rust build on `britton-desktop`: direct `cargo build`, editor-triggered checks, and one-off project commands can still consume all hardware threads. The existing Rust cache profile already manages Cargo config, sccache, mold, and the shared target dir; it needs an explicit desktop-safe job policy and cache-capacity plan that preserves the current compatibility surface.

## What Changes

- Extend the Rust build-cache contract with a default Cargo job limit for interactive builds.
- Define a supported resource-scoped wrapper/workflow for intentional large local builds.
- Add a cache/target storage policy so sccache and the shared target dir do not create surprise root-disk pressure.

## Capabilities

### Modified Capabilities
- `rust-build-cache`: Desktop Rust builds remain cached while respecting workstation responsiveness.

## Impact

- **Files**: Home Manager sccache/Cargo profile files and documentation under the `brittonr` home profile.
- **APIs**: User Cargo config and optional helper command/workflow only.
- **Dependencies**: No required new Rust dependency.
- **Testing**: Inspect generated Cargo config, run a small Cargo build, verify sccache still fails open, and check cache size/storage policy.
