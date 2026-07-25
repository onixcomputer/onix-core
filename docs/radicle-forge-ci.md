# Aspen1 Radicle forge CI

## Scope

Aspen1 runs a dedicated non-delegate Radicle bot and a separate credentialless
runner for only `rad:z2CpqLFpdP36fZXYUK5ZNWxMibpCo`.

The portable OnixOS policy is pinned by BLAKE3
`091e57f4409f79db14465ccc26e730bf1181209fe45c28d7dd1259393e93f740`.
The runner accepts unchanged `Cargo.toml`, `Cargo.lock`, `flake.nix`, and
`flake.lock` identities and executes only:

```text
nix build --no-link --no-update-lock-file \
  --option allow-import-from-derivation false \
  --option restrict-eval true \
  .#checks.x86_64-linux.cargo-test
```

## Authority boundary

`radicle-ci-bot` owns `/var/lib/radicle-ci-bot`, its own Ed25519 identity, and
its own Radicle namespace. It may synchronize the pilot RID from the pinned
Aspen production seed and publish a patch-revision comment. It is not a project
delegate and cannot change the production seed's storage or seeding policy.
Systemd limits bot egress to loopback and `100.100.103.95/32`.

`radicle-ci-runner` owns `/var/lib/radicle-ci-runner` and
`/var/lib/radicle-ci-artifacts`. It can exchange bounded jobs and results only
through `/var/lib/radicle-ci-exchange`. It cannot read the bot home, production
Radicle state, `/run/secrets`, user homes, Harmonia state, SSH configuration,
deployment material, or release credentials. `PrivateNetwork=true` removes job
networking. Jobs build against a per-runner local Nix store with offline mode
and no substituters.

`radicle-ci-input-hydrator` is a separate reviewed preparer. It has no Radicle
identity, credentials, event/archive input, production storage, bot state,
secrets, home, cache-signing, or deployment access. It may use the network only
to hydrate the exact locked inputs and canonical check closure of the fixed
reviewed Bounded Exec source into the runner's local store. Both services use an immutable process-local Nix profile that trusts the runner
only for its private `local?root=` store. They deny namespace creation, host
system features such as `uid-range`, and cache-signing credentials; the
untrusted runner remains offline and is not trusted by the host Nix daemon.

The runner's process, output, memory, CPU, task, artifact, and wall-clock bounds
are enforced by both `bounded-exec` at exact revision
`29dac88ecded94457572db3fdfaaaab95fa91525` and systemd.

## Service flow

1. `radicle-ci-node.service` runs the loopback-only bot node.
2. `radicle-ci-sync.timer` starts `radicle-ci-sync.service`.
3. The sync reconciles the bot's fail-closed policy to the pilot RID and fetches
   only from the pinned production seed.
4. `radicle-ci-input-hydrator.service` prepares only the immutable reviewed
   flake's locked inputs and remains active after successful hydration.
5. `radicle-ci-scan.service` reads the bot's local storage, verifies delegates
   and lock identities, and atomically exports an exact Git object plus event.
6. `radicle-ci-runner.service` verifies the BLAKE3-bound event and archive,
   materializes source read-only, and runs one bounded job.
7. `radicle-ci-publisher.service` moves accepted results to the durable
   published queue and comments on the exact patch revision under the bot DID.

The deterministic job ID and durable ledger suppress duplicate execution after
restart. A failed status publication leaves the result in the outbox for retry.

## Operator checks

```text
systemctl status radicle-ci-node.service radicle-ci-sync.timer
systemctl status radicle-ci-input-hydrator.service
systemctl status radicle-ci-sync.service radicle-ci-scan.service
systemctl status radicle-ci-runner.service radicle-ci-publisher.service
journalctl -u 'radicle-ci-*' --since today

systemctl start radicle-ci-isolation-probe.service
systemctl start radicle-ci-sync.service
find /var/lib/radicle-ci-exchange -maxdepth 2 -type f -print
find /var/lib/radicle-ci-artifacts -maxdepth 2 -type f -print
```

Before accepting a deployment, verify the generated private/public key pair,
pinned bot fingerprint and node ID, non-delegate status, exact single-RID bot
policy, runner filesystem denial, runner network denial, unchanged production
seed policy, unchanged canonical refs, and public Git availability.

## Rollback

Stop and disable `radicle-ci-sync.timer`, then stop the CI publisher, runner,
scanner, sync, and bot node units. Retain published receipts and artifacts.
Remove only `/var/lib/radicle-ci-*` after explicit evidence retention approval.
Do not alter `/var/lib/radicle`, production Radicle services, delegate refs,
canonical refs, Nginx, or Cloudflare configuration during CI rollback.

## Non-claims

A successful job is a bounded observation. It does not prove source or Nix
correctness, host sandbox correctness, merge eligibility, canonical-ref or
release authority, remote artifact durability, protocol-enforced mandatory CI,
or whole-stack GitHub independence.
