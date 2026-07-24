## Context

Build discovery functions commonly swallow network and parse errors into empty lists, while request checks map errors and in-progress results to `None`. The CLI then treats only a subset of explicit failure statuses as nonzero and exits successfully when discovery finds nothing. The library function also calls `sys.exit`, which prevents callers from composing or testing outcomes cleanly.

## Decisions

### 1. Define a pure aggregate outcome model

**Choice:** Represent each discovery/build result as verified success, verified CI failure, pending, or tool/error. A pure aggregator returns `SUCCESS`, `CI_FAILED`, or `INDETERMINATE` with reasons.

**Rationale:** Exit behavior becomes deterministic and testable without HTTP or process mocks.

### 2. Reserve exit zero for verified terminal success

**Choice:** Exit zero requires at least one required Buildbot build and terminal accepted status for every required parent and triggered request. CI failures use exit one; indeterminate discovery/tooling states use a distinct nonzero error exit.

**Rationale:** This matches the README's CI-integration claim and prevents false greens.

### 3. Preserve errors through the imperative shell

**Choice:** HTTP helpers will use bounded timeouts and return typed errors instead of empty collections. `check_pr` will return a structured result; only `main` will translate it to process output and exit status.

**Rationale:** Network I/O belongs in the shell, while policy over outcomes belongs in the functional core.

### 4. Make package tests hermetic and authoritative

**Choice:** Export the public callable expected by tests, repair cassette paths/imports, add synthetic negative fixtures, and enable package checks without live credentials or network access.

**Rationale:** Disabled integration tests allowed the false-success behavior to persist.

## Risks / Trade-offs

- Pending builds will no longer look successful to scripts that use this command as a gate.
- Buildbot result codes need an explicit policy for warnings and skipped builds.
- Recorded cassettes can age; small synthetic unit fixtures should own outcome-policy coverage.
