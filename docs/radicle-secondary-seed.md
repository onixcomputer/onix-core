# Radicle secondary seed operations

`britton-desktop` runs the native-only secondary seed for the governed Bounded Exec pilot. Aspen1 remains the primary native seed and the only public read-only HTTPS Git origin.

## Accepted identity and policy

| Fact | Accepted value |
|---|---|
| RID | `rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo` |
| Commit | `29dac88ecded94457572db3fdfaaaab95fa91525` |
| Node ID | `z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG` |
| Fingerprint | `SHA256:JHQTPqoMr4kLqBsrAPSRNXUuzETiHAoiKBM/VWftmEg` |
| Native address | `100.110.43.11:8776` on `tailscale0` |
| State | `datapool/radicle-seed` mounted at `/var/lib/radicle` |
| Quota | 64 GiB |
| Signed refs | minimum feature `parent` |
| Receipt | `evidence/radicle/secondary-seed-v1.json` |

The service has no HTTP, public ingress, delegate, CI, deployment, release, canonical-ref, cache-write, artifact, backup, or signing authority.

## Health check

Use the pinned tailnet address and strict host-key checking:

```bash
ssh -o StrictHostKeyChecking=yes root@100.110.43.11 '
  systemctl is-active radicle-node.service radicle-policy-reconcile.timer
  systemctl show radicle-replica-identity-verify.service \
    -p Result -p ExecMainStatus -p CapabilityBoundingSet \
    -p PrivateNetwork -p ProtectHome -p NoNewPrivileges
  ss -H -ltn "sport = :8776"
  zfs get quota,recordsize,used,available datapool/radicle-seed
'
```

Expected boundaries:

- node and policy timer are active;
- the last verifier result is successful;
- the verifier and node capability bounding sets are empty;
- the listener is exactly `100.110.43.11:8776`;
- no `radicle-httpd.service` exists;
- the dataset quota remains 64 GiB.

## Inspect the exact object

Root Git requires a one-command safe-directory override because the repository belongs to the `radicle` service user:

```bash
ssh -o StrictHostKeyChecking=yes root@100.110.43.11 '
  repository=/var/lib/radicle/storage/z2CpqLFpdP36fZXYUK5ZNWxMibpCo
  git -c safe.directory="$repository" -C "$repository" rev-parse refs/heads/main
  git -c safe.directory="$repository" -C "$repository" \
    cat-file -t 29dac88ecded94457572db3fdfaaaab95fa91525
'
```

Expected output is the accepted commit followed by `commit`.

The seeding database is authoritative only through `radicle-policy-reconcile.service`. Do not run `rad seed` under root's default profile. To inspect the policy, use a temporary least-authority query profile or inspect the reconciler journal:

```bash
ssh -o StrictHostKeyChecking=yes root@100.110.43.11 \
  'journalctl -u radicle-policy-reconcile.service --since today --no-pager'
```

Expected steady state is `removed=0, added=0, desired=1`.

## Restart

```bash
ssh -o StrictHostKeyChecking=yes root@100.110.43.11 '
  systemctl restart radicle-node.service
  systemctl start radicle-policy-reconcile.service
  systemctl is-active radicle-node.service radicle-policy-reconcile.timer
'
```

Every observed node start must be preceded by a successful `radicle-replica-identity-verify.service` run. A fingerprint or private/public mismatch must leave the node inactive; never bypass the verifier.

## Deploy

From the `onix-core` repository:

```bash
NIX_CONFIG=$'min-free = 0\nmax-free = 0' \
  nix develop -c clan machines update britton-desktop \
    --target-host root@100.110.43.11 \
    --host-key-check strict
```

Build the focused check and machine closure before deployment:

```bash
nix build .#checks.x86_64-linux.radicle-seed-replica -L --no-link
nix build .#nixosConfigurations.britton-desktop.config.system.build.toplevel -L --no-link
```

If the key generator has intentionally changed, regenerate only the reviewed machine generator, then update and review the pinned public fingerprint before deployment. Never copy an operator or delegate profile into the service.

## Outage drill safeguards

A valid independent-seed drill must:

1. stop transient operator nodes;
2. stop Aspen1's native node and verify it inactive;
3. run a fresh client with egress allowed only to `100.110.43.11/32`;
4. block the client from `/var/lib/radicle`, `/run/secrets`, and user homes;
5. require signed-reference feature `parent`;
6. verify the exact commit and source-archive BLAKE3;
7. reject an undeclared RID and missing object;
8. restore Aspen1 in a trap, then verify its node and policy timer active.

A normal `rad clone --seed` is insufficient because peer discovery can silently fall back to public seeds and mutate the client's local seeding policy.

## Recovery boundary

The replica key is encrypted in Clan per-machine variables. Repository state is disposable replication state and can be rebuilt from the accepted primary repository. Aspen1's full encrypted recovery exercise remains the stack's destructive restore evidence; no destructive restore of this secondary dataset has been claimed.

The desktop also hosts Aspen1's encrypted Borg target, but that backup authority is not mounted or credentialed into the Radicle replica services.

## Non-claims

Two native seeds do not establish a second public HTTPS origin, automatic HTTPS failover, geographic/building-power independence, host-root isolation, private confidentiality, source correctness, CI correctness, canonical-ref enforcement by seeds, or release readiness.
