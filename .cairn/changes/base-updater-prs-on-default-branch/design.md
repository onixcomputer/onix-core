## Context

`git worktree add -b <update-branch> <path>` uses the caller's current `HEAD` when no start point is supplied. The updater later commits all worktree changes and pushes the branch, so unrelated ancestry is not filtered out by the changed-file set.

## Decisions

### 1. Resolve a single authoritative PR base

**Choice:** Determine the remote default branch from `refs/remotes/origin/HEAD`, with a bounded provider fallback only when needed. Fetch that branch and record its commit OID before creating any worktree.

**Rationale:** An explicit remote commit avoids dependence on the caller's checkout and avoids racing a moving symbolic name during later validation.

### 2. Create worktrees from the observed base OID

**Choice:** Pass the recorded base commit as the final `git worktree add -b` argument. Keep package updates isolated in the temporary worktree.

**Rationale:** The resulting branch ancestry is deterministic even when invoked from a feature branch.

### 3. Verify ancestry and scope before publication

**Choice:** Before push, assert that the merge base with the recorded default is that base and that the committed diff is limited to expected updater outputs for the selected package plus explicitly allowed lock files.

**Rationale:** Base selection prevents unrelated commits; scope validation prevents custom update scripts from publishing unrelated file changes.

### 4. Fail closed on unresolved or stale bases

**Choice:** Missing origin, missing default-branch metadata, fetch failure, or changed remote base before publication produces a nonzero result and no push/PR action.

**Rationale:** Guessing `main` or continuing with stale ancestry recreates the original failure mode.

## Risks / Trade-offs

- Repositories without an `origin` default branch require explicit setup.
- Custom update scripts with legitimate cross-package edits need a reviewed allowlist mechanism.
- The updater still depends on provider CLI availability for final PR creation.
