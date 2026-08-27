## Phase 1: Load shaping

- [x] [serial] Limit each fleet uploader to one concurrent upload. r[onix.rustfs_build_caches.uploaders]
- [x] [serial] Add a generated positive check for the bounded worker count while retaining negative settings coverage. r[onix.rustfs_build_caches.uploaders]

## Phase 2: Verification and rollout

- [x] [serial] Run focused checks and build all three machine closures. r[onix.rustfs_build_caches.uploaders]
- [x] [serial] Deploy all three nodes and exercise one existing queue with bounded concurrency. r[onix.rustfs_build_caches.uploaders.backlog]
- [x] [serial] Record queue, service, and health evidence with explicit non-claims. r[onix.rustfs_build_caches.uploaders.backlog]

## Phase 3: Completion

- [x] [serial] Sync the accepted specification, archive the change, and integrate the verified branch. r[onix.rustfs_build_caches.uploaders]
