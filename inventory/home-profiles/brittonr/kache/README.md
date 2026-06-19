# kache desktop pilot

This profile makes Home Manager the source of truth for `~/.cargo/config.toml`
and `~/.config/kache/config.toml` on `britton-desktop` while piloting kache as
Cargo's `rustc-wrapper`.

Cargo uses a managed `cargo-rustc-kache-wrapper` automatically. No manual
`RUSTC_WRAPPER` export and no `kache init` run are needed.

## Managed defaults

- Cargo target dir stays on `/home/brittonr/.cargo-target`
- Cargo defaults to `build.jobs = 20` on `britton-desktop`
- Cargo keeps `net.retry = 3`
- Cargo keeps `term.quiet = false`
- kache uses only the local disk cache at `/home/brittonr/.cache/kache`
- kache caps the local disk cache at 32 GiB
- kache runs with `KACHE_LOCAL_ONLY=1`; S3 and planner config stay disabled
- The wrapper derives `KACHE_KEY_SALT` from the active `rustc`, `cc`, and
  `mold` store paths, then appends any user-supplied `KACHE_KEY_SALT`
- Cargo defaults `target.x86_64-unknown-linux-gnu.linker = "cc"`
- Cargo adds `-fuse-ld=mold` via target-specific rustflags so the compiler
  driver selects mold as the backend linker
- `mold` is installed in the managed user environment and is also available to
  the wrapper process

## First activation and rollback

First managed activation copies an existing manual `~/.cargo/config.toml` to
`~/.cargo/config.toml.pre-kache` before Home Manager takes over. If that backup
already exists, activation fails closed.

Manual rollback path:

1. Replace the `kache` profile with the previous `sccache` profile in
   `inventory/core/users.ncl`
2. Re-activate Home Manager
3. If needed, copy `~/.cargo/config.toml.pre-kache` back to
   `~/.cargo/config.toml`

Do not run `kache init`; it edits user files that this profile manages.

## Validation flows

### Smoke check wrapper wiring

```bash
cargo build --help >/dev/null
kache doctor
```

`kache doctor` should report the managed wrapper/config and local cache path.

### Repeated clean build stats

```bash
cd /home/brittonr/git/chaoscontrol
kache purge
cargo build
cargo clean
cargo build
kache stats
```

The second build should show local cache activity. Treat the numbers as a pilot
signal, not a guarantee that normal edit/build loops improve: kache disables
Rust incremental compilation while it wraps rustc.

### Temporary bypass

```bash
KACHE_DISABLED=1 cargo build
```

This leaves the managed wrapper in place but makes kache pass through to
`rustc`.
