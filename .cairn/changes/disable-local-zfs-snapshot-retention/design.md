# Design

## Decision

Set `services.zfs.autoSnapshot.enable = lib.mkForce false` in `machines/aspen3/configuration.nix` and `machines/britton-desktop/configuration.nix`.

`lib.mkForce` is required because `nixosModules/clanCore/zfs.nix` from the Clan input defines the option as `true` for every Clan machine.

## Why not restructure the timers

Clan owns the option definition and the four generated timers. Overriding the timers individually would leave the option enabled and the units defined; disabling the option removes the services and timers at the module boundary and survives Clan updates.

## Why not keep a short local window

The user selected "only go to Drive, not local". A short retention still pins deleted blocks until the window rolls over, which is what made the 71 GiB deletion look like an ENOSPC failure. The off-machine path is already the intended retention.

## Alternatives considered

- **Transient snapshot to Restic on Drive**: the correct long-term shape for consistent hourly offsite copies, but it needs the rclone token and Restic password provisioned per host plus a timer. Declined for now; recorded as a gap.
- **Keep 2/2 locally**: cheaper than 8/7/4/1 but still local retention, contrary to the request.

## Verification

- Evaluate both configurations: `services.zfs.autoSnapshot.enable` is false and no `zfs-snapshot-*` timer or service is generated.
- Stop and disable the running timers on both hosts, then confirm none is active and `zfs list -t snapshot` gains no new `zfs-auto-snap_*` entries.
- No production backup run, prune, restore or dataset migration.
