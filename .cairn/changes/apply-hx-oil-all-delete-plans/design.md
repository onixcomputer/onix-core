## Context

`build_apply_plans` groups only entries that are not delete-flagged. The grouped map therefore lacks a root or subdirectory key when that scope's edited final state is empty. Since `build_plan` is never called, the original snapshot is not converted into delete operations.

## Decisions

### 1. Inventory scopes before filtering entries

**Choice:** Build the scope set from the document and sidecar first, initialize each represented scope with an empty edited list, and then append only retained entries.

**Rationale:** An empty list is meaningful final state, not absence of an edit.

### 2. Reuse the existing pure hunk planner

**Choice:** Call `build_plan` with the original snapshot and empty edited entries. Existing hunk logic will produce deletes for all originals.

**Rationale:** This keeps the fix in the functional core and avoids a second deletion algorithm.

### 3. Preserve safety checks before mutation

**Choice:** All generated plans must pass stale-snapshot, duplicate/path, target, and empty-directory validation before any scope executes.

**Rationale:** Making all-delete effective must not bypass the refusal to remove non-empty directories.

### 4. Cover root and inline-subdirectory semantics

**Choice:** Tests will exercise a root with only delete flags, a represented inserted subdirectory with only delete flags, and documents with no actual entries.

**Rationale:** The existing special-case subdirectory deletion logic should not mask root-scope behavior or create duplicate operations.

## Risks / Trade-offs

- Applying an old manifest that previously no-op'd will now honor its visible delete flags.
- Multi-scope execution remains non-transactional and is outside this narrow repair.
- Empty documents need a clear distinction between intentional final state and malformed manifest structure.
