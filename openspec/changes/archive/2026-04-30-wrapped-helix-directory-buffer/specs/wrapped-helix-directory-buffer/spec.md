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
