# Wrapped Helix Directory Buffer Specification

## Purpose

This specification records requirements synced from OpenSpec change `wrapped-helix-directory-buffer`.

## Requirements

<!-- synced from openspec change: wrapped-helix-directory-buffer -->
## ADDED Requirements

### Requirement: Wrapped Helix can open a directory manifest buffer
The wrapped Helix distribution SHALL provide an oil-style directory-buffer workflow backed by external helper tooling. Opening a directory through this workflow MUST produce a plain-text manifest buffer representing exactly one local root directory snapshot. The manifest SHALL use one editable entry per non-comment line, lines beginning with `#` SHALL be treated as helper metadata/comments, blank lines SHALL be ignored, and directory entries MUST be rendered with a trailing `/` marker.

#### Scenario: Open explicit directory path
- **WHEN** the user invokes the directory-buffer workflow on an explicit local path
- **THEN** Helix opens a manifest buffer for that directory instead of a fuzzy picker result list

#### Scenario: Open current buffer directory
- **WHEN** the user invokes the directory-buffer workflow from an open file buffer
- **THEN** the manifest root is the current buffer's parent directory

#### Scenario: Directory entries are visually distinct
- **WHEN** a manifest contains both files and subdirectories
- **THEN** subdirectories are rendered with a trailing `/` marker that distinguishes them from files

#### Scenario: Comment lines do not become filesystem entries
- **WHEN** the manifest contains helper comment lines beginning with `#`
- **THEN** those lines are ignored by diff and apply logic

### Requirement: Manifest edits stage filesystem operations
The helper SHALL treat manifest edits as staged filesystem operations rooted in the manifest directory. Changing an existing entry name SHALL stage a rename, adding a new entry SHALL stage a create, and removing an entry SHALL stage a delete. Directory creation MUST be expressible from the manifest format. The helper SHALL preserve original entry order as the identity signal for rename detection in v1, and it MUST reject reordered or otherwise ambiguous edits that cannot be mapped safely.

#### Scenario: Rename existing file
- **WHEN** the user changes `notes.md` to `ideas.md` in the manifest
- **THEN** the staged plan contains a rename from `notes.md` to `ideas.md`

#### Scenario: Create new file
- **WHEN** the user adds a new manifest line for `todo.md`
- **THEN** the staged plan contains a file creation for `todo.md`

#### Scenario: Create new directory
- **WHEN** the user adds a new manifest line using the directory marker format for `drafts`
- **THEN** the staged plan contains a directory creation for `drafts`

#### Scenario: Delete existing entry
- **WHEN** the user removes the manifest line for `old.txt`
- **THEN** the staged plan contains a delete operation for `old.txt`

#### Scenario: Refuse deletion of non-empty directory
- **WHEN** the user removes a manifest line for a directory that still contains children
- **THEN** the apply fails with a non-empty-directory error and performs no filesystem mutations

#### Scenario: Reject ambiguous duplicate target
- **WHEN** the edited manifest would map two entries to the same target path
- **THEN** the helper fails the apply with a clear duplicate-path error and performs no filesystem mutations

#### Scenario: Reject reordered manifest entries
- **WHEN** the user reorders existing manifest entries without keeping the original order
- **THEN** the helper fails the apply with an unsupported-reordering error and performs no filesystem mutations

### Requirement: Apply validates the snapshot before mutating disk
Applying a manifest SHALL validate the current filesystem state against the original snapshot before executing staged operations. If the baseline is stale, an entry changed externally, or a destructive action would be ambiguous, the helper MUST fail loudly without partial mutation. The helper SHALL support a dry-run mode that shows planned operations without executing them.

#### Scenario: Dry-run shows staged operations
- **WHEN** the user runs the apply action in dry-run mode for a manifest containing a rename and a delete
- **THEN** the helper prints the planned operations and leaves the filesystem unchanged

#### Scenario: Apply succeeds on unchanged directory
- **WHEN** the filesystem still matches the manifest snapshot and the staged edits are valid
- **THEN** the helper performs the planned operations and refreshes the manifest view to the new canonical state

#### Scenario: Apply fails on stale snapshot
- **WHEN** an entry in the manifest root was changed outside the directory buffer after the snapshot was created
- **THEN** the helper reports a stale-snapshot error and performs no filesystem mutations

#### Scenario: Apply fails when sidecar state is missing
- **WHEN** the manifest sidecar is missing or unreadable at apply time
- **THEN** the helper fails with a reopen-the-directory-buffer instruction and performs no filesystem mutations

### Requirement: Directory-buffer navigation stays inside wrapped Helix
From a directory manifest buffer, the wrapped Helix workflow SHALL support opening the entry under cursor, refreshing the current manifest, and moving to the parent directory without leaving Helix for an external file manager.

#### Scenario: Open file entry under cursor
- **WHEN** the cursor is on a file entry and the user invokes the open-entry action
- **THEN** Helix opens that file in the current workflow

