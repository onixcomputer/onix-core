## Context

The current wrapped Helix setup in `inventory/home-profiles/brittonr/base/helix/helix.nix` mainly configures themes, language servers, and a few keybindings. Helix already has picker-style navigation (`file_picker`, `file_explorer`), but it does not give us oil.nvim's core behavior: treat a directory listing like an editable buffer whose text changes map to filesystem operations.

Helix has no plugin runtime comparable to Neovim, so this feature cannot live as an in-editor Lua extension. If we want oil-style behavior, it has to come from wrapper-integrated external tooling plus Helix commands and keybindings.

## Goals / Non-Goals

**Goals:**
- Open a local directory as a deterministic editable manifest buffer.
- Map manifest edits to staged filesystem operations: rename, create, and delete.
- Keep navigation inside wrapped Helix: open entry under cursor, refresh listing, and move to parent directory.
- Make destructive operations safe with dry-run support, snapshot validation, and conflict detection.
- Keep core diff/apply logic testable outside Helix.

**Non-Goals:**
- Reproducing oil.nvim feature-for-feature.
- Tree views, recursive multi-directory editing, or remote adapters.
- File previews, git decorations, permission editing, or trash integration.
- Implicitly mutating disk on every text edit.

## Decisions

### 1. Implement `hx-oil` as a Rust CLI packaged by Nix

**Choice:** Implement the feature as an external Rust helper (`hx-oil`) packaged by Nix and injected into the wrapped Helix environment.

**Rationale:** Helix has shell-command and picker primitives, but no stable plugin API for intercepting directory buffers. Rust matches the repo's existing tooling bias, gives us predictable filesystem handling, and keeps the hard logic in a normal testable program without carrying a Helix fork.

**Alternative:** Patch Helix or maintain an out-of-tree plugin host. Rejected because it is high-maintenance and out of proportion for a local workflow feature.

### 2. Use a concrete manifest format with visible names and sidecar metadata

**Choice:** `hx-oil render` writes a plain-text manifest file plus a JSON sidecar. The manifest format is:

```text
# hx-oil root: /abs/path/to/dir
# blank lines and comment lines are ignored
subdir/
notes.md
```

- one editable entry per non-comment line
- directories use a trailing `/`
- blank lines and `# ...` lines are ignored
- entries are rendered in stable order: directories first, then files, each group sorted lexically

The sidecar stores the original ordered snapshot with `root`, `manifest_path`, `created_at`, and `entries = [{ index, relative_path, kind, mtime_ns, size }]`. The manifest file itself uses a stable helper-owned extension (`manifest.hxoil`) so wrapper commands can recognize it explicitly.

**Rationale:** The visible buffer stays simple and Helix-friendly, while the sidecar carries the original ordered snapshot and freshness data needed for diffing.

**Alternative:** Hide immutable per-line IDs inside the visible buffer. Rejected for v1 because Helix does not offer a robust conceal/protected-column story for this workflow.

### 3. Track entry identity by stable order and reject reordering

**Choice:** `hx-oil apply` treats the original ordered snapshot as canonical identity. It compares original entries to edited entries in order, uses longest-common-subsequence style matching for unchanged spans, infers rename/create/delete only for simple local edits, and rejects reordered or multi-entry ambiguous hunks as unsupported.

**Rationale:** This gives us rename detection without exposing ugly inline IDs in the manifest. It is good enough for the common oil-style maintenance flow: rename one entry, add one entry, delete one entry, then apply.

**Alternative:** Attempt to infer arbitrary reorder/move operations. Rejected for v1 because ambiguity grows fast and turns a simple directory buffer into a full patch language.

### 4. Use an explicit Helix ↔ helper command protocol

**Choice:** Wrapper integration will use Helix command expansions and shell commands directly:

- open directory buffer from current file: `:open %sh{hx-oil render --from %{file_path_absolute}}`
- open directory buffer from cwd: `:open %sh{hx-oil render --from %{current_working_directory}}`
- apply staged edits: `:write`, then `:sh hx-oil apply %{file_path_absolute}`, then `:reload`
- refresh manifest: `:sh hx-oil refresh %{file_path_absolute}` then `:reload`
- open entry at cursor: `:open %sh{hx-oil open-at-line %{file_path_absolute} %{cursor_line}}`
- open parent directory: `:open %sh{hx-oil parent %{file_path_absolute}}`

