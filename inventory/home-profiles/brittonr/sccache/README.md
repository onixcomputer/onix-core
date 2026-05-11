# sccache desktop rollout

This profile makes Home Manager the source of truth for `~/.cargo/config.toml`
and `~/.config/sccache/config` on `britton-desktop`.

Cargo uses a managed `cargo-rustc-sccache-wrapper` automatically, and that
wrapper calls a wrapped `sccache` binary on `PATH`. No manual
`RUSTC_WRAPPER` export is needed.

## Managed defaults

- Cargo target dir stays on `/home/brittonr/.cargo-target`
- Cargo defaults to `build.jobs = 20` on `britton-desktop`. This leaves 12 of the workstation's 32 hardware threads for the compositor, editor, language servers, and background services while still giving direct Rust builds substantial parallelism.
- Cargo keeps `net.retry = 3`
- Cargo keeps `term.quiet = false`
- `sccache` uses only the local disk cache at `/home/brittonr/.cache/sccache`
- `sccache` caps the local disk cache at 32 GiB
- `sccache` logs errors to `/home/brittonr/.cache/sccache/error.log`
- Path normalization uses `/home/brittonr/git` and `/home/brittonr/git/worktrees`
- Cargo defaults `target.x86_64-unknown-linux-gnu.linker = "cc"`
- Cargo adds `-fuse-ld=mold` via target-specific rustflags so the compiler driver selects mold as the backend linker
- `mold` is installed in the managed user environment so the compiler driver can resolve it
- Cargo fail-open is handled by the managed rustc-wrapper, which falls back to
  direct `rustc` if `sccache` cannot start or connect to its daemon

## First activation and rollback

First managed activation copies an existing manual `~/.cargo/config.toml` to
`~/.cargo/config.toml.pre-sccache` before Home Manager takes over. If that
backup already exists, activation fails closed.

Manual rollback path:

1. Remove the `sccache` profile from `hm-desktop`
2. Re-activate Home Manager
3. Copy `~/.cargo/config.toml.pre-sccache` back to `~/.cargo/config.toml`

## Heavy local builds

Default direct Cargo builds are intentionally bounded by `build.jobs = 20`.
For intentionally heavy/off-hours local builds, run the build in an explicit
systemd scope instead of removing the managed default:

```bash
systemd-run --user --scope \
  -p CPUWeight=50 \
  -p IOWeight=50 \
  -p Nice=10 \
  -E CARGO_BUILD_JOBS=32 \
  cargo build --release
```

That workflow keeps the managed `~/.cargo/config.toml`, rustc-wrapper,
sccache, shared target dir, and mold flags intact while making the higher job
count visible and resource-scoped. Use a lower `CARGO_BUILD_JOBS` value if the
session becomes interactive again; prefer remote-builder-only Nix workflows for
large Nix builds.

## Storage inspection and cleanup policy

The current desktop policy is a 32 GiB local sccache budget plus the shared
Cargo target directory at `/home/brittonr/.cargo-target`. The shared target dir
is observable but not quota-enforced in this change; dataset/quota migration is
deferred to a future storage change if growth becomes a problem.

Inspect usage with:

```bash
sccache --show-stats
sccache --show-stats | grep -E 'Cache size|Max cache size'
du -sh /home/brittonr/.cache/sccache /home/brittonr/.cargo-target
```

Clean only when necessary:

```bash
sccache --zero-stats      # reset counters only; does not reclaim disk
sccache --stop-server     # flush/stop daemon before manual cache maintenance
cargo clean               # run per-project when a workspace target dir is stale
```

Do not delete `/home/brittonr/.cargo-target` casually; it is intentionally
shared across checkouts and worktrees to preserve incremental build reuse.

## Rust cache caveats

`sccache` does not turn every Rust compile into a cache hit.

- Incremental workspace builds still miss
- Link-heavy crates still miss even with a faster linker; using mold through `cc -fuse-ld=mold` cuts link time, not cache misses
- Some `proc-macro` cases still miss

Treat the stats flows below as health checks, not a promise that every build
phase will be cached.

## Validation flows

### chaoscontrol primary checkout vs worktree reuse

```bash
cd /home/brittonr/git/chaoscontrol
sccache --zero-stats
cargo build
sccache --show-stats

cd /home/brittonr/git/worktrees/chaoscontrol
cargo clean
cargo build
sccache --show-stats
```

`cargo clean` in the worktree forces fresh `rustc` work even though both
checkouts still share `/home/brittonr/.cargo-target`. Second stats snapshot
should show more cache hits than first one.

### crunch repeated-build stats

```bash
cd /home/brittonr/git/crunch/crunch
sccache --zero-stats
SNIX_BUILD_SANDBOX_SHELL=/bin/sh nix develop -c cargo build
SNIX_BUILD_SANDBOX_SHELL=/bin/sh nix develop -c cargo clean
SNIX_BUILD_SANDBOX_SHELL=/bin/sh nix develop -c cargo build
sccache --show-stats
```

`cargo clean` between the two builds forces the second pass back through
`rustc`, which makes the `sccache` hit count observable even though the
workspace still shares `/home/brittonr/.cargo-target`.

After second build, request count and hit count should both be greater than
zero.

### crunch fail-open with dead UDS

```bash
cd /home/brittonr/git/crunch/crunch
SNIX_BUILD_SANDBOX_SHELL=/bin/sh \
  SCCACHE_SERVER_UDS=/tmp/sccache-broken.sock \
  nix develop -c cargo build
```

Build should still succeed because the managed rustc-wrapper falls back to
plain `rustc` when the wrapped `sccache` cannot use the dead daemon transport.
Inspect errors with:

```bash
tail -n 100 /home/brittonr/.cache/sccache/error.log
```
