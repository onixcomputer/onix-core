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
