## Context

`britton-desktop` currently runs the Seaglass Radicle broker as user `radicle`. The broker admits one private RID and invokes the historical direct Kiln Nix executor. The Aspen canary runs under separate host and Lattice users with no Radicle authority, no broker events, and a marker workflow.

Onix Core now pins Kiln host revision `69c0a6ac454d7291e4aed12fd72a6f2c31636e76`. That revision requires explicit `--profile` and `--runtime` arguments. The live broker still has the old environment-only command shape. This is a latent continuity defect even though the broker process itself is active.

## Search contract

**Goal:** route the admitted private Seaglass broker events through the durable Kiln Aspen host and real Lattice build workflow without automatic fallback.

**Completion evidence:** restored legacy continuity during staging, immutable production cohort, separate authority, exact source view, real broker event and build report, failure and uncertainty receipts, duplicate suppression, restart recovery, bounded load, backup/restore, observability, explicit rollback, and archived Cairn evidence.

**False completion:** an operator fixture, direct adapter invocation that bypasses the broker, a marker workflow, a successful service state without a real build, dual publication from shadow traffic, automatic fallback, or receipts from the previous route.

**Audit risks:** lost or duplicated broker events, duplicate builds, source or revision substitution, Radicle key exposure, report corruption, socket cross-authority, active-job cutover, rollback drift, stale profile identity, and unrelated repository admission.

**Budget:** four mechanism families, two search rounds, current repository sources and bounded live host facts, and deterministic Nix/Cairn/live validators as final authority.

## Approach registry

| Family | Mechanism | State | Evidence or blocker |
|---|---|---|---|
| In-place canary command switch | Point the broker at the existing canary socket | Falsified | The workflow is a marker and the canary host has process-local state. |
| Direct broker wrapper | Keep Nix in the broker and call Aspen only for admission | Falsified | The real effect bypasses Lattice and does not prove hosted execution. |
| Shared Radicle identity | Run Lattice as `radicle` | Falsified | It grants node state and key authority outside the workflow contract. |
| Parallel production cohort | Restore legacy continuity, stage a separate durable host, shadow without publication, then switch one broker command | Selected | It gives exact rollback and preserves authority boundaries. |

The passes are serial and correlated because no subagent consent was granted.

## Decisions

### Decision: Restore the old route before production work

**Choice:** Add a separate immutable legacy Kiln input for the broker. Keep the Aspen host input independent.

**Rationale:** A long production change must not leave the existing broker coupled to an incompatible CLI revision.

### Decision: Deploy a separate production cohort

**Choice:** Keep `kiln-aspen-canary` unchanged. Add a production instance with distinct users, state roots, sockets, workflow identity, report root, and service ordering.

**Rationale:** Canary evidence and production authority must remain distinguishable. Rollback must not depend on mutating canary state.

### Decision: Expose only the admitted source view

**Choice:** Materialize or mount one read-only view of the exact Seaglass bare repository outside `/var/lib/radicle`. The production workflow receives no Radicle keys, node socket, policy database, or unrelated repository path.

**Rationale:** The Lattice effect needs source bytes, not Radicle identity or mutation authority.

### Decision: Cut over one explicit composition root

**Choice:** Change only the broker adapter command after shadow gates pass. It will use Defelo input compatibility and explicit Aspen runtime arguments. Missing Aspen state fails the job. It never invokes the legacy adapter automatically.

**Rationale:** The broker remains the event and status owner. Kiln remains the CI semantics owner. Aspen remains the runtime substrate. Lattice remains the workflow executor.

### Decision: Keep rollback manual and exact

**Choice:** Install an operator-only rollback unit or configuration switch that selects the separately pinned legacy adapter. Do not inspect failures to select it automatically.

**Rationale:** Unknown provider acceptance cannot safely trigger another execution path.

## Risks / Trade-offs

- The production route remains one-machine and does not prove global availability.
- A source view grants read access to one private repository and requires explicit review.
- Cutover must wait for zero active broker adapters and a durable queue boundary.
- The existing Kache quota warnings remain outside this change but can still affect builds.
