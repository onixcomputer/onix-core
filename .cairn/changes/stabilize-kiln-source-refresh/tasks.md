# Tasks: Stabilize Kiln source refresh

## Phase 1: Reproduce and specify

- [x] [serial] T1.1 Record the live `unit-start-limit-hit` state, repeated successful refresh starts, and provider source-readiness failure. r[onix.radicle_ci.aspen_authority.refresh_quiescence]
- [x] [serial] T1.2 Add the proposal, design, tasks, and delta requirement for bounded refresh quiescence. r[onix.radicle_ci.aspen_authority.refresh_quiescence]

## Phase 2: Implement idempotent ACL admission

- [x] [serial] T2.1 Inspect directory and file ACLs before mutation. r[onix.radicle_ci.aspen_authority.refresh_quiescence]
- [x] [serial] T2.2 Preserve the existing source path, file-type, symlink, group, and capability boundaries. r[onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.missing-entry]

## Phase 3: Add regression checks

- [x] [serial] T3.1 Require the idempotent ACL inspection path in the focused module check. r[onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.current]
- [x] [serial] T3.2 Reject the prior unconditional recursive `setfacl` form. r[onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.self-trigger]
- [x] [serial] T3.3 Run focused module, machine, formatting, and Cairn gates. r[onix.radicle_ci.aspen_authority.refresh_quiescence]

## Phase 4: Deploy and replay

- [ ] [serial] T4.1 Deploy the reviewed system closure to `britton-desktop`. r[onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.current]
- [ ] [serial] T4.2 Reset and start the source-refresh service and path. r[onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.current]
- [ ] [serial] T4.3 Replay the blocked Seaglass revision and observe source visibility, terminal status, report publication, and an empty queue. r[onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.missing-entry]

## Phase 5: Closeout

- [ ] [serial] T5.1 Record bounded verification evidence and sync the accepted spec. r[onix.radicle_ci.aspen_authority.refresh_quiescence]
- [ ] [serial] T5.2 Archive only after the deployed path remains active and the replay completes without source-readiness exhaustion. r[onix.radicle_ci.aspen_authority.refresh_quiescence.scenario.self-trigger]
