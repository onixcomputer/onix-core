# RustFS build caches

The fleet uses separate RustFS buckets for interactive Rust artifacts and Nix store paths.

| Cache | Runtime host | Endpoint | RustFS bucket |
|---|---|---|---|
| Kache | `aspen1`, `aspen3`, `britton-desktop` | local daemon through each node's RustFS endpoint | `onix-kache` |
| niks3 | `aspen1` | `http://100.100.103.95:39400` | `onix-niks3` on `127.0.0.1:39500` |

Kache uses Tailnet HTTP because Tailscale encrypts host traffic. niks3 uses a separate loopback-only RustFS process and data directory. Runtime principals have bucket-scoped policies. They do not have RustFS administrator authority.

## Kache

All three nodes install the managed Cargo wrapper and run `kache-rustfs.service`. Aspen1 and the desktop use `/var/cache/kache-nix/user-brittonr`. Aspen3 uses `/mnt/usb4-nvme/kache-nix/user-brittonr` to protect its root disk.

Each daemon uses its node-local RustFS endpoint. All daemons share the bucket-scoped Kache credential and `onix-kache` namespace. Only the desktop provisions the bucket and policy. Home Manager does not start a second daemon.

The long-lived daemons disable speculative prefetch. Exact remote hits and background uploads remain active without repeated whole-bucket listings.

Inspect the service:

```console
systemctl status kache-rustfs.service
KACHE_CONFIG=/etc/kache-rustfs/config.toml kache stats
```

Run an explicit synchronization:

```console
kache-rustfs-sync --dry-run
kache-rustfs-sync --push
kache-rustfs-sync --pull
```

The managed Cargo profile reads `/etc/kache-rustfs/config.toml`, which contains no credential. The system daemon alone reads the Clan secret.

The Nix-owned Kache wrapper remains local-only. Nix build sandboxes do not receive the RustFS credentials or direct remote authority.

## niks3

The server keeps reference and garbage-collection metadata in local PostgreSQL on Aspen1. NAR files, narinfo files, logs, and realisations use `rustfs-niks3-cache.service` and `/var/lib/rustfs-niks3-cache`.

All three build nodes retain crash-safe SQLite queues. Automatic post-build activation is disabled. Nix trusts the dedicated public signing key and uses the read proxy as an extra substituter.

Inspect the service and queue:

```console
ssh root@aspen1.local systemctl status niks3.service niks3.socket
systemctl status rustfs-niks3-cache.service niks3.service niks3.socket
systemctl status niks3-auto-upload.service niks3-auto-upload.socket
curl -fsS http://100.100.103.95:39400/nix-cache-info
```

## Admitted upload maintenance

A normal build does not start an uploader. To drain one node, first verify all configured guard endpoints. Then create the runtime marker and start the socket and service:

```console
install -m 0600 /dev/null /run/niks3-maintenance-window
systemctl start niks3-auto-upload.socket niks3-auto-upload.service
journalctl -fu niks3-auto-upload.service
```

Stop the service and socket before you admit another node. Remove the marker after the window:

```console
systemctl stop niks3-auto-upload.socket niks3-auto-upload.service
rm -f /run/niks3-maintenance-window
```

A missing marker or failed guard endpoint rejects service startup before queue work begins. Manual uploads require the deployed API token. Do not copy that token into shell history or the repository.

## Monitoring and recovery

Prometheus probes each RustFS, Celld, Site Celld, and niks3 health endpoint. Each build node exports `onix_niks3_upload_queue_paths` through the node-exporter textfile collector.

The desktop stores authoritative object snapshots under `/datapool/rustfs-authority-backup`. These snapshots include both Celld buckets and the dedicated niks3 metadata-backup bucket. They exclude Kache and niks3 cache objects.

Aspen1 creates a compressed PostgreSQL dump with `postgresqlBackup-niks3.service`. A successful dump uploads with a BLAKE3 sidecar to `onix-niks3-metadata-backup`.

Run bounded restore checks:

```console
systemctl start rustfs-authority-restore-probe-rustfs-cluster.service
systemctl status rustfs-authority-restore-probe-rustfs-cluster.service
```

The object probe verifies the complete snapshot manifest and restores one object through a temporary bucket. PostgreSQL restoration uses a temporary database and never changes production `niks3`.

## Failure behavior

If Kache cannot reach RustFS, compilation continues and local cache behavior remains available. If niks3 is unavailable, Nix tries other substituters and local builds. Durable SQLite queues remain available for admitted maintenance.

Harmonia remains deployed during this trial. It provides the existing Aspen1 store cache while niks3 proves durable storage and garbage collection.

## Rollback

Remove or disable `kache-remote` and `nix-cache` in `inventory/services/services.ncl`. Remove `hm-kache-fleet` from `inventory/core/users.ncl`, then deploy the affected machines. This stops new remote cache use without deleting either RustFS bucket. Keep the buckets until restore and retention tests finish.