#### Scenario: Open subdirectory entry under cursor
- **WHEN** the cursor is on a subdirectory entry and the user invokes the open-entry action
- **THEN** Helix replaces or opens a manifest buffer rooted at that subdirectory

#### Scenario: Open action on comment line is a no-op
- **WHEN** the cursor is on a comment line, blank line, or line outside the manifest entry range and the user invokes the open-entry action
- **THEN** the current manifest remains open and no unrelated file is opened

#### Scenario: Move to parent directory
- **WHEN** the user invokes the parent-directory action from a manifest buffer
- **THEN** Helix opens a manifest buffer for the parent of the current manifest root

#### Scenario: Refresh manifest after external changes
- **WHEN** the user invokes the refresh action after the directory contents changed outside Helix
- **THEN** the manifest is regenerated from the current filesystem state

### Requirement: Wrapped Helix packages expose the workflow consistently
The repo's wrapped Helix packages SHALL install the helper tool and expose the directory-buffer workflow through wrapper-managed commands or keybindings. The shared keymap contract SHALL define dedicated directory-buffer actions rather than replacing existing picker bindings, and the Helix wrapper MUST consume the shared values rather than hardcoding conflicting bindings.

#### Scenario: Regular wrapped Helix includes helper
- **WHEN** the main `hx` wrapper is built from Home Manager configuration
- **THEN** the helper executable is present in the wrapper environment and the directory-buffer actions are bound

#### Scenario: Zen wrapper stays aligned
- **WHEN** the `zen` wrapper is built with directory-buffer support
- **THEN** it uses the same helper implementation and compatible action bindings as the main wrapper

### Requirement: Automated checks cover render, diff, and wrapper integration
The change SHALL include automated checks covering manifest rendering, diff/apply planning, stale-snapshot rejection, and wrapper integration.

#### Scenario: Helper tests cover filesystem planning
- **WHEN** automated tests run for the helper
- **THEN** they verify create, rename, delete, duplicate-target rejection, and stale-snapshot rejection behavior

#### Scenario: Nix integration check covers wrapper wiring
- **WHEN** repo checks evaluate the wrapped Helix configuration
- **THEN** they verify that the helper package and directory-buffer actions are present in the generated wrapper configuration

<!-- synced from openspec change: wrapped-helix-dired-powerups -->
## MODIFIED Requirements

### Requirement: Wrapped Helix directory buffers support explicit marks and delete flags
The directory-buffer workflow SHALL expose a visible in-band per-entry prefix that distinguishes unmarked entries, marked entries, and delete-flagged entries without leaving the editable manifest format. Marks SHALL be usable as a transient selection set for bulk operations, and delete flags SHALL remain distinct from plain line deletion so users can stage removals without rewriting surrounding text.

The persisted manifest syntax for entry lines MUST be:
- `"  <entry>"` for an unmarked entry
- `"* <entry>"` for a marked entry
- `"D <entry>"` for a delete-flagged entry

where `<entry>` keeps the existing trailing `/` directory marker rules.

If the helper opens a pre-v2 manifest that lacks this prefix grammar, it MUST refresh/re-render that manifest into the v2 format before further edits or bulk actions proceed.

#### Scenario: Mark entries for batch actions
- **WHEN** the user toggles marks on multiple manifest entries
- **THEN** those entries show the manifest's marked prefix and become the default input set for bulk copy, move, link, and transform actions

#### Scenario: Flag deletes without removing lines immediately
- **WHEN** the user flags an entry for deletion
- **THEN** the entry shows the manifest's delete flag prefix and remains visible until the explicit apply step executes

#### Scenario: Clear marks without discarding inline rename text edits
- **WHEN** the user clears marks in a manifest containing other staged text edits
- **THEN** only mark state changes and unrelated staged rename/create text remains intact

#### Scenario: Delete flags and inline line deletion compose deterministically
- **WHEN** one entry is delete-flagged with `D ` and another entry is removed from the manifest text before apply
- **THEN** apply treats both as staged deletes, and if the same entry is both delete-flagged and removed from the manifest text, the helper executes at most one delete for that entry

### Requirement: Directory buffers support explicit bulk operations over marked entries
The helper SHALL support explicit bulk copy, move, symlink, and relative-symlink actions over marked entries. Each action MUST preview the resolved target and planned mutations before execution, and it MUST refuse collisions, stale state, or unsupported mixes before mutating the filesystem. If execution still fails after preview because of an external runtime condition, the helper MUST halt on the first error, report the partial completion boundary, and MUST NOT attempt automatic rollback.

#### Scenario: Copy marked entries to another directory buffer target
- **WHEN** the user runs the bulk copy action with marked entries and another directory buffer is selected as the target
- **THEN** the helper previews copy operations into that target root and executes them only after the explicit action completes

#### Scenario: Move marked entries with DWIM target resolution
- **WHEN** the user runs the bulk move action without an explicit filesystem path but another directory buffer is available as the wrapper-provided alternate target via `--alternate-manifest <path>`
- **THEN** the helper uses that alternate target in the preview and move plan

