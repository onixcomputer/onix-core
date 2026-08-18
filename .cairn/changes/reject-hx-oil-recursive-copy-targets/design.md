## Context

Bulk planning validates destination collisions but not source/destination ancestry. For a selected directory and a target beneath that directory, the computed destination is also beneath the source. Recursive execution creates that destination and then walks the source, causing the copy to encounter its own output.

## Decisions

### 1. Add a pure canonical ancestry predicate

**Choice:** Introduce a deterministic helper that compares normalized absolute source and destination paths by path components and reports equality or descendant relationships.

**Rationale:** String-prefix checks are incorrect for sibling names such as `src` and `src-old`. Component comparison is testable without filesystem mutation after the shell resolves existing paths.

### 2. Validate every planned directory copy before execution

**Choice:** `build_bulk_plan` will reject any directory-copy item whose destination is equal to or nested under its source. Planning must finish successfully for every item before `execute_bulk_plan` runs.

**Rationale:** Rejecting after the first copy would still permit partial mutation.

### 3. Resolve symlinked roots at the shell boundary

**Choice:** Existing source and target roots will be canonicalized before pure ancestry comparison. Missing destinations remain represented by joining their final component to a canonical parent.

**Rationale:** A textual sibling can resolve through a symlink into the source tree.

### 4. Preserve non-recursive operations

**Choice:** Valid sibling/external copies remain unchanged. Move and symlink operations receive shared ancestry checks only where their own semantics can create an unsafe self-reference.

**Rationale:** The fix should be narrow and should not reject harmless links merely because their targets refer to source content.

## Risks / Trade-offs

- Canonicalization can fail for missing parents; the diagnostic must identify the unresolved target.
- Filesystem state can race after planning, so execution remains fallible even after validation.
- The change prevents recursive self-copy but does not make multi-item copy transactional.
