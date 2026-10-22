## Why

The 2026-10-21 flake update moved `radicle-node` from 1.9.1 to 1.10.3 and
`radicle-httpd` from 0.27.0 to 0.28.0. `radicle-node-policy` pins the exact
reviewed identity of both, so it has failed since the update. The operator
accepted both releases on 2026-10-21.

## What Changes

- Pin the reviewed `radicle-node` release to 1.10.3 in the node policy check.
- Record `radicle-httpd` 0.28.0, its `releases/0.28.0` tag on the same
  seed.radicle.dev source, and its source and cargo hashes as the reviewed
  httpd identity.
- Keep validating the bootstrap receipt and the replica receipt against the
  releases they recorded, and keep the module minimum at 1.9.1.
- Name the node version bounds in both checks by their roles: reviewed
  release, module minimum, and recorded receipt version.

## Impact

- **Files**: `flake-outputs/_radicle-node-checks.nix`,
  `flake-outputs/_radicle-seed-replica-checks.nix`.
- **Risk**: checks only; no machine configuration changes, and `aspen1`
  already runs both releases. Nixpkgs still marks `radicle-node` 1.10.3
  insecure, and the exact-version permit from `permit-insecure-radicle-node`
  stays in place.
- **Non-goals**: no package, service, or seeding-policy change, and no new
  deployment evidence for either release.
- **Testing**: the `radicle-node-policy` and `radicle-seed-replica` checks.

## Affected Specs

- `radicle-node-hosting`: the package requirement records the reviewed
  releases that the checks pin.
