Evidence-ID: V5-fail-open
Task-ID: V5
Artifact-Type: verification-evidence
Covers: rustcache.fail-open.server-unavailable

## Commands

```bash
cd /home/brittonr/git/crunch/crunch
if env | grep -q '^RUSTC_WRAPPER='; then exit 1; fi
rm -f /home/brittonr/.cache/sccache/error.log
rm -rf /tmp/sccache-broken.sock
mkdir /tmp/sccache-broken.sock
SNIX_BUILD_SANDBOX_SHELL=/bin/sh nix develop -c cargo clean
SNIX_BUILD_SANDBOX_SHELL=/bin/sh \
  SCCACHE_LOG=debug \
  SCCACHE_SERVER_UDS=/tmp/sccache-broken.sock \
  nix develop -c cargo build
ls -l /home/brittonr/.cache/sccache/error.log
tail -n 40 /home/brittonr/.cache/sccache/error.log
```

## Observed Fallback

The build log repeatedly showed the managed rustc-wrapper catching the cache transport failure and falling back to direct `rustc`:

```text
sccache: error: Connection to server timed out: Os { code: 111, kind: ConnectionRefused, message: "Connection refused" }
sccache-rustc-wrapper: cache transport unavailable, falling back to rustc
```

The error log remained inspectable after the successful build:

```text
[2026-04-22T18:14:18Z INFO  sccache::server] server has setup with ReadWrite
[2026-04-22T18:14:18Z ERROR sccache::server] failed to start server: Address already in use (os error 98)
[2026-04-22T18:14:18Z DEBUG sccache::server] notify_server_startup(AddrInUse)
sccache: error: Address already in use (os error 98)
V5_PASS=1
```

## Result

PASS. With `SCCACHE_SERVER_UDS=/tmp/sccache-broken.sock`, Cargo still exited successfully through the managed rustc-wrapper, the wrapper emitted explicit fallback messages, and `/home/brittonr/.cache/sccache/error.log` remained available for inspection.
