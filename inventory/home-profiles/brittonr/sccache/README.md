# sccache desktop rollout

This profile makes Home Manager the source of truth for `~/.cargo/config.toml`
and `~/.config/sccache/config` on `britton-desktop`.

Cargo uses a managed `cargo-rustc-sccache-wrapper` automatically, and that
wrapper calls a wrapped `sccache` binary on `PATH`. No manual
`RUSTC_WRAPPER` export is needed.

## Managed defaults

- Cargo target dir stays on `/home/brittonr/.cargo-target`
- Cargo keeps `net.retry = 3`
- Cargo keeps `term.quiet = false`
- `sccache` uses only the local disk cache at `/home/brittonr/.cache/sccache`
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
