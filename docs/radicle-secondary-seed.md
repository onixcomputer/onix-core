# Radicle replica operations

Aspen1 is the primary native seed and the only public HTTPS Git origin. Two native-only replicas run on `britton-desktop` and `aspen3`.

All three nodes seed these exact repository sets:

- four governed public RIDs
- one non-secret private pilot RID

The replicas have no HTTP, public ingress, delegate, CI, deployment, release, canonical-ref, cache-write, artifact, backup, or signing authority.

## Accepted replica identities

| Fact | `britton-desktop` | `aspen3` |
|---|---|---|
| Node ID | `z6MkkQCj5EczNiVzDzCkX9ewHNJ7NDEXSKbuRiS1x7o72yeG` | `z6MkoHdimfedLwXjNZhxfAadc8H3rW2TMjpn7ATMNcRWieWh` |
| Fingerprint | `SHA256:JHQTPqoMr4kLqBsrAPSRNXUuzETiHAoiKBM/VWftmEg` | `SHA256:TEuGqHuV/3kGZzGiqUGCkCYG8ITfhV3TvJUjddv8fb0` |
| Native address | `100.110.43.11:8776` | `100.108.13.4:8776` |
| Interface | `tailscale0` | `tailscale0` |
| Dataset | `datapool/radicle-seed` | `zroot/radicle-seed` |
| State path | `/var/lib/radicle` | `/var/lib/radicle` |
| Quota | `64G` | `64G` |
| Failure domain | `britton-desktop-workstation` | `aspen3-mobile-workstation` |

The original desktop acceptance receipt remains at `evidence/radicle/secondary-seed-v1.json`.

## Health checks

Check the desktop replica:

```bash
ssh -o StrictHostKeyChecking=yes root@100.110.43.11 '
  systemctl is-active radicle-node.service radicle-policy-reconcile.timer
  ss -H -ltn "sport = :8776"
  zfs get quota,recordsize,used,available datapool/radicle-seed
'
```

Check the `aspen3` replica:

```bash
ssh -o StrictHostKeyChecking=yes root@aspen3 '
  systemctl is-active radicle-node.service radicle-policy-reconcile.timer
  systemctl show radicle-replica-identity-verify.service \
    -p Result -p ExecMainStatus -p CapabilityBoundingSet \
    -p PrivateNetwork -p ProtectHome -p NoNewPrivileges
  systemctl show radicle-node.service -p Restart -p CapabilityBoundingSet
  ss -H -ltn "sport = :8776"
  zfs get quota,recordsize,used,available zroot/radicle-seed
'
```

Accept these results:

1. The node and policy timer are active.
2. The verifier result is successful.
3. The capability sets are empty.
4. The listener uses only the reviewed tailnet address.
5. `radicle-httpd.service` has load state `not-found`.

The replica node uses `Restart=no`. The persistent policy timer starts a failed node through a new identity-verification transaction.

## Policy and storage

Start policy reconciliation after an admission change:

```bash
ssh -o StrictHostKeyChecking=yes root@aspen3 \
  'systemctl start radicle-policy-reconcile.service && journalctl -u radicle-policy-reconcile.service -n 20 --no-pager'
```

The steady-state result is `removed=0, added=0, desired=5`.

List the exact storage set:

```bash
ssh -o StrictHostKeyChecking=yes root@aspen3 \
  'find /var/lib/radicle/storage -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort'
```

Expected RIDs:

```text
z2CpqLFpdP36fZXYUK5ZNWxMibpCo
z2oYsb9jGTyp68BKYhzpivY1eK58a
z3t9ykR1HfG9UkyKoQQg5ikkzrTxg
z4JGYYW7WsesXUq7MXVdx16Fawu2f
zL2ncTUeASVYwcoGkEXv9JKgGbAF
```

Do not run `rad seed` under the root profile. The policy reconciler owns the seeding database.

## Restart

Restart a replica through systemd:

```bash
ssh -o StrictHostKeyChecking=yes root@aspen3 '
  systemctl restart radicle-node.service
  systemctl start radicle-policy-reconcile.service
  systemctl is-active radicle-node.service radicle-policy-reconcile.timer
'
```

A successful restart reruns `radicle-replica-identity-verify.service`. A fingerprint or key-pair mismatch keeps the node inactive.

## Deploy

Build the focused check and the target closure:

```bash
nix build .#checks.x86_64-linux.radicle-seed-replica -L --no-link
nix build .#nixosConfigurations.aspen3.config.system.build.toplevel -L --no-link
```

Deploy `aspen3`:

```bash
NIX_CONFIG=$'min-free = 0\nmax-free = 0' \
  nix develop -c clan machines update aspen3 \
    --target-host root@aspen3 \
    --host-key-check strict
```

If a replica key changes, regenerate only that machine generator. Then pin and review the new public fingerprint before deployment.

## Recovery boundary

Clan encrypts each replica key as a per-machine variable. Repository state is disposable replication state and can be rebuilt from another accepted seed.

The Aspen1 stack retains encrypted backup and destructive-restore evidence. Replica services receive no backup credentials or backup mounts.

## Non-claims

Three native seeds do not establish another public HTTPS origin, automatic failover, geographic independence, or building-power independence.

This deployment also does not prove host-root isolation, private-secret safety, global metadata secrecy, source correctness, CI correctness, or release readiness.
