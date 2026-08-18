## Context

The workflow rebases local history and then always executes `git push --force origin HEAD:<branch>`. A bare force push provides no compare-and-swap protection against a remote branch update that occurred after local preparation.

## Decisions

### 1. Make safe push intent explicit

**Choice:** A pure command builder will choose among new-branch push, fast-forward push, and lease-protected rewritten-history push. It will never emit bare `--force`.

**Rationale:** Command policy can be exhaustively unit-tested without touching a remote repository.

### 2. Observe the remote object before any rewrite

**Choice:** The shell will fetch or query the target branch OID. A rewritten push, when explicitly permitted, will use `--force-with-lease=<branch>:<observed-oid>`.

**Rationale:** An exact lease fails if another actor updates the branch after observation.

### 3. Default existing feature branches to non-destructive failure

**Choice:** Ordinary invocation attempts a normal push. If rebased history requires replacement, the tool exits with instructions unless the operator supplied an explicit lease-enabled option.

**Rationale:** History destruction should not be an implicit side effect of asking for auto-merge.

### 4. Isolate generated default-branch work

**Choice:** Generated branches remain in the tool-owned namespace and still use observed leases when updated. Existing open PR state must not weaken the lease requirement.

**Rationale:** A predictable generated name can also have concurrent or stale remote state.

## Risks / Trade-offs

- The workflow gains an explicit recovery step for rebased feature branches.
- A lease protects against unseen updates but does not assess whether the rewritten commits are semantically correct.
- Temporary-repository tests cover Git behavior locally; hosted-provider behavior remains separately tested.
