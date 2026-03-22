## ADDED Requirements

### Requirement: Sanoid snapshot automation
All ZFS machines SHALL run sanoid for automated snapshot creation and pruning, configured via the `zfs` tag with per-dataset retention policies.

#### Scenario: Home dataset snapshots
- **WHEN** sanoid runs on its hourly timer
- **THEN** a new snapshot `rpool/home@autosnap_<timestamp>_hourly` is created, and snapshots beyond the retention window (24 hourly, 30 daily, 4 weekly, 6 monthly) are pruned

#### Scenario: Nix dataset excluded
- **WHEN** sanoid evaluates the `rpool/nix` dataset
- **THEN** no snapshots are created (nix store is reproducible, snapshots waste space)

### Requirement: Snapshot retention per dataset
Sanoid SHALL apply the following retention policies:

| Dataset | Hourly | Daily | Weekly | Monthly |
|---------|--------|-------|--------|---------|
| home | 24 | 30 | 4 | 6 |
| root | 0 | 7 | 2 | 0 |
| var-log | 0 | 7 | 0 | 0 |
| nix | — | — | — | — |
| data (desktop) | 24 | 30 | 4 | 6 |

#### Scenario: Root dataset daily snapshot
- **WHEN** the daily sanoid timer fires
- **THEN** a snapshot of `rpool/root` is created and snapshots older than 7 days (daily) or 2 weeks (weekly) are pruned

#### Scenario: Var-log short retention
- **WHEN** var-log snapshots older than 7 days exist
- **THEN** sanoid prunes them, keeping at most 7 daily snapshots

### Requirement: Snapshot listing
Users SHALL be able to list all snapshots for a dataset using `zfs list -t snapshot -r rpool/<dataset>`.

#### Scenario: List home snapshots
- **WHEN** a user runs `zfs list -t snapshot -r rpool/home`
- **THEN** output shows timestamped snapshots matching sanoid naming convention, ordered chronologically

### Requirement: Manual snapshot rollback
Users SHALL be able to rollback a dataset to a previous snapshot using `zfs rollback rpool/<dataset>@<snapshot>`.

#### Scenario: Rollback home to yesterday
- **WHEN** a user runs `zfs rollback -r rpool/home@autosnap_<yesterday>_daily`
- **THEN** the `/home` filesystem contents revert to the state at that snapshot timestamp
