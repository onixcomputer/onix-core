# Aspen3 live Radicle seed evidence — 2026-07-31

<!--
r[verify onix.radicle_private_pilot.admission]
r[verify onix.radicle_private_pilot.admission.scenario.fail_closed]
r[verify onix.radicle_private_pilot.publication]
r[verify onix.radicle_private_pilot.publication.scenario.private]
r[verify onix.radicle_private_pilot.replication]
r[verify onix.radicle_private_pilot.replication.scenario.exact]
r[verify onix.radicle_replica.configuration]
r[verify onix.radicle_replica.configuration.accepted]
r[verify onix.radicle_replica.configuration.rejected]
r[verify onix.radicle_replica.deployment]
r[verify onix.radicle_replica.deployment.identity]
r[verify onix.radicle_replica.evidence]
r[verify onix.radicle_replica.evidence.accepted]
r[verify onix.radicle_replica.identity_distinct]
r[verify onix.radicle_replica.identity_distinct.production]
r[verify onix.radicle_replica.validation]
r[verify onix.radicle_replica.validation.focused]
-->

## Accepted deployment

- Managed host: `aspen3`
- Deployment target: `root@aspen3`, with strict host-key checking
- Failure domain: `aspen3-mobile-workstation`
- Tailnet address: `100.108.13.4`
- System closure: `/nix/store/c4igmld2jjsix9235kpnfgr1fcg24xqc-nixos-system-aspen3-26.11.20260629.7a1a647`
- Node ID: `z6MkoHdimfedLwXjNZhxfAadc8H3rW2TMjpn7ATMNcRWieWh`
- Public fingerprint: `SHA256:TEuGqHuV/3kGZzGiqUGCkCYG8ITfhV3TvJUjddv8fb0`

The focused replica check and the full `aspen3` closure build passed before the final deployment. Clan generated a new encrypted machine key. The public fingerprint was pinned before activation.

## Storage and policy

`zroot/radicle-seed` is mounted at `/var/lib/radicle`. The dataset has quota `64G`, record size `128K`, and observed use `5.70M`.

The policy reconciler reported:

```text
reconciled Radicle seeding policy: removed=0, added=0, desired=5
```

The exact stored RID set is:

```text
z2CpqLFpdP36fZXYUK5ZNWxMibpCo
z2oYsb9jGTyp68BKYhzpivY1eK58a
z3t9ykR1HfG9UkyKoQQg5ikkzrTxg
z4JGYYW7WsesXUq7MXVdx16Fawu2f
zL2ncTUeASVYwcoGkEXv9JKgGbAF
```

The four public repositories synchronized from `britton-desktop`. A direct Aspen1 transfer completed on Aspen1 after the client handshake timeout, so that attempt was not accepted.

## Private pilot identity update

The sole delegate accepted private identity revision `cb3f6273f35ff437e58f15332d48f25b06c4b9cc`. The revision adds only the new `aspen3` DID.

Current private facts:

- identity revision: `cb3f6273f35ff437e58f15332d48f25b06c4b9cc`
- identity JSON BLAKE3: `f1794d2561882dd471541c2b4aff7392a12a3c08de81d974ace2e15009e1f2ab`
- delegate signed refs: `ad1b6d032b69a4b81910b2fc98f8707b9ff268fb`
- canonical commit: `ff4ff027817465b1bb04251a8a98db42cc610b0c`
- new allowed DID: `did:key:z6MkoHdimfedLwXjNZhxfAadc8H3rW2TMjpn7ATMNcRWieWh`

Aspen1, `britton-desktop`, and `aspen3` contain the same identity revision and delegate signed refs. The denied client DID remains absent.

The updated backup verifier is deployed in Aspen1 closure `/nix/store/bffp1ljwgh9h2gblfp45ww9jk25wc5z4-nixos-system-aspen1-26.11.20260629.7a1a647`. Its backup timer is active.

## Network and authority boundary

The node listens at only `100.108.13.4:8776`. The firewall rule is attached to `tailscale0`.

`radicle-httpd.service` has load state `not-found`. The node and verifier capability sets are empty. Both units protect home directories and deny privilege escalation.

The verifier has no network. It checks the key pair and pinned fingerprint before each managed node start.

The service receives only its machine-scoped node key and repository state. It receives no delegate, CI, deployment, release, canonical-ref, cache, artifact, backup, Cloudflare, GitHub, or signing authority.

Prometheus and the systemd exporter are active. Metrics for `radicle-node.service` and `radicle-policy-reconcile.service` are present.

## Restart and failure recovery

A manual restart changed the node PID, reran the verifier, preserved all five repositories, and restored the exact listener.

A negative drill sent `SIGKILL` to the node. `Restart=no` blocked the internal systemd restart path. Starting the policy service created a new transaction, reran the verifier, restored the node, and preserved all five repositories.

## Validation

These checks passed:

```text
checks.x86_64-linux.radicle-seed-replica
checks.x86_64-linux.radicle-node-policy
nixosConfigurations.aspen3.config.system.build.toplevel
```

Cairn proposal, design, task, and repository validation gates also passed before implementation. Final Cairn validation runs after documentation and task closure.

## Non-claims

This evidence does not prove another public HTTPS origin, automatic failover, geographic independence, or building-power independence.

It does not prove host-root isolation, production-secret confidentiality, global metadata secrecy, source correctness, CI correctness, or release readiness.

The new private-seed observation proves authorized storage and identity convergence. It does not claim a new isolated-client confidentiality drill against `aspen3`.
