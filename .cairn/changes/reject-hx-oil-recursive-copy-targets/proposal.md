## Why

`hx-oil op copy` accepts a target directory located beneath a selected source directory. Its recursive copy implementation creates the destination before walking the source, so the new destination becomes part of the traversal and can recurse until path-length or storage exhaustion.

## What Changes

- Add a pure ancestry check for every bulk-copy source and computed destination.
- Reject targets equal to or nested beneath a selected directory before any filesystem mutation.
- Preserve valid copies to sibling and external directories.
- Add positive and negative planner plus CLI regression tests.

## Impact

- **Files**: `pkgs/hx-oil/src/lib.rs`, `pkgs/hx-oil/tests/cli.rs`, and Cairn traceability markers added during implementation.
- **Risk**: Previously accepted self-nesting copy commands will fail closed with a diagnostic.
- **Non-goals**: Do not add overwrite semantics or change valid move/symlink behavior beyond shared safety validation where necessary.
- **Testing**: Cover sibling copies, external targets, direct self-targets, descendant targets, symlink-resolved descendants, and zero-mutation rejection.
