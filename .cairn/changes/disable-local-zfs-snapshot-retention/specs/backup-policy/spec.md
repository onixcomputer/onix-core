# Backup policy Specification Delta

## ADDED Requirements

### Requirement: No local ZFS snapshot retention

r[onix.backup.no_local_snapshots] Britton-desktop and aspen3 MUST disable the Clan-enabled `services.zfs.autoSnapshot` timers, so no hourly, daily, weekly or monthly local snapshot is created or retained by policy. Off-machine retention MUST come from the general Borg jobs and the encrypted Restic archives on Google Drive. Dataset `com.sun:auto-snapshot` properties and existing snapshots MUST remain untouched.

#### Scenario: Evaluate both machines

- GIVEN the two machine configurations
- WHEN the NixOS configurations are evaluated
- THEN `services.zfs.autoSnapshot.enable` is false on both
- AND no `zfs-snapshot-*` timer or service is generated
- AND no local snapshot is created by policy.

#### Scenario: Existing snapshots are preserved

- GIVEN snapshots already present on aspen3's agent datasets
- WHEN the new configuration is activated
- THEN those snapshots remain in place
- AND only new snapshot creation stops.
