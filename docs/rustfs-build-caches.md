# RustFS build caches

The fleet uses separate RustFS buckets for interactive Rust artifacts and Nix store paths.

| Cache | Runtime host | Endpoint | RustFS bucket |
|---|---|---|---|
| Kache | `britton-desktop` | direct S3 through the local daemon | `onix-kache` |
| niks3 | `aspen1` | `http://100.100.103.95:39400` | `onix-niks3` |

Both RustFS endpoints use Tailnet HTTP because Tailscale encrypts host traffic. The runtime principals have bucket-scoped policies. They do not have RustFS administrator authority.

## Kache

The Cargo wrapper keeps its local store at `/var/cache/kache-nix/user-brittonr`. The `kache-rustfs.service` daemon handles remote checks and uploads with a Clan secret. Home Manager does not start a second daemon.

Inspect the service:

```console
systemctl status kache-rustfs.service
kache stats
```

Run an explicit synchronization:

```console
kache-rustfs-sync --dry-run
kache-rustfs-sync --push
kache-rustfs-sync --pull
```

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

Remove or disable `kache-remote` and `nix-cache` in `inventory/services/services.ncl`, then deploy the affected machines. This stops new remote cache use without deleting either RustFS bucket. Keep the buckets until restore and retention tests finish.
