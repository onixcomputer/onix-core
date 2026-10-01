# RustFS build caches

The fleet uses separate RustFS buckets for interactive Rust artifacts and Nix store paths.

| Cache | Runtime host | Endpoint | RustFS bucket |
|---|---|---|---|
| Kache | `aspen1`, `aspen3`, `britton-desktop` | local daemon through each node's RustFS endpoint | `onix-kache` |
| niks3 | `aspen1` | `http://100.100.103.95:39400` | `onix-niks3` on `100.100.103.95:39500` |

Kache uses Tailnet HTTP because Tailscale encrypts host traffic. niks3 uses a separate Tailnet-only RustFS process and data directory. Runtime principals have bucket-scoped policies. They do not have RustFS administrator authority.

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

Aspen1, Aspen2, Aspen3, and the desktop retain crash-safe SQLite queues. Automatic post-build activation of those queues is disabled. Nix trusts the dedicated public signing key and uses the read proxy as an extra substituter. Scheduled farm builds publish through a separate, explicitly enabled path described below.

Inspect the service and queue:

```console
ssh root@aspen1.local systemctl status niks3.service niks3.socket
systemctl status rustfs-niks3-cache.service niks3.service niks3.socket
systemctl status niks3-auto-upload.service niks3-auto-upload.socket
curl -fsS http://100.100.103.95:39400/nix-cache-info
```

## Scheduled Nix build farm

The `nix-build-farm` inventory service replaces the managed Aspen1 SSH build route with shared scheduling:

| Role | Machines | Endpoint |
|---|---|---|
| Scheduler and worker | `aspen1` | `100.100.103.95:50052`, Tailnet only |
| Worker | `aspen2` | `100.82.25.30:50052`, Tailnet only |
| Envoy ingress | `aspen1` | `aspen1.local:50051` |
| Clients | `bonsai`, `aspen3`, `britton-desktop` | ingress above |

Each worker offers 16 jobs and stops admitting work below 100 GiB free. Worker Nix daemons have no remote builders, preventing recursive dispatch. Independent SSH builders remain configured; the excluded Darwin builder is not admitted.

Clients pin `aspen1.local` to `100.100.103.95` in their generated hosts file. This preserves the certificate name while allowing off-LAN clients such as Aspen3 to reach ingress without mDNS.

Ingress and worker connections use a private CA. Workers authorize exact `ci-`, `worker-`, and `lb-` machine identities, with no anonymous or OIDC role. Envoy sanitizes forwarded client identity; although its TLS listener permits a certificate-less handshake, the worker denies unauthenticated store operations. Client keys are root-only and used by `nix-daemon`, not copied into user profiles. The CA signing key is encrypted in Clan vars and never deployed.

The plugin is pinned to `nix-grpc-store` `0.1.0-beta.4` and built against the existing Nix fork's exact libraries. `pkgs/nix-grpc-store/nix-2.36-full-inputs.patch` supports that fork's grouped derivation-input API without advancing the Nix pin. Niks3 is pinned to `1.13.0` for the scheduler lease, object-presence, and acknowledged `push --stdin` APIs.

Farm daemons automatically publish outputs before advertising cache availability. Each worker runs one concurrent push with one concurrent NAR upload and S3 integrity verification. Both workers can publish simultaneously; this is not a fleet-wide one-upload limit. The existing SQLite maintenance queues remain disabled.

### Activation order

Repository integration does not activate hosts or generate production certificates. Before deployment:

1. Back up the existing Niks3 PostgreSQL database on Aspen1 with `postgresqlBackup-niks3.service`. The server upgrade applies database migrations; do not downgrade the binary against a migrated database without a compatible restore plan.
2. Generate worker and ingress credentials. Clan generates the shared CA dependency once:

   ```console
   clan vars generate aspen1 aspen2 --generator nix-build-farm-node
   clan vars generate aspen1 --generator nix-build-farm-balancer
   ```

3. Deploy Aspen1 first, bringing up the new cache server, scheduler, worker, and ingress. Use `root@aspen1.local` for its SSH target. Confirm cache health and both `niks3.service` and `nix-grpc-daemon.service` before admitting the second worker.
4. Deploy Aspen2 and verify it registers. On Aspen1, inspect the private Envoy admin endpoint and service journals:

   ```console
   curl -fsS http://127.0.0.1:9901/clusters
   journalctl -u nix-grpc-daemon.service -u envoy.service
   ```

5. Generate client credentials, then deploy the three clients only after both workers are healthy:

   ```console
   clan vars generate bonsai aspen3 britton-desktop --generator nix-build-farm-client
   ```

Normal builds then use the configured gRPC build hook. No manual plugin flags or user-readable private keys are needed. If workstation auto-GC removes a generator script during deployment, rerun with `NIX_CONFIG=$'min-free = 0\nmax-free = 0'`.

Leaf certificates last 365 days; the CA lasts five years. Renew leaves before expiry with the corresponding `nix-build-farm-node`, `nix-build-farm-balancer`, or `nix-build-farm-client` generator and `--regenerate`, then redeploy. Credential changes restart the consuming service. CA rotation requires regenerating **all** dependent leaves and a coordinated deployment window; it is not a rolling, zero-downtime operation.

### Verification evidence

`.cairn/changes/integrate-grpc-build-farm/evidence.json` records the exact runtime, reproducible isolated smoke expression, and 21 passed four-VM scenarios. These cover scheduling, signed retrieval, cache reuse, denied access, the Nix build hook, cancellation, restart recovery, and low-disk admission. The upstream fixture also tests two-scheduler failover and OIDC; neither is enabled by this fleet configuration. Generated fleet service units, exact identity rules, maintenance gates, and certificate scripts were checked separately. This evidence is not a live deployment receipt.

Production credential preparation and rollout status are recorded separately in `.cairn/changes/integrate-grpc-build-farm/deployment-evidence.json`. Consult its activation status before assuming these services are running on live hosts.

## Admitted upload maintenance

A non-farm local build does not start a queue uploader. Farm publication is independent and does not grant permission to drain these queues. To drain one node, first verify all configured guard endpoints. Then create the runtime marker and start the socket and service:

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

If Kache cannot reach RustFS, compilation continues and local cache behavior remains available. For ordinary substitution, Nix can try other substituters and local builds when Niks3 is unavailable. Durable SQLite queues remain available for admitted maintenance.

Farm builds require acknowledged cache publication: a cache outage can delay or fail them. Aspen1 is the single scheduler, ingress, and cache-metadata failure domain; the second worker does not make this topology highly available. If the farm is unavailable, explicitly select local builds rather than assuming every in-flight remote build falls back.

Harmonia remains deployed during this trial. It provides the existing Aspen1 store cache while niks3 proves durable storage and garbage collection.

## Rollback

To roll back the farm only, remove the `nix-build-farm` instance from `inventory/services/services.ncl`, deploy clients first, then deploy both workers. This removes the gRPC route and services but preserves Niks3, its signing key, the cache objects, and maintenance queues. It does not automatically restore the retired Aspen1 SSH build route. Keep the upgraded cache server unless its database migration has a tested rollback.

To remove remote caches too, first roll back the farm, then remove or disable `kache-remote` and `nix-cache` in `inventory/services/services.ncl`. Remove `hm-kache-fleet` from `inventory/core/users.ncl`, then deploy the affected machines. This stops new remote cache use without deleting either RustFS bucket. Keep the buckets until restore and retention tests finish.
