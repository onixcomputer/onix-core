## Context

- `hm-desktop` is the only home-manager assignment that targets `britton-desktop` directly (`inventory/core/users.ncl`), so a desktop-only rollout can avoid changing laptops and servers.
- Today `~/.cargo/config.toml` is manual and sets `target-dir = "/home/brittonr/.cargo-target"`, `net.retry = 3`, and `term.quiet = false`.
- Notes across sibling Rust repos show that the shared `~/.cargo-target` helps reuse artifacts but also causes lock contention and doc/doctest clobbering. No `sccache` config exists in this repo yet.
- Most local repos live under `/home/brittonr/git`, which matches `sccache`'s `basedirs` support for cache reuse across different absolute checkout paths.
- Current workstation disk state can support a real local cache budget: `/home/brittonr/.cargo-target` is about `31G`, and the root filesystem currently has about `539G` free.
- `sccache` improves repeated `rustc` work, but it does not cache every Rust crate shape: incremental builds, link-heavy crates, and some proc-macro cases still miss.

## Goals / Non-Goals

**Goals:**
- Make `sccache` a declarative part of the `britton-desktop` user environment.
- Keep the current shared Cargo target-dir workflow intact during the first rollout.
- Enable cache-key normalization for sibling repos and worktrees under `/home/brittonr/git`.
- Keep local development fail-open if cache infrastructure is unhealthy.
- Provide a repeatable validation flow that proves second-pass cache hits on real workstation repos.

**Non-Goals:**
- Remote cache backends, distributed compilation, or team-shared cache infrastructure.
- Changing Rust build behavior on `hm-server` or `hm-laptop` machines.
- Retiring the shared `~/.cargo-target` in the same change.
- General CI changes outside `britton-desktop` workstation usage.

## Decisions

### 1. Scope rollout through a new desktop-only profile

**Choice:** Create `inventory/home-profiles/brittonr/sccache/` and add it only to `hm-desktop` in `inventory/core/users.ncl`.

**Rationale:** `hm-desktop` already scopes user-profile changes to `britton-desktop`. Keeping `sccache` out of the shared `dev` profile limits blast radius while the rollout is validated.

**Alternative:** Put `sccache` directly in `dev`. Rejected because it would silently change Rust builds on laptops and servers.

### 2. Manage Cargo and sccache config declaratively from repo-owned data

**Choice:** The new profile will install a Nix-wrapped `sccache`, render a managed `~/.cargo/config.toml`, and render `~/.config/sccache/config` from repo-owned typed data. The generated Cargo config will preserve the current manual defaults (`target-dir`, retry, and term settings) and set `build.rustc-wrapper` to a dedicated Nix-managed `cargo-rustc-sccache-wrapper` script. That script will call the wrapped `sccache` binary, which exports `SCCACHE_IGNORE_SERVER_IO_ERROR=1` plus an explicit `SCCACHE_ERROR_LOG` path, and will fall back to direct `rustc` execution if `sccache` fails during startup or transport setup.

**Rationale:** Cargo wrapper settings and fail-open behavior need to apply everywhere Cargo runs, not just interactive shells. A dedicated rustc-wrapper matches Cargo's invocation contract, while a separately wrapped `sccache` keeps `sccache --show-stats` and other direct CLI usage working on `PATH`. Repo-owned config also removes workstation drift and keeps the current manual file reviewable.

**Alternative:** Export `RUSTC_WRAPPER` and fail-open env from shell init only. Rejected because editors, GUI launches, and non-shell activations would miss them. Pointing Cargo directly at the raw `sccache` binary plus Cargo `[env]` was also rejected after validation showed startup/connect failures still abort before upstream fail-open logic can help. Keeping the file manual was rejected because it preserves drift.

### 3. Keep the shared target-dir during phase 1

**Choice:** Preserve `target-dir = "/home/brittonr/.cargo-target"` in the managed Cargo config for the initial rollout, and add an explicit pre-link Home Manager activation step that backs up an existing manual `~/.cargo/config.toml` to `~/.cargo/config.toml.pre-sccache` before takeover.

**Rationale:** Too many local workflows, docs, and scripts still assume that path. `sccache` can improve compiler reuse immediately without forcing a cross-repo migration in the same change, and an explicit activation step avoids relying on hidden takeover behavior.

