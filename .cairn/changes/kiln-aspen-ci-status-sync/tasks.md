# Tasks: Kiln Aspen CI status sync

## Phase 0: Implement the bounded status sync

- [ ] [serial] Add the status-sync path unit watching the bot namespace signed-refs file and the oneshot service running one bounded sync for the admitted repository. r[onix.radicle_ci.status_sync]
- [ ] [serial] Restrict the sync oneshot to unix address families with the radicle user, pinned state directory, runtime bound, and no network authority. r[onix.radicle_ci.status_sync.unix_only]
- [ ] [serial] Extend the module checks to assert the watched path, the repository argument, the unix-only address families, and the bounded runtime. r[onix.radicle_ci.status_sync.scoped]
- [ ] [serial] Document the announce limitation, the manual remedy, and the CLI profile repair procedure in the module README. r[onix.radicle_ci.status_sync.visible]

## Phase 1: Validate, deploy, and verify live

- [ ] [serial] Validate the offline module checks, machine evaluation, and strict Cairn validation before deployment. r[onix.radicle_ci.status_sync.bounded]
- [ ] [serial] Deploy through the pinned Clan wrapper with the production preflight, then verify one live CI event propagates to the owner node without operator action. r[onix.radicle_ci.status_sync]
- [ ] [serial] Sync and archive only after the live propagation evidence passes. r[onix.radicle_ci.status_sync]
