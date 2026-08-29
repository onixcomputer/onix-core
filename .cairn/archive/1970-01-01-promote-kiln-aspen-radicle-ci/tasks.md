## Phase 0: Restore current-route continuity

- [x] [serial] Add and lock a separate immutable legacy Kiln executor input for the existing broker. r[onix.radicle_ci.aspen_continuity]
- [x] [serial] Bind the broker command and focused checks to the legacy input while the Aspen cohort remains separate. r[onix.radicle_ci.aspen_continuity]
- [x] [serial] Deploy the continuity fix and run one exact legacy broker event before further cutover work. r[onix.radicle_ci.aspen_continuity]

## Phase 1: Admit the production cohort

- [x] [serial] Pin the published durable Kiln Aspen host and bounded Radicle provider revisions. r[onix.radicle_ci.aspen_composition]
- [x] [serial] Add typed production settings and negative fixtures for users, paths, bounds, source identity, workflow identity, and rollback. r[onix.radicle_ci.aspen_composition]
- [x] [serial] Deploy separate production host and Lattice users, state roots, sockets, ordering, resource limits, and restart policy. r[onix.radicle_ci.aspen_composition]
- [x] [serial] Expose only the exact read-only Seaglass source view and writable report root to the provider workflow. r[onix.radicle_ci.aspen_authority]
- [x] [serial] Prove that Radicle keys, node sockets, policy databases, unrelated repositories, home directories, and network authority remain unavailable. r[onix.radicle_ci.aspen_authority]
- [x] [serial] Wait within a finite bound for the exact event revision to become visible without fetching or widening source authority. r[onix.radicle_ci.aspen_authority.source_readiness]

## Phase 2: Stage, observe, and cut over

- [x] [serial] Import the exact production workflow and run direct shadow requests with status publication disabled. r[onix.radicle_ci.aspen_cutover]
- [x] [serial] Run accepted, failed, unavailable, uncertain, duplicate, restart, corruption, teardown, and bounded-load shadow drills. r[onix.radicle_ci.aspen_evidence]
- [x] [serial] Drain active broker adapters and record the durable queue boundary before switching commands. r[onix.radicle_ci.aspen_cutover]
- [x] [serial] Change the single broker adapter composition to explicit Defelo-over-Aspen with no fallback. r[onix.radicle_ci.aspen_cutover]
- [x] [serial] Run one real private Radicle default-branch event through the broker, Aspen host, Lattice workflow, Nix provider, report server, and Radicle status path. r[onix.radicle_ci.aspen_evidence]
- [x] [serial] Replay the exact event after service restart and prove no second provider dispatch. r[onix.radicle_ci.aspen_evidence]

## Phase 3: Rollback, operations, and closeout

- [x] [serial] Add production alerts, bounded status, backup/restore, upgrade, rollback, and incident procedures. r[onix.radicle_ci.aspen_operations]
- [x] [serial] Exercise explicit legacy rollback without automatic failover or duplicate execution. r[onix.radicle_ci.aspen_operations]
- [x] [serial] Restore the Aspen route, retain exact receipts, and record all non-claims and unrelated host warnings. r[onix.radicle_ci.aspen_evidence]
- [x] [serial] Run focused Nix/Nickel checks, full machine evaluation, managed deployment checks, and strict Cairn validation. r[onix.radicle_ci.aspen_evidence]
- [x] [serial] Sync and archive only after every live production gate passes. r[onix.radicle_ci.aspen_evidence]