Manifest buffers are real files, so `%{file_path_absolute}` is enough context for helper commands. `open-at-line` uses Helix's `%{cursor_line}` expansion to resolve the selected entry. On comment lines, blank lines, or out-of-range lines, `open-at-line` returns the current manifest path so the action becomes a no-op instead of trying to open an error string as a file.

**Rationale:** This pins the integration seam to concrete Helix features that already exist and avoids vague "some shell command will do it" hand-waving.

**Alternative:** Depend on scratch-buffer round trips or watcher-driven write hooks. Rejected because they are harder to reason about and harder to recover after failures.

### 5. Use explicit apply instead of magic write hooks

**Choice:** Directory edits are staged in the manifest buffer, then applied through an explicit action exposed by the wrapper and helper. Deletes are permanent in v1 (no trash), and deleting a non-empty directory is refused instead of recursing.

**Rationale:** Helix can run shell commands, but it does not offer the kind of reliable buffer-write hooks that would make `:w` semantics easy to maintain. Explicit apply is safer, easier to reason about, and keeps destructive transitions visible to the user.

**Alternative:** Background watcher that mutates the filesystem whenever the manifest file is written. Rejected for v1 because it complicates process lifecycle, cleanup, and error reporting.

### 6. Scope v1 to one rooted local directory per buffer

**Choice:** A manifest buffer represents one local root directory. Entries may be renamed within that root, added, removed, refreshed, and reopened, but v1 does not support remote paths, tree views, or broad recursive editing.

**Rationale:** This preserves the oil.nvim mental model we want most often—"edit this directory like text"—without solving generalized filesystem browsing in one step.

**Alternative:** Full cross-directory move/copy semantics from day one. Rejected because conflict handling and operation ordering get much harder and are not needed for the first useful version.

### 7. Store sessions under XDG state and garbage-collect old manifests

**Choice:** `hx-oil` stores manifests and sidecars under `$XDG_STATE_HOME/hx-oil/sessions/<session-id>/` (defaulting to `~/.local/state/hx-oil/...`). Each helper invocation runs lightweight garbage collection that removes session directories older than seven days. If a manifest loses its sidecar, helper commands fail with a reopen instruction instead of guessing.

**Rationale:** This gives the workflow a stable place for temp state without polluting project directories or `/tmp`, and it makes crash recovery predictable.

**Alternative:** Store everything only in `/tmp`. Rejected because it is less discoverable, less durable across longer Helix sessions, and more likely to vanish unexpectedly.

### 8. Use shared keymap actions and keep zen behavior aligned

**Choice:** Extend the shared keymap contract with directory-buffer actions instead of replacing existing picker bindings, and expose the same helper + bindings in both `hx` and `zen`.

Concretely, v1 will keep the current file picker binding and add dedicated actions for:
- open directory buffer
- apply manifest
- refresh manifest

Parent-directory navigation may use a manifest-local key (for example `-`) because it is specific to this mode.

**Rationale:** This avoids stealing existing muscle memory, keeps behavior consistent across both wrappers, and fits the repo's "shared keymap first" pattern.

**Alternative:** Replace existing explorer/picker bindings or make zen opt out. Rejected because it creates unnecessary drift and surprises.
## Risks / Trade-offs

- **Explicit apply is less magical than oil.nvim** → Document it as an intentional safety trade-off and make the apply action cheap to invoke.
- **Temp manifests can go stale if the directory changes outside Helix** → Snapshot validation must fail loudly and offer refresh instead of applying blindly.
- **Deletes, duplicate names, and reordered lines can destroy intent** → Reject destructive or ambiguous edits before mutation and show a clear reason.
- **Large directories may feel clumsy as plain text buffers** → Keep render format lightweight and treat large-directory optimization as future work.
- **Wrapper integration touches both regular and zen Helix packages** → Share as much helper wiring as possible so behavior does not drift.
- **Helix shell integration is stringly typed** → Keep the command protocol narrow and test the exact rendered commands in integration checks.

## Migration Plan

1. Add the Rust helper package and its tests.
2. Wire the package into wrapped Helix and expose open/apply/refresh actions.
3. Extend the shared keymap contract with dedicated directory-buffer actions while leaving existing picker behavior intact.
4. Ship the same bindings in `hx` and `zen` so the workflow does not drift.
5. Verify helper behavior with Rust unit/integration tests and verify wrapper wiring with a Nix/flake check that inspects the generated Helix configuration and wrapper environment.
6. Add docs/examples after the feature shape is stable.
