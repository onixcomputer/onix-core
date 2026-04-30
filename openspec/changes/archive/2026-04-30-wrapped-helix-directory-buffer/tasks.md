## 1. Helper design and packaging

- [x] 1.1 Add the `hx-oil` Rust package and Nix packaging scaffold under `pkgs/hx-oil/`.
- [x] 1.2 Implement manifest render/parse support for `.hxoil` files and JSON sidecars, including comment lines, trailing-`/` directory markers, and ordered-entry identity rules.
- [x] 1.3 Implement diff planning with explicit dry-run output for create, rename, delete, directory creation, and reorder rejection.
- [x] 1.4 Implement apply-time validation and mutation logic for stale snapshots, duplicate targets, non-empty-directory refusal, missing-sidecar refusal, and other unsupported edits before any filesystem mutation.
- [x] 1.5 Implement navigation subcommands for `open-at-line`, comment-line no-op behavior, refresh, and parent-directory traversal.
- [x] 1.6 Implement session storage and garbage collection under `$XDG_STATE_HOME/hx-oil/` so manifests and sidecars do not leak indefinitely.

## 2. Wrapped Helix integration

- [x] 2.1 Wire the helper into `inventory/home-profiles/brittonr/base/helix/helix.nix` and `inventory/home-profiles/brittonr/base/helix/helix-zen.nix`.
- [x] 2.2 Add wrapper-managed actions for opening a directory buffer, applying staged edits, refreshing the manifest, opening the entry under cursor, and moving to the parent directory using Helix command expansions.
- [x] 2.3 Extend `inventory/home-profiles/brittonr/base/keymap.ncl` with dedicated directory-buffer actions while leaving existing picker bindings intact.

## 3. Verification and rollout

- [x] 3.1 Add Rust unit/integration tests covering all helper scenarios from `specs/wrapped-helix-directory-buffer/spec.md`, including render, directory creation, create, rename, delete, dry-run output, reorder rejection, non-empty-directory rejection, duplicate-target rejection, missing-sidecar rejection, stale-snapshot rejection, open-at-line no-op behavior, parent traversal, and session GC behavior.
- [x] 3.2 Add a Nix/flake integration check that verifies the wrapped Helix environment includes the helper, uses the expected `.hxoil` manifest workflow, and wires the directory-buffer actions into generated configuration.
- [x] 3.3 Document the user workflow, including explicit apply semantics, refresh behavior, and fallback to existing picker/explorer commands during rollout.
