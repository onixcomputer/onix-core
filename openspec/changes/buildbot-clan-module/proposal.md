## Why

Buildbot is configured as a direct NixOS import in `machines/aspen1/buildbot.nix`, outside the clan inventory system. Secrets use clan vars but the service itself doesn't follow the perInstance pattern used by every other service (harmonia, prometheus, tailscale, etc.). Adding a second worker (e.g., aspen2 or britton-desktop) means duplicating config and manually wiring secrets. Converting buildbot to a clan service module makes workers tag-driven, centralizes the master config in inventory, and unblocks future work like distributed builds and push-deploy effects.

## What Changes

- New clan service module `modules/buildbot/default.nix` with `master` and `worker` roles using the perInstance pattern
- Master role: wraps `buildbot-nix.nixosModules.buildbot-master` with clan vars generators for all secrets (worker password, GitHub app key, OAuth secret, webhook secret)
- Worker role: wraps `buildbot-nix.nixosModules.buildbot-worker` with automatic password provisioning from the master's generated worker secret
- Inventory service instance in `inventory/services/buildbot.nix` assigning master to aspen1 and workers via machine references (aspen1 initially, expandable by adding machines)
- Remove `machines/aspen1/buildbot.nix` direct import — all config flows through inventory
- Existing `outputsPath`, `postBuildSteps` (ntfy notifications), and harmonia co-location remain functionally identical

## Capabilities

### New Capabilities
- `buildbot-clan-service`: Clan service module for buildbot-nix with master/worker roles, clan vars secret management, and inventory-driven configuration

### Modified Capabilities

## Impact

- `modules/default.nix` — register new `buildbot` module
- `modules/buildbot/default.nix` — new clan service module
- `inventory/services/buildbot.nix` — new inventory service instance
- `inventory/services/default.nix` — import the new service
- `machines/aspen1/buildbot.nix` — deleted (logic moves to module + inventory)
- `machines/aspen1/configuration.nix` — remove `./buildbot.nix` import
- `flake.nix` — no changes (buildbot-nix input stays, nixosModules imported by the clan module)
- Existing clan vars generators (`buildbot-worker`, `buildbot-github`) move into the module's perInstance
- No secret re-generation needed — var names and paths stay the same
