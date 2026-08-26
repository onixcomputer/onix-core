## Phase 1: Fleet configuration

- [x] [serial] Add typed per-node Kache composition, shared read-only client configuration, and managed cache directories. r[onix.rustfs_build_caches.kache]
- [x] [serial] Apply the Kache Cargo profile to `brittonr` on all three nodes while preserving sandbox isolation. r[onix.rustfs_build_caches.kache.sandbox]

## Phase 2: Verification and rollout

- [x] [serial] Add positive and negative generated checks for membership, local endpoints, storage paths, one provisioner, credentials, and Cargo wrappers. r[onix.rustfs_build_caches.kache.storage]
- [x] [serial] Build, deploy, and capture cross-node Kache reuse and failure-safe evidence. r[onix.rustfs_build_caches.kache.upload]
- [x] [serial] Sync the accepted specification, archive the change, and integrate the verified branch. r[onix.rustfs_build_caches.kache]