**Implementation detail:** The activation step runs before Home Manager links the managed Cargo file. If `~/.cargo/config.toml` exists and `~/.cargo/config.toml.pre-sccache` does not, it copies the manual file to the backup path. If the backup already exists, activation fails closed with a clear message instead of overwriting the only rollback artifact. Manual rollback is explicit: remove the `sccache` profile from `hm-desktop`, re-activate, and copy `~/.cargo/config.toml.pre-sccache` back to `~/.cargo/config.toml`.

**Alternative:** Retire the shared target-dir immediately and go back to per-repo `target/`. Rejected for this change because the compatibility audit spans multiple sibling repos and would turn a workstation cache rollout into a much broader migration.

### 4. Use a local disk cache with explicit workstation constants

**Choice:** Start with local-disk `sccache` only, with explicit named constants for the cache directory, cache-size budget, error-log path, and `basedirs`. The initial cache directory will be `/home/brittonr/.cache/sccache`, the initial cache-size constant will be `32 GiB`, the initial error-log path will be `/home/brittonr/.cache/sccache/error.log`, the initial `basedirs` list will be `["/home/brittonr/git", "/home/brittonr/git/worktrees"]`, and non-module typed data for the profile will live under a non-auto-imported subdirectory such as `inventory/home-profiles/brittonr/sccache/lib/`.

**Rationale:** Workstation usage does not need Redis/S3 complexity. A `32 GiB` local cache roughly matches the current `31G` shared target footprint while staying modest relative to the available free space, the two-root `basedirs` list lets `/home/brittonr/git/chaoscontrol` and `/home/brittonr/git/worktrees/chaoscontrol` normalize to the same repo-relative path, and keeping typed data out of the profile root avoids the known clan-core auto-import trap for non-module `.nix` files.

**Alternative:** Add remote or multi-level backends now. Rejected as unnecessary complexity for a single-machine rollout.

### 5. Use the default on-demand daemon with an explicit rustc-wrapper fallback

**Choice:** Let `sccache` start its local daemon on demand, but do not rely on upstream `SCCACHE_IGNORE_SERVER_IO_ERROR=1` alone for fail-open behavior. Instead, wrap the `sccache` CLI with fixed `SCCACHE_IGNORE_SERVER_IO_ERROR=1` and `SCCACHE_ERROR_LOG=/home/brittonr/.cache/sccache/error.log`, then have the dedicated Cargo rustc-wrapper detect startup/transport failures from `sccache` and `exec` the real `rustc` directly when that transport is unhealthy.

**Rationale:** Real validation with a dead `SCCACHE_SERVER_UDS` showed the documented upstream fail-open env is too late for startup/connect failures: `sccache rustc -vV` still aborts before local compilation begins. A thin Nix-managed rustc-wrapper keeps non-shell launches covered while making the fail-open contract deterministic for the negative-path validation.

**Alternative:** Add a dedicated systemd user service for `sccache`. Rejected because it adds extra moving parts without solving the initial adoption problem.

## Risks / Trade-offs

- **[Risk] Shared target-dir pain remains** → **[Mitigation]** keep this change focused on `sccache` adoption, then record whether a target-dir migration needs its own follow-up change.
- **[Risk] Existing manual Cargo config is replaced** → **[Mitigation]** capture the current file as `~/.cargo/config.toml.pre-sccache` before activation, and keep the generated file semantically equivalent to the current manual defaults plus `sccache`.
- **[Risk] Users expect every Rust compile to hit cache** → **[Mitigation]** document `sccache`'s Rust caveats up front (incremental, link-heavy crates, and some proc-macro cases still miss).
- **[Risk] Builds outside `/home/brittonr/git` miss normalization benefits** → **[Mitigation]** start with the known dominant root and adjust in a later change if validation shows another stable workspace root matters.

## Migration Plan

