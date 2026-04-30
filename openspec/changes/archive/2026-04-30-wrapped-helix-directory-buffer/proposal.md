## Why

Wrapped Helix already gives us pickers and Helix ships a built-in file explorer, but those flows still treat directory work as navigation, not editing. Renaming files, creating sibling files, pruning stale entries, and walking parent directories still push the workflow into a shell or external file manager. We want an oil.nvim-style directory buffer so filesystem maintenance can stay inside our wrapped Helix workflow.

## What Changes

- Add a companion `hx-oil` helper that renders a local directory as an editable manifest buffer and can apply staged filesystem edits.
- Teach the wrapped Helix packages to open these manifests from the current buffer directory or an explicit directory path.
- Add directory-buffer actions for open entry, refresh, parent navigation, and apply so the workflow feels like a Helix-native oil-style mode instead of a one-off shell script.
- Add safety rails around destructive edits: snapshot validation, conflict detection, dry-run output, and clear failure messages.
- Add automated checks for manifest rendering, diff/apply behavior, and wrapper integration.

## Capabilities

### New Capabilities
- `wrapped-helix-directory-buffer`: Oil-style directory browsing and staged filesystem edits inside the repo's wrapped Helix packages.

### Modified Capabilities

## Impact

- New package for the companion helper (likely `pkgs/hx-oil/` or equivalent Rust source + package wiring).
- `inventory/home-profiles/brittonr/base/helix/helix.nix` and likely `inventory/home-profiles/brittonr/base/helix/helix-zen.nix` for package install and command bindings.
- `inventory/home-profiles/brittonr/base/keymap.ncl` if we extend the shared leader-action contract for directory-buffer actions.
- Flake/package checks to exercise render, diff, and apply behavior.