#### Scenario: Resolve zero, one, or many DWIM targets deterministically
- **WHEN** the user runs a bulk target-aware action without an explicit target
- **THEN** target resolution uses zero/one/many candidate rules in this order: no alternate buffer -> current manifest root, exactly one alternate buffer -> that buffer root, multiple alternate buffers -> the wrapper-provided most recently focused alternate buffer

#### Scenario: Relative symlink uses same preview and collision rules
- **WHEN** the user runs the relative-symlink action on marked entries
- **THEN** the helper previews the resolved relative link paths and rejects duplicate outputs using the same collision policy as copy and move

#### Scenario: Reject bulk operation collisions
- **WHEN** a bulk copy, move, or link action would create a duplicate output path in the target directory
- **THEN** the helper fails with a clear collision error and performs no filesystem mutations

### Requirement: Directory buffers support preview-first filename transforms
The helper SHALL support batch filename transforms over marked entries, including regex replacement and simple prefix/suffix/case transforms. The transform workflow MUST preview the resulting names before execution and MUST reject collisions, ambiguous no-ops, or path escapes before changing the filesystem or canonical manifest state.

#### Scenario: Preview regex rename over marked files
- **WHEN** the user applies a regex rename transform to marked entries
- **THEN** the helper shows the original and transformed names before any mutation occurs

#### Scenario: Preview prefix, suffix, and case transforms
- **WHEN** the user applies a prefix, suffix, lower-case, or upper-case transform to marked entries
- **THEN** the helper previews the resulting names before any mutation occurs

#### Scenario: Reject transform collision
- **WHEN** a batch transform would map two marked entries to the same output name
- **THEN** the helper reports a collision error and performs no filesystem mutations

### Requirement: Directory buffers support inline child-directory insertion
The directory-buffer workflow SHALL support inserting a child directory's contents inline inside the current manifest using helper-owned in-band block delimiters. Users SHALL be able to refresh or collapse that inserted subtree without leaving the parent directory context. This change supports at most one inserted child-directory level beneath the root manifest; deeper nested subtree insertion is out of scope. Inline subtree insert/refresh/collapse errors MUST leave the manifest unchanged.

#### Scenario: Insert child directory inline
- **WHEN** the cursor is on a subdirectory entry and the user invokes the inline insert action
- **THEN** the manifest inserts that child directory's entries in-place with exact helper-owned subdirectory block markers `# hx-oil subdir: <name>` and `# hx-oil end-subdir: <name>`

#### Scenario: Reject deeper nested subtree insertion
- **WHEN** the user attempts to inline-insert a grandchild directory from inside an already inserted child subtree
- **THEN** the helper refuses the request with a bounded-nesting error and leaves the current manifest unchanged

#### Scenario: Collapse inserted subtree
- **WHEN** the user invokes collapse on an inserted subdirectory block
- **THEN** the helper removes that block from the manifest while leaving the parent directory listing intact

#### Scenario: Refresh inserted subtree after external changes
- **WHEN** files are added or removed inside an inserted child directory outside Helix and the user refreshes that subtree
- **THEN** only that subtree block is regenerated from current filesystem state

#### Scenario: Edits inside an inserted subtree are scoped to that child root
- **WHEN** the user marks, flags, renames, creates, or deletes entries inside an inserted child subtree block
- **THEN** preview and apply treat those edits as operations scoped to that child directory root and MUST reject moves or transforms that would cross subtree boundaries in one step

### Requirement: Wrapped Helix packages expose Dired-inspired batch actions consistently
The repo's wrapped Helix packages SHALL expose dedicated actions for mark toggling, delete flagging, clear marks, bulk copy/move/link operations, transform preview/apply, inline subdirectory insertion/collapse, and target-aware directory-buffer actions. These actions SHALL be defined through the shared keymap contract rather than wrapper-local hardcoding.

#### Scenario: Main wrapper exposes Dired-inspired actions
- **WHEN** the main `hx` wrapper is built from Home Manager configuration
- **THEN** the helper executable and generated configuration include the new Dired-inspired directory-buffer actions

#### Scenario: Zen wrapper stays aligned with batch workflow
- **WHEN** the `zen` wrapper is built with directory-buffer support
- **THEN** it exposes a compatible set of directory-buffer batch actions backed by the same helper implementation

### Requirement: Automated checks cover Dired-inspired workflow additions
The change SHALL include automated coverage for mark/flag state, bulk operation planning, DWIM target resolution, transform preview behavior, inline subdirectory insertion/collapse, and wrapper integration.

#### Scenario: Helper tests cover marks, targets, and transforms
- **WHEN** helper tests run
- **THEN** they verify marks vs flags, target resolution, copy/move/link planning, transform preview/collision rejection, and inline subtree behavior

#### Scenario: Nix integration checks cover new wrapper actions
- **WHEN** repo checks evaluate the wrapped Helix configuration
- **THEN** they verify that generated `hx` and `zen` configuration includes the new Dired-inspired helper actions and expected manifest workflow wiring
