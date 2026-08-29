# Build Storage Specification

## Purpose

Keep disposable workstation build output from exhausting the `britton-desktop` root filesystem or unboundedly consuming the ZFS data pool.

## ADDED Requirements

### Requirement: Repository build storage is off root

r[onix.build_storage.datasets] `britton-desktop` MUST mount `/home/brittonr/git` from a quota-limited ZFS dataset.

#### Scenario: Repository-local Cargo target

r[onix.build_storage.datasets.repo_target]
- GIVEN a repository command sets `CARGO_TARGET_DIR=target`
- WHEN Cargo creates build output below `/home/brittonr/git`
- THEN that output is stored on the Git ZFS dataset
- AND it does not consume root ext4 capacity

### Requirement: Build caches are bounded

r[onix.build_storage.quotas] Shared Cargo and Kache ZFS datasets MUST have explicit quotas.

#### Scenario: Cache growth reaches its bound

r[onix.build_storage.quotas.enforced]
- GIVEN a build cache grows continuously
- WHEN it reaches the configured dataset quota
- THEN ZFS rejects further growth in that dataset
- AND unrelated root filesystem capacity remains available

### Requirement: Interactive Kache stays off root

r[onix.build_storage.kache] The interactive Kache profile MUST store its cache under the ZFS-backed machine cache and MUST keep a finite application budget.

#### Scenario: User daemon starts

r[onix.build_storage.kache.daemon]
- GIVEN the Britton Home Manager profile is active
- WHEN `kache.service` starts
- THEN `KACHE_CACHE_DIR` points below `/var/cache/kache-nix`
- AND the configured local cache maximum is finite

### Requirement: Stale-target cleanup is fail-safe

r[onix.build_storage.cleanup] Automated cleanup MUST remove only stale disposable Cargo target directories.

#### Scenario: Tracked target fixture

r[onix.build_storage.cleanup.tracked]
- GIVEN a directory named `target` is tracked by Git or lacks `CACHEDIR.TAG`
- WHEN the cleanup job scans it
- THEN the directory remains unchanged

#### Scenario: Active build

r[onix.build_storage.cleanup.active]
- GIVEN Cargo or rustc is active for the workstation user
- WHEN the cleanup job starts
- THEN it exits without deleting target directories

#### Scenario: Stale ignored build output

r[onix.build_storage.cleanup.stale]
- GIVEN an ignored Cargo target contains `CACHEDIR.TAG`
- AND no contained file was modified within 21 days
- AND no Cargo or rustc process is active
- WHEN cleanup runs
- THEN the target directory is removed

### Requirement: Journals are bounded

r[onix.build_storage.journal] Persistent system journals MUST be capped at 1 GiB with finite retention.

### Requirement: Runtime validation is authoritative

r[onix.build_storage.validation] Deployment MUST verify the configured mounts, quotas, cleanup timer, Kache cache path, journal limit, and root free space before the migration is complete.

### Requirement: Migration is verified

r[onix.build_storage.migration] The one-time Git migration MUST preserve repository data before the old root copy is removed.

#### Scenario: Dataset switch

r[onix.build_storage.migration.switch]
- GIVEN source and staged ZFS copies have matching file counts, byte totals, and Git repository metadata
- WHEN the Git dataset is mounted at `/home/brittonr/git`
- THEN representative repositories retain their status and worktree metadata
- AND the old root copy is retained until runtime validation succeeds
