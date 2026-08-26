# Kache fleet runtime rollout evidence

Date: 2026-08-26

## Static and build evidence

The combined Celld and Kache branch passed these checks:

- Kache package positive version and negative unsupported-command checks;
- Kache Nickel positive and negative settings fixtures;
- Kache semantic positive and negative settings tests;
- generated three-node membership, endpoint, cache-path, provisioner, credential, wrapper, and no-prefetch checks;
- existing local-only Nix sandbox checks;
- Celld settings and generated topology checks;
- complete NixOS builds for Aspen1, Aspen3, and `britton-desktop`.

The deployed package is Kache `0.16.0`. All three generated configurations set `prefetch_enabled = false`. Exact remote lookups and background uploads remain enabled.

## Deployment state

The combined closures were deployed to `britton-desktop`, Aspen3, and Aspen1. Every node reports:

- `kache-rustfs.service`: active and running;
- Kache version: `0.16.0`;
- `prefetch_enabled = false` in `/etc/kache-rustfs/config.toml`;
- active RustFS and niks3 auto-upload sockets;
- the same shared Kache credential, compared by BLAKE3 without printing its value.

Aspen1 and `britton-desktop` use `/var/cache/kache-nix/user-brittonr`. Aspen3 uses `/mnt/usb4-nvme/kache-nix/user-brittonr` with owner `brittonr:users` and mode `0700`.

## Cross-node reuse

A dependency-free Rust library with positive and empty-input boundary tests was built with one pinned Cargo and Rust compiler closure on both Aspen nodes.

Kache `0.6.0` produced different keys for identical source, compiler, arguments, and traced key fields. That version could not satisfy cross-node reuse. The package was upgraded to Kache `0.16.0` before acceptance.

An isolated Kache `0.16.0` run produced the same complete cache key on both Aspen nodes. A fresh managed build on Aspen1 then produced:

- one library miss and one test-executable miss;
- successful automatic remote uploads;
- a 481,703-byte compressed test-executable upload with `ok=true`.

After the Aspen3 package target was cleaned, the same source completed in 0.33 seconds. Kache recorded two `remote_hit` events:

- library artifact: 9,891 bytes, 209 milliseconds;
- test executable: 1,298,856 bytes, 317 milliseconds.

The corresponding remote downloads each used one request and reported `ok=true`. Both positive and boundary tests passed after restoration.

## Failure-safe evidence

Kache `0.16.0` was invoked with cache and runtime paths under read-only `/proc`. It reported that caching was disabled, invoked the real pinned Rust compiler, and produced a non-empty rlib. An unavailable cache did not change the valid compiler result.

## Authority and service health

The Kache credential listed `onix-kache` and was denied access to `onix-niks3`. It has no cross-bucket authority.

After deployment:

- all three RustFS health endpoints returned HTTP 200;
- niks3 returned HTTP 200 from `/nix-cache-info`;
- the Aspen1 lab Celld health endpoint returned HTTP 200;
- both Site Celld health endpoints and `/blog/` assets returned HTTP 200.

## Operational recovery

Large concurrent Nix builds activated durable niks3 uploads and overloaded experimental RustFS object operations. Upload workers were stopped without deleting their SQLite queues. RustFS and niks3 recovered after the workers stopped. The three socket units were restored to the active state; the socket-activated workers remained idle.

Aspen3 entered ZFS slop-space protection. Nix SQLite writes failed with no allocatable space. Intermediate system generations 51 and 52 were removed. One large automatic hourly home snapshot, `zfs-auto-snap_hourly-2026-08-25-21h00`, was destroyed after smaller cache deletion could not release snapshot-held blocks. Normal Nix garbage collection then completed, and `/nix/store` retained about 12 GiB available.

No niks3 queue, RustFS object, or application bucket was deleted.

## Non-claims

This evidence proves bounded behavior for the observed builds and probes. It does not prove compatibility across different compiler closures, unlimited RustFS load, long-duration availability, or public Internet service.

Aspen1 still has the unrelated known `radicle-ci-runner.service` missing-store-path failure.
