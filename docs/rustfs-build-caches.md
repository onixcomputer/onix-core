# RustFS build caches

The fleet uses separate RustFS buckets for interactive Rust artifacts and Nix store paths.

| Cache | Runtime host | Endpoint | RustFS bucket |
|---|---|---|---|
| Kache | `aspen1`, `aspen3`, `britton-desktop` | local daemon through each node's RustFS endpoint | `onix-kache` |
| niks3 | `aspen1` | `http://100.100.103.95:39400` | `onix-niks3` |

Both RustFS endpoints use Tailnet HTTP because Tailscale encrypts host traffic. The runtime principals have bucket-scoped policies. They do not have RustFS administrator authority.

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

The server keeps reference and garbage-collection metadata in local PostgreSQL on Aspen1. NAR files, narinfo files, logs, and realisations use RustFS.

All three RustFS nodes run the crash-safe auto-upload hook. The hook receives only a shared niks3 API token. Nix trusts the dedicated public signing key and uses the read proxy as an extra substituter.

Inspect the service and queue:

```console
ssh root@aspen1.local systemctl status niks3.service niks3.socket
systemctl status niks3-auto-upload.service niks3-auto-upload.socket
curl -fsS http://100.100.103.95:39400/nix-cache-info
```

Manual uploads require the deployed API token. Do not copy that token into a shell history or the repository.

## Failure behavior

If Kache cannot reach RustFS, compilation continues and local cache behavior remains available. If niks3 is unavailable, Nix tries its other substituters and local builds. Auto-upload keeps a local SQLite queue for retries.

Harmonia remains deployed during this trial. It provides the existing Aspen1 store cache while niks3 proves durable storage and garbage collection.

## Rollback

Remove or disable `kache-remote` and `nix-cache` in `inventory/services/services.ncl`. Remove `hm-kache-fleet` from `inventory/core/users.ncl`, then deploy the affected machines. This stops new remote cache use without deleting either RustFS bucket. Keep the buckets until restore and retention tests finish.
