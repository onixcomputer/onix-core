# Tasks

- [ ] 1.1 Replace aspen3's auto-snapshot keep counts with `services.zfs.autoSnapshot.enable = lib.mkForce false` and drop the frequent-timer override.
- [ ] 1.2 Add the same override to britton-desktop.
- [ ] 1.3 Update the `onix.backup` spec: remove the lean local policy requirement, add the no-local-retention requirement.
- [ ] 2.1 Evaluate both machines: option false, no `zfs-snapshot-*` units.
- [ ] 2.2 Stop and disable the running timers on both hosts; confirm none active.
- [ ] 2.3 Confirm no new `zfs-auto-snap_*` snapshot appears and record existing snapshot counts.
- [ ] 3.1 Commit and push the configuration and spec change.
