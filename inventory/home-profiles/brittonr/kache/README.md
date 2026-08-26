# Kache fleet profile

This profile makes Home Manager the source of truth for `~/.cargo/config.toml`
on Aspen1, Aspen3, and `britton-desktop`. It configures Kache as Cargo's
`rustc-wrapper` and reads machine policy from `/etc/kache-rustfs/config.toml`.

Cargo uses a managed `cargo-rustc-kache-wrapper` automatically. The NixOS
`kache-rustfs.service` owns the daemon and its private RustFS credentials. No
manual `RUSTC_WRAPPER` export and no `kache init` run are needed.

## Managed defaults

- Cargo target dir stays on `/home/brittonr/.cargo-target`
- Cargo defaults to `build.jobs = 20` on all three nodes
- Cargo keeps `net.retry = 3`
- Cargo keeps `term.quiet = false`
- Aspen1 and the desktop use `/var/cache/kache-nix/user-brittonr`
- Aspen3 uses `/mnt/usb4-nvme/kache-nix/user-brittonr`
- each node caps its local disk cache at 32 GiB
- kache uses the dedicated `onix-kache` RustFS bucket through the local daemon
- kache's daemon runs as the declarative NixOS service `kache-rustfs.service`
- Home Manager does not start a second user daemon
- kache's daemon idle timeout is disabled so systemd remains the lifecycle owner
- The wrapper derives `KACHE_KEY_SALT` from the active `rustc`, `cc`, and
  `mold` store paths, then appends any user-supplied `KACHE_KEY_SALT`
- Cargo defaults `target.x86_64-unknown-linux-gnu.linker = "cc"`
- Cargo adds `-fuse-ld=mold` via target-specific rustflags so the compiler
  driver selects mold as the backend linker
- the compiler driver and `mold` are installed in the managed user environment
  and are also available to the wrapper process
- Cargo tools that set `RUSTC_WORKSPACE_WRAPPER` (for example cargo-octet's
  Dylint driver) bypass kache automatically and execute the workspace wrapper
  directly; kache 0.6.0 only recognizes rustc-shaped argv in wrapper mode

## First activation and rollback

First managed activation copies an existing manual `~/.cargo/config.toml` to
`~/.cargo/config.toml.pre-kache` before Home Manager takes over. If that backup
already exists, activation fails closed.

Manual rollback path:

1. Remove or narrow the `hm-kache-fleet` assignment in `inventory/core/users.ncl`
2. Add the `sccache` profile where the previous wrapper is required
3. Re-activate Home Manager
4. If needed, copy `~/.cargo/config.toml.pre-kache` back to
   `~/.cargo/config.toml`

Do not run `kache init`; it edits user files that this profile manages.

## Validation flows

### Smoke check wrapper wiring

```bash
cargo build --help >/dev/null
kache doctor
```

`kache doctor` should report the managed wrapper, config, local cache path, and S3 remote. Use `kache-rustfs-sync --dry-run` to test remote authority.

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
`rustc`. Tools that install their own Cargo workspace wrapper should not need
this setting; the managed wrapper passes those chains through before invoking
kache.