1. Capture the current manual Cargo defaults and ensure the activation step is ready to create `~/.cargo/config.toml.pre-sccache` before takeover.
2. Evaluate the generated home-manager outputs for `britton-desktop` before activation, including the exact Cargo env block and the exact `sccache` config constants.
3. Activate the new desktop-only profile on `britton-desktop`; the pre-link activation step creates `~/.cargo/config.toml.pre-sccache` if needed and fails closed if that backup already exists.
4. Zero `sccache` stats and run repeated builds in the named validation repos under `/home/brittonr/git`.
5. If the rollout is healthy, keep the managed profile in place and record whether a future change should retire the shared target-dir. If the rollout is unhealthy, remove the desktop profile and restore `~/.cargo/config.toml` from `~/.cargo/config.toml.pre-sccache`.

## Validation Plan

- **`rustcache.desktop-scope.non-desktop`**: verify `inventory/core/users.ncl` adds the new profile only to `hm-desktop`, and confirm `hm-server` / `hm-laptop` profile lists stay unchanged.
- **`rustcache.desktop-wrapper.cargo-build` / `rustcache.managed-config.file-ownership` / `rustcache.managed-config.profile-root-layout`**: inspect the generated `~/.cargo/config.toml` for the Nix-managed `cargo-rustc-sccache-wrapper` path, inspect the evaluated wrapped `sccache` and rustc-wrapper scripts for `SCCACHE_IGNORE_SERVER_IO_ERROR=1`, `SCCACHE_ERROR_LOG=/home/brittonr/.cache/sccache/error.log`, and explicit fallback to direct `rustc`, inspect the generated `~/.config/sccache/config`, inspect the profile tree to confirm every root-level `.nix` file is a module while helper/data `.nix` files live under `lib/` or another non-auto-imported subdirectory, then run `cargo build` in `/home/brittonr/git/crunch/crunch` and confirm `sccache --show-stats` records requests.
- **`rustcache.local-only.config-inspection` / `rustcache.workspace-basedirs.checkout-path`**: inspect `inventory/home-profiles/brittonr/sccache/README.md` and confirm it documents the `chaoscontrol` primary-checkout vs worktree flow; inspect `~/.config/sccache/config` and confirm it sets `dir = "/home/brittonr/.cache/sccache"`, `size = 32 GiB`, `basedirs = ["/home/brittonr/git", "/home/brittonr/git/worktrees"]`, and no remote/distributed backend sections; then zero stats, build `/home/brittonr/git/chaoscontrol`, run `cargo clean` in `/home/brittonr/git/worktrees/chaoscontrol` so the shared target-dir still forces rustc work through `sccache`, build the worktree at the same revision, and confirm the later stats snapshot reports cache hits.
- **`rustcache.shared-target-compat.managed-cargo-file`**: inspect the activated Cargo file and confirm it still contains `target-dir = "/home/brittonr/.cargo-target"`, `net.retry = 3`, and `term.quiet = false`.
- **`rustcache.managed-config.first-activation`**: activate on a machine with an existing manual `~/.cargo/config.toml`, confirm the pre-link activation step creates `~/.cargo/config.toml.pre-sccache`, confirm activation fails closed if that backup already exists, then remove the `sccache` profile, re-activate, and confirm copying `~/.cargo/config.toml.pre-sccache` back to `~/.cargo/config.toml` restores the prior manual file.
- **`rustcache.fail-open.server-unavailable`**: inspect `inventory/home-profiles/brittonr/sccache/README.md` and confirm it documents the dead-UDS injection flow plus `/home/brittonr/.cache/sccache/error.log`; then run a negative-path `cargo build` in `/home/brittonr/git/crunch/crunch` with `SCCACHE_SERVER_UDS=/tmp/sccache-broken.sock`, and confirm the managed rustc-wrapper falls back to direct `rustc` while `/home/brittonr/.cache/sccache/error.log` remains inspectable.
- **`rustcache.stats.repeated-builds`**: confirm `inventory/home-profiles/brittonr/sccache/README.md` documents `sccache --zero-stats`, `cargo clean`, `sccache --show-stats`, and `/home/brittonr/.cache/sccache/error.log`, then run `sccache --zero-stats; cargo build; cargo clean; cargo build; sccache --show-stats` in `/home/brittonr/git/crunch/crunch`, and confirm both request count and hit count are greater than zero after the second build.

## Open Questions

- After real stats and path-audit results are in, does the shared `~/.cargo-target` deserve a dedicated follow-up retirement change?
