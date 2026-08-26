## Why

The Site deployment adapter needs a dedicated Celld fleet. The existing `celld-lab` instance owns a counter Worker and one RustFS bucket. Celld permits one deployed application per fleet, so Site cannot share that fleet.

The current Celld module also gives every instance the same systemd units, Unix user, and provisioning directory. A second instance on one host would collide with the lab instance.

## What Changes

- Add an explicit validated runtime name to each Celld instance.
- Derive instance-specific systemd units, Unix identities, and provisioning state from that runtime name.
- Add a two-node Site fleet on `aspen3` and `britton-desktop` with one dedicated RustFS bucket and credential.
- Deploy an AWS shared-credentials file only to the declared publisher user.
- Record static and live rollout evidence without claiming public Internet service.

## Impact

- **Files**: `modules/celld/`, `inventory/services/`, `flake-outputs/_module-checks.nix`, `docs/`, `cairn/changes/site-celld-fleet/`, and `cairn/specs/site-celld-fleet/` after synchronization.
- **Testing**: Nickel validation, semantic settings tests, generated NixOS topology checks, affected machine builds, bucket authority probes, Celld health checks, and a Site asset deployment through both healthy nodes.
