## Phase 0: Restore current-route continuity

- [x] [serial] Add and lock a separate immutable legacy Kiln executor input for the existing broker. r[onix.radicle_ci.aspen_continuity]
- [x] [serial] Bind the broker command and focused checks to the legacy input while the Aspen cohort remains separate. r[onix.radicle_ci.aspen_continuity]
- [x] [serial] Deploy the continuity fix and run one exact legacy broker event before further cutover work. r[onix.radicle_ci.aspen_continuity]

## Phase 1: Admit the production cohort

- [x] [serial] Pin the published durable Kiln Aspen host and bounded Radicle provider revisions. r[onix.radicle_ci.aspen_composition]
- [x] [serial] Add typed production settings and negative fixtures for users, paths, bounds, source identity, workflow identity, and rollback. r[onix.radicle_ci.aspen_composition]
- [ ] [serial] Deploy separate production host and Lattice users, state roots, sockets, ordering, resource limits, and restart policy. r[onix.radicle_ci.aspen_composition]
- [ ] [serial] Expose only the exact read-only Seaglass source view and writable report root to the provider workflow. r[onix.radicle_ci.aspen_authority]
- [ ] [serial] Prove that Radicle keys, node sockets, policy databases, unrelated repositories, home directories, and network authority remain unavailable. r[onix.radicle_ci.aspen_authority]

## Phase 2: Stage, observe, and cut over

- [ ] [serial] Import the exact production workflow and run direct shadow requests with status publication disabled. r[onix.radicle_ci.aspen_cutover]
- [ ] [serial] Run accepted, failed, unavailable, uncertain, duplicate, restart, corruption, teardown, and bounded-load shadow drills. r[onix.radicle_ci.aspen_evidence]
- [ ] [serial] Drain active broker adapters and record the durable queue boundary before switching commands. r[onix.radicle_ci.aspen_cutover]
- [ ] [serial] Change the single broker adapter composition to explicit Defelo-over-Aspen with no fallback. r[onix.radicle_ci.aspen_cutover]
- [ ] [serial] Run one real private Radicle default-branch event through the broker, Aspen host, Lattice workflow, Nix provider, report server, and Radicle status path. r[onix.radicle_ci.aspen_evidence]
- [ ] [serial] Replay the exact event after service restart and prove no second provider dispatch. r[onix.radicle_ci.aspen_evidence]

## Phase 3: Rollback, operations, and closeout

- [ ] [serial] Add production alerts, bounded status, backup/restore, upgrade, rollback, and incident procedures. r[onix.radicle_ci.aspen_operations]
- [ ] [serial] Exercise explicit legacy rollback without automatic failover or duplicate execution. r[onix.radicle_ci.aspen_operations]
- [ ] [serial] Restore the Aspen route, retain exact receipts, and record all non-claims and unrelated host warnings. r[onix.radicle_ci.aspen_evidence]
- [ ] [serial] Run focused Nix/Nickel checks, full machine evaluation, managed deployment checks, and strict Cairn validation. r[onix.radicle_ci.aspen_evidence]
- [ ] [serial] Sync and archive only after every live production gate passes. r[onix.radicle_ci.aspen_evidence]
