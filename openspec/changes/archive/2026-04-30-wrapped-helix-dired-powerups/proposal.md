## Why

`hx-oil` v1 covers the core Wdired-like loop: open a directory manifest, edit names, and explicitly apply create/rename/delete changes. That gets us oil-style inline editing, but it still lacks the higher-leverage Dired workflows that make directory editing fast once the novelty wears off:

- marking several files before operating on them
- flagging deletes separately from inline text edits
- bulk copy/move/link commands with a sensible target guess
- batch filename transforms that avoid hand-editing many lines
- expanding a child directory in place instead of replacing the whole buffer

Without those pieces, `hx-oil` is good for a few local renames but weak for real directory maintenance.

## What Changes

- Extend `hx-oil` with Dired-style marks and delete flags that coexist with editable manifest lines.
- Add bulk operations over marked entries: copy, move, symlink, and relative symlink, with DWIM target selection from another open directory buffer when available.
- Add previewable bulk filename transforms for marked entries so users can apply regex/prefix/suffix/case changes without hand-editing every line.
- Add inline subdirectory insertion, subtree refresh, and subtree collapse so users can work across nearby directories without leaving the current manifest context.
- Wire the new actions into wrapped Helix and zen without replacing existing picker/explorer flows.
- Add tests and docs for the new batch-oriented workflow.

## Non-Goals

- Full recursive tree editing by default; this change is limited to the root directory plus explicitly inserted child subdirectories.
- Remote/TRAMP-style targets or non-local filesystems.
- Trash/undo/rollback UX for bulk operations beyond a clear halt-on-error policy.
- Async/background bulk jobs.
- Permission, ownership, compression, encryption, or other non-core Dired admin commands.
- Replacing Helix's existing picker/explorer workflows.

## Capabilities

### Modified Capabilities
- `wrapped-helix-directory-buffer`: add Dired-inspired batch operations, inline subdirectory context, and target-aware bulk actions on top of the existing explicit-apply workflow.

## Impact

- `pkgs/hx-oil/` helper command surface, manifest format, sidecar/session model, and tests.
- `inventory/home-profiles/brittonr/base/helix/helix.nix` and `inventory/home-profiles/brittonr/base/helix/helix-zen.nix` for new commands and wrapper wiring.
- `inventory/home-profiles/brittonr/base/keymap.ncl` for dedicated Dired-inspired actions.
- Flake checks and docs covering marks/flags, bulk ops, target inference, and inline subdir behavior.

## Verification Expectations

- Rust unit/integration coverage for mark/flag state, bulk operation planning/execution, transform preview rules, stale-state rejection, and inline subdirectory behavior.
- Flake integration checks that inspect generated `hx`/`zen` wrapper scripts plus generated Helix config for helper wiring and new actions.
- Manual smoke validation for the interactive pieces that Helix shell-command wiring cannot fully unit-test, especially target selection and inline subtree workflows.
