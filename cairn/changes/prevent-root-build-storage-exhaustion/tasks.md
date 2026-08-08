## Phase 1: Declare bounded storage

- [x] [serial] Declare the Git, shared Cargo target, and Kache ZFS quotas. r[onix.build_storage.datasets]
- [x] [serial] Route interactive Kache state to the ZFS-backed machine cache. r[onix.build_storage.kache]
- [x] [serial] Add bounded journal retention. r[onix.build_storage.journal]

## Phase 2: Add safe retention

- [x] [serial] Add a weekly stale Cargo target cleanup service and timer. r[onix.build_storage.cleanup]
- [x] [serial] Require Cargo cache markers, Git-ignore status, inactivity, and no active compiler processes before deletion. r[onix.build_storage.cleanup]

## Phase 3: Migrate and validate

- [x] [serial] Validate the Cairn package and evaluate the `britton-desktop` machine configuration. r[onix.build_storage.validation]
- [x] [serial] Clear the oversized shared Cargo cache after active builds stop. r[onix.build_storage.migration]
- [x] [serial] Copy `~/git` into `datapool/git`, switch the mount, and compare source and destination manifests. r[onix.build_storage.migration]
- [x] [serial] Deploy the Home Manager and NixOS changes, then verify mounts, quotas, service timers, Kache paths, and free space. r[onix.build_storage.validation]
