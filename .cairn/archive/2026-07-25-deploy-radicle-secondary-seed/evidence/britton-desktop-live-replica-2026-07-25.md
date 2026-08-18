# Britton desktop live Radicle replica — 2026-07-25

## Accepted deployment

- Managed host: `britton-desktop`
- Pinned deployment target: `root@100.110.43.11`, strict host-key checking
- Failure domain: `britton-desktop-workstation`
- Primary failure domain: `aspen-primary-site`
- Accepted system closure: `/nix/store/p6p9sm4c1ghfwczcyzykvbzsb8q6kg3b-nixos-system-britton-desktop-26.11.20260629.7a1a647`
- Policy revision: `3855bd216beb12c910a4c5e7c5920d4de34ea06e`
- OnixOS acceptance revision: `39aba12`
- Replica receipt BLAKE3: `c53a296c5bd277ba032ffa35574634690c9a9debc76eaa68fa51cdd77a527e24`

The focused `radicle-seed-replica` check and the full `britton-desktop` NixOS build passed before the accepted deployment. Clan generated a distinct machine-scoped key as encrypted per-machine state; the public fingerprint was pinned before activation.

## Identity and storage

- Node ID: `z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG`
- Public fingerprint: `SHA256:JHQTPqoMr4kLqBsrAPSRNXUuzETiHAoiKBM/VWftmEg`
- Aspen1 node ID: `z6MkfpHAyrqSqhpiSGayy6AjB6L5UWkKLvsZvLh5hYD7XSu8`
- Aspen1 fingerprint: `SHA256:zwNJTV2uBfWYcFXeFJs+eAfatqahgK8KKe+4gdGkOSE`
- State dataset: `datapool/radicle-seed`
- Mount: `/var/lib/radicle`
- Quota: 64 GiB (`68719476736` bytes)
- Record size: 128 KiB (`131072` bytes)

The pre-existing 52-record, 137,204-byte state directory was migrated into the dedicated dataset with numeric IDs, modes, ACLs, xattrs, hard links, symlinks, and checksum comparison enabled. Source and target both contained 52 records before activation. The root-filesystem migration copy was removed only after the final service, repository, restart, and outage probes passed.

`radicle-replica-identity-verify.service` derives the public key from the systemd credential, compares it with the declared public half, checks the pinned SHA-256 fingerprint, has no network, and has an empty capability bounding set. It completed before every observed node start and ran again during restart testing.

## Selective repository policy

The authoritative reconciler reported:

```text
reconciled Radicle seeding policy: removed=0, added=1, desired=1
reconciled Radicle seeding policy: removed=0, added=0, desired=1
```

A service-profile query returned exactly:

```text
rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo  bounded-exec  allow  all
```

The stored canonical branch and object resolved to:

```text
main_commit=29dac88ecded94457572db3fdfaaaab95fa91525
object_type=commit
```

The node listens only at `100.110.43.11:8776`; its Radicle firewall opening is attached to `tailscale0`. `radicle-httpd`, Radicle HTTPS, Cloudflare, ACME, and public ingress are absent from this replica.

## Restart and authority boundary

Restart testing changed the node PID, reran identity verification, preserved the exact commit, restored the listener, and left the node and policy timer active/enabled.

The node unit has one credential: its machine-scoped Radicle private key. Its capability bounding set is empty, home and the host secret tree are inaccessible, and the live process environment contains no delegate, recovery delegate, CI, deployment, release, canonical-ref, cache-write, artifact, backup, Cloudflare, GitHub, or signing authority. The verifier is also local-only and capability-free.

Prometheus and the systemd exporter are active. Metrics for `radicle-node.service` and `radicle-policy-reconcile.service` are present.

## Final Aspen1-off acquisition drill

Before the accepted drill:

1. The transient operator node was stopped.
2. Aspen1's native `radicle-node.service` was stopped and observed inactive.
3. A fresh systemd `DynamicUser` client was allowed egress only to `100.110.43.11/32`.
4. Desktop seed storage, `/run/secrets`, user homes, Aspen1, and public-network fallback were inaccessible.
5. The client used signed-reference feature level `parent`.

Accepted result:

```text
probe_storage_access=blocked
probe_secret_access=blocked
public_egress=blocked
aspen_egress=blocked
desktop_native_known_commit=29dac88ecded94457572db3fdfaaaab95fa91525
desktop_native_source_blake3=4fbbf8f0749262469f00748e04c775180488dba800303f139172656d25931927
desktop_native_missing_object=rejected
desktop_native_undeclared_rid=rejected
```

Aspen1 was restored in a trap and then observed active with its policy timer, listener, and exact pilot branch intact. This proves two persistent selective native seeds in different machine/storage failure domains under the declared policy. It does not prove geographic, building-power, or operator-administration independence.

## HTTPS negative completion

The canonical public HTTPS branch still resolved to `29dac88ecded94457572db3fdfaaaab95fa91525`. Fetching absent object `1111111111111111111111111111111111111111` failed closed with HTTP 500 from the Git backend; no object was returned. Unknown RID and write/API/root routes remain covered by the accepted bootstrap receipt's 404 probes.

## Safe failures retained

Two unsafe intermediate states failed before acceptance:

- Running the identity verifier inside the node's chroot rejected startup. Verification was moved into a separate no-network prerequisite service rather than bypassed.
- An empty Nix list omitted systemd's `CapabilityBoundingSet=` directive for the verifier. Live inspection found the default full set; the pure service core, positive check, and deployed unit were corrected to produce an empty set before the final outage drill.

Neither intermediate state is part of the accepted receipt.

## Non-claims

This evidence does not claim a second public HTTPS origin, automatic HTTPS failover, geographic/building-power independence, host-root isolation, private-repository confidentiality, a destructive restore of the secondary seed, source or patch-review correctness, CI correctness, seed-enforced canonical refs, release readiness, or whole-stack GitHub independence.
