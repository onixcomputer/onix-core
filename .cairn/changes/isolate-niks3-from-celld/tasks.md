## Phase 1: Storage isolation

- [x] [serial] Make RustFS instances generate distinct units, credentials, volumes, and resource controls. r[onix.rustfs_cluster.instances]
- [x] [serial] Add a standalone cache-only RustFS instance and move niks3 object storage to it. r[onix.rustfs_build_caches.niks3.isolation]
- [x] [serial] Disable automatic uploader activation and add guarded manual maintenance starts. r[onix.rustfs_build_caches.uploaders]

## Phase 2: Monitoring and recovery

- [x] [serial] Export durable queue depth and add blackbox probes and alerts for RustFS, Celld, and niks3. r[onix.rustfs_build_caches.monitoring]
- [x] [serial] Add off-host Celld object and niks3 metadata backups with bounded restore probes. r[onix.rustfs_build_caches.recovery]

## Phase 3: Validation and rollout

- [x] [serial] Run positive and negative settings checks, generated checks, and complete builds for all three nodes. r[onix.rustfs_cluster.instances]
- [ ] [serial] Deploy one verified closure per host and prove isolation, rejected unsafe drains, backup, restore, and service health. r[onix.rustfs_build_caches.niks3.isolation]
- [ ] [serial] Sync accepted specifications, archive the change, integrate the verified branch, and record explicit non-claims. r[onix.rustfs_build_caches.recovery]
