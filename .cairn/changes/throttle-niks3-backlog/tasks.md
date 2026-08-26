## Phase 1: Load shaping

- [x] [serial] Limit each fleet uploader to one concurrent upload. r[onix.rustfs_build_caches.uploaders]
- [x] [serial] Add a generated positive check for the bounded worker count while retaining negative settings coverage. r[onix.rustfs_build_caches.uploaders]

## Phase 2: Verification and rollout

- [ ] [serial] Run focused checks and build all three machine closures. r[onix.rustfs_build_caches.uploaders]
- [ ] [serial] Deploy all three nodes and drain existing queues one node at a time. r[onix.rustfs_build_caches.uploaders.backlog]
- [ ] [serial] Record queue, service, and health evidence with explicit non-claims. r[onix.rustfs_build_caches.uploaders.backlog]

## Phase 3: Completion

- [ ] [serial] Sync the accepted specification, archive the change, and integrate the verified branch. r[onix.rustfs_build_caches.uploaders]
