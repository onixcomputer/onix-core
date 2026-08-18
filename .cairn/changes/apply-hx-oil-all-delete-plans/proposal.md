## Why

`hx-oil` removes delete-flagged entries before it creates per-scope apply plans. When every entry in a scope is delete-flagged, that scope disappears from planning, so dry-run and apply report "No changes" and leave the files intact.

## What Changes

- Preserve every represented scope while constructing edited-entry groups.
- Build an empty final-entry plan when all entries in a scope are deleted.
- Retain non-empty-directory deletion protection and stale-snapshot checks.
- Add root and inserted-subdirectory regression tests for all-delete operations.

## Impact

- **Files**: `pkgs/hx-oil/src/lib.rs`, `pkgs/hx-oil/tests/cli.rs`, and Cairn traceability markers added during implementation.
- **Risk**: A previously ignored all-delete manifest will now perform the explicitly requested deletions.
- **Non-goals**: Do not permit recursive deletion of non-empty directories.
- **Testing**: Cover a sole file, all files in a scope, an empty directory, an inserted subdirectory, a non-empty directory rejection, and dry-run/apply parity.
