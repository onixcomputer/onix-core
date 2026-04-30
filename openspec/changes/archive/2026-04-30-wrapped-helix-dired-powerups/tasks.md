## 1. Manifest and session model

- [x] 1.1 Extend `hx-oil` sidecars with stable entry IDs plus any metadata needed for mark/flag state and inserted subdirectory blocks.
- [x] 1.2 Update manifest render/parse logic for visible mark/flag prefixes, indented inline subdirectory blocks, and clean refresh/reopen behavior for pre-v2 manifests.
- [x] 1.3 Add helper subcommands to toggle marks, clear marks, flag/unflag deletes, and collapse inserted subdirectories without mutating unrelated staged edits.

## 2. Bulk operations and transforms

- [x] 2.1 Implement previewable bulk copy, move, symlink, and relative-symlink planning/execution over marked entries.
- [x] 2.2 Implement target resolution rules for explicit targets, explicit target manifests, wrapper-provided alternate directory buffers, and same-root fallback, with the resolved target shown in previews.
- [x] 2.3 Implement preview-first batch filename transforms for marked entries (regex replacement plus simple prefix/suffix/case transforms), including collision/no-op rejection.
- [x] 2.4 Ensure apply-time validation still rejects stale snapshots, duplicate outputs, unsafe subtree mutations, and unsupported mixed edits before any filesystem mutation.

## 3. Inline subdirectory workflow

- [x] 3.1 Implement inline child-directory insertion, subtree refresh, and subtree collapse with helper-owned block headers and bounded nesting.
- [x] 3.2 Extend open-entry and parent-navigation behavior so inline subdir blocks preserve intuitive cursor movement and do not corrupt mark/flag state.

## 4. Wrapped Helix integration

- [x] 4.1 Wire new helper commands into `inventory/home-profiles/brittonr/base/helix/helix.nix` and `inventory/home-profiles/brittonr/base/helix/helix-zen.nix`.
- [x] 4.2 Extend `inventory/home-profiles/brittonr/base/keymap.ncl` with dedicated actions for mark toggle, delete flag toggle, clear marks, copy/move/link operations, transform preview/apply, inline subdir insert/collapse, and DWIM target-aware actions while keeping existing bindings available.
- [x] 4.3 Expose wrapper-managed target passing so bulk copy/move/link commands can prefer another open directory buffer when available.

## 5. Verification and docs

- [x] 5.1 Add Rust unit/integration tests covering marks vs flags, bulk copy/move/link behavior, DWIM target resolution, transform previews, collision rejection, inline subdir insertion/collapse, subtree refresh, and stale-state refusal.
- [x] 5.2 Add or extend flake integration checks to verify the helper package, manifest format, and generated `hx`/`zen` bindings for the new Dired-inspired actions.
- [x] 5.3 Document the Dired-inspired workflow, especially marks vs flags, explicit preview/apply semantics, target selection, and inline subdirectory behavior.
