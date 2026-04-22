## ADDED Requirements

### Requirement: Desktop Cargo builds use sccache by default
ID: rustcache.desktop-wrapper
The `britton-desktop` user environment MUST install a wrapped `sccache` binary on `PATH` and configure Cargo to use a dedicated Nix-managed rustc-wrapper that invokes that wrapped `sccache` by default.

#### Scenario: cargo build uses managed wrapper
ID: rustcache.desktop-wrapper.cargo-build
- **WHEN** `brittonr` runs `cargo build` on `britton-desktop` after home-manager activation
- **THEN** Cargo uses the dedicated Nix-managed rustc-wrapper as `build.rustc-wrapper`
- **AND** that rustc-wrapper invokes the wrapped `sccache` binary
- **AND** no manual `RUSTC_WRAPPER` export is required

### Requirement: Initial rollout stays on britton-desktop only
ID: rustcache.desktop-scope
The managed `sccache` profile MUST be attached only to `britton-desktop`'s current home-manager assignment until the workstation rollout is validated.

#### Scenario: other machines evaluate home-manager profiles
ID: rustcache.desktop-scope.non-desktop
- **WHEN** any machine other than `britton-desktop` evaluates its home-manager profile list
- **THEN** it does not import the new `sccache` profile
- **AND** its Rust toolchain behavior remains unchanged by this change

### Requirement: Managed Cargo and sccache config files are repo-owned
ID: rustcache.managed-config
Home Manager MUST become the source of truth for both `~/.cargo/config.toml` and `~/.config/sccache/config` on `britton-desktop`, a Nix-managed wrapped `sccache` plus a Nix-managed Cargo rustc-wrapper MUST deliver `SCCACHE_IGNORE_SERVER_IO_ERROR=1` and `SCCACHE_ERROR_LOG=/home/brittonr/.cache/sccache/error.log` for every Cargo-driven invocation, and only root-level `.nix` files may act as Home Manager modules while helper/data `.nix` files live under a non-auto-imported subdirectory.

#### Scenario: home-manager activates the desktop Rust cache profile
ID: rustcache.managed-config.file-ownership
- **WHEN** home-manager activates the `sccache` profile on `britton-desktop`
- **THEN** it writes managed `~/.cargo/config.toml` and `~/.config/sccache/config` files
- **AND** the managed Cargo config points `build.rustc-wrapper` at a dedicated Nix-managed rustc-wrapper
- **AND** the managed rustc-wrapper and wrapped `sccache` deliver `SCCACHE_IGNORE_SERVER_IO_ERROR=1` and `SCCACHE_ERROR_LOG=/home/brittonr/.cache/sccache/error.log`

#### Scenario: first activation takes over an existing manual Cargo config
ID: rustcache.managed-config.first-activation
- **WHEN** the rollout first replaces a pre-existing manual `~/.cargo/config.toml` on `britton-desktop`
- **THEN** the previous file is preserved as `~/.cargo/config.toml.pre-sccache` before activation continues
- **AND** activation fails closed instead of overwriting an existing `~/.cargo/config.toml.pre-sccache` backup
- **AND** if the operator rejects the rollout, manual rollback removes the desktop profile, re-activates, and copies `~/.cargo/config.toml.pre-sccache` back to `~/.cargo/config.toml`

#### Scenario: profile root only contains module `.nix` files
ID: rustcache.managed-config.profile-root-layout
- **WHEN** files are added under `inventory/home-profiles/brittonr/sccache/`
- **THEN** every root-level `.nix` file is a Home Manager module
- **AND** plain `.nix` data or helper files live under a non-auto-imported subdirectory such as `inventory/home-profiles/brittonr/sccache/lib/`

### Requirement: Phase 1 cache backend remains local-only
ID: rustcache.local-only
Phase 1 MUST configure only local disk storage in `~/.config/sccache/config` and MUST NOT configure remote or distributed cache backends.

#### Scenario: generated sccache config is inspected
ID: rustcache.local-only.config-inspection
- **WHEN** the generated `~/.config/sccache/config` is inspected on `britton-desktop`
- **THEN** it configures `dir = "/home/brittonr/.cache/sccache"` with a `32 GiB` local cache budget
- **AND** it does not configure remote or distributed cache backends

### Requirement: Cache keys normalize the shared workspace roots
ID: rustcache.workspace-basedirs
The generated `~/.config/sccache/config` MUST set `basedirs = ["/home/brittonr/git", "/home/brittonr/git/worktrees"]` so the shared workspace root is stripped from cache-key path prefixes while repo-relative paths below each configured root remain significant, and `inventory/home-profiles/brittonr/sccache/README.md` MUST document the `chaoscontrol` primary-checkout vs worktree validation flow.

#### Scenario: equivalent checkout uses a second worktree root
ID: rustcache.workspace-basedirs.checkout-path
- **WHEN** the validation workflow runs `sccache --zero-stats`, runs `cargo build` in `/home/brittonr/git/chaoscontrol`, records `sccache --show-stats`, then runs `cargo clean` and `cargo build` in `/home/brittonr/git/worktrees/chaoscontrol` at the same Git revision before recording `sccache --show-stats` again
- **THEN** the configured `basedirs` strip `/home/brittonr/git` from the first build path and `/home/brittonr/git/worktrees` from the second build path
- **AND** the second stats snapshot shows a higher cache-hit count than the first snapshot

### Requirement: Initial rollout preserves the shared Cargo target-dir
ID: rustcache.shared-target-compat
The initial `sccache` rollout MUST preserve `britton-desktop`'s existing shared Cargo target directory and current baseline Cargo defaults until a later change explicitly retires them.

#### Scenario: managed Cargo config replaces the manual file
ID: rustcache.shared-target-compat.managed-cargo-file
- **WHEN** home-manager activates the workstation Rust cache profile on `britton-desktop`
- **THEN** the generated Cargo config keeps `target-dir = "/home/brittonr/.cargo-target"`
- **AND** the generated Cargo config also preserves `net.retry = 3` and `term.quiet = false`

### Requirement: Cache failures fail open for local development
ID: rustcache.fail-open
The workstation Rust build environment MUST use a dedicated Cargo rustc-wrapper that invokes `sccache`, detects cache startup or transport failures, and falls back to direct compiler execution instead of aborting local builds, and `inventory/home-profiles/brittonr/sccache/README.md` MUST document the dead-UDS failure-injection method plus `/home/brittonr/.cache/sccache/error.log` inspection.

#### Scenario: local sccache server is unavailable
ID: rustcache.fail-open.server-unavailable
- **WHEN** Cargo runs through the managed rustc-wrapper and `SCCACHE_SERVER_UDS=/tmp/sccache-broken.sock` makes `sccache` hit an intentionally dead daemon transport on `britton-desktop`
- **THEN** the build exits successfully instead of failing solely because of the cache infrastructure
- **AND** the user can inspect `/home/brittonr/.cache/sccache/error.log` after the build

### Requirement: Cache behavior is observable during validation
ID: rustcache.stats
The workstation setup MUST provide a supported stats workflow, documented in `inventory/home-profiles/brittonr/sccache/README.md`, for validating cache reuse after repeated Rust builds.

#### Scenario: user inspects cache reuse after repeated builds
ID: rustcache.stats.repeated-builds
- **WHEN** the user runs `sccache --zero-stats`, `cargo build`, `cargo clean`, `cargo build`, and `sccache --show-stats` in `/home/brittonr/git/crunch/crunch`
- **THEN** the workstation reports cache request, hit, and miss counters for the active local cache
- **AND** both request count and hit count are greater than zero after the second build completes
