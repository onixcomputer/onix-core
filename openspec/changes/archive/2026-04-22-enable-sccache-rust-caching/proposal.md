## Why

`britton-desktop` currently reuses Rust artifacts through a manually managed `~/.cargo/config.toml` that points every Cargo build at `/home/brittonr/.cargo-target`. That saves disk, but it still leaves repeated `rustc` work uncached, causes cross-project target contention, and lives outside declarative workstation config. `sccache` can reuse compiler results across repeated builds and worktrees while letting Onix own the setup.

## What Changes

- Add a `sccache` home-manager profile for the current `hm-desktop` assignment, which in this inventory resolves only to `britton-desktop`, with only root-level `.nix` files as Home Manager modules while helper/data `.nix` files live under a non-auto-imported subdirectory.
- Install the Nix-managed `sccache` binary and generate repo-owned `~/.cargo/config.toml` + `~/.config/sccache/config` for the desktop user, using a local-only `32 GiB` cache under `/home/brittonr/.cache/sccache`.
- Preserve the current shared Cargo target-dir during the initial rollout, but move the existing manual Cargo defaults under repo management.
- Configure local-only path normalization for `/home/brittonr/git` and `/home/brittonr/git/worktrees` so a primary checkout and named worktree roots can reuse cache keys.
- Add workstation validation and troubleshooting flow around `sccache --show-stats`, a configured `SCCACHE_ERROR_LOG` path, repeated builds, and fail-open behavior triggered with a dead `SCCACHE_SERVER_UDS` path.
- **BREAKING**: home-manager becomes the source of truth for `~/.cargo/config.toml` on `britton-desktop`; the first managed activation must preserve the previous manual file as `~/.cargo/config.toml.pre-sccache`, fail closed rather than overwrite an existing backup, and use that saved file for manual rollback if the operator rejects the rollout.

## Non-Goals

- Remote cache backends, distributed compilation, or team-shared cache infrastructure.
- Non-Rust compiler/toolchain caching.
- Path-normalization guarantees for repos outside `/home/brittonr/git` during phase 1.
- Retiring the shared `/home/brittonr/.cargo-target` in the same change.

## Capabilities

### New Capabilities
- `rust-build-cache`: Declarative `sccache`-backed Rust compiler caching for `britton-desktop`, including Cargo integration, cache configuration, and validation workflow.

### Modified Capabilities
- None.

## Impact

- `inventory/core/users.ncl`: attach the new profile only to the current `hm-desktop` assignment, which today targets `britton-desktop` alone.
- `inventory/home-profiles/brittonr/sccache/`: new desktop-only home-manager profile, typed config data, and `README.md` troubleshooting guide.
- Generated `~/.cargo/config.toml` and `~/.config/sccache/config` on `britton-desktop`.
- Validation commands run against named Rust fixtures under `/home/brittonr/git`, using `chaoscontrol` plus `/home/brittonr/git/worktrees/chaoscontrol` for equivalent-worktree reuse and `crunch/crunch` for the exact `sccache --zero-stats; cargo build; cargo build; sccache --show-stats` repeated-build sequence.
