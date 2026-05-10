## Phase 1: Cache routing policy

- [x] [serial] Write the OpenSpec package for desktop substituter and remote-builder routing.
- [ ] [serial] Implement a deduplicated `britton-desktop` substituter order with documented local-cache placement.
- [ ] [serial] Review trusted substituter/trusted-key settings touched by the cache-routing change.
- [ ] [parallel] Document the remote-builder-only workflow for heavyweight builds.

## Phase 2: Verification

- [ ] [depends:desktop-cache.substituter-order] Evaluate resolved substituters and assert no duplicates.
- [ ] [depends:desktop-cache.trust-policy] Inspect trusted substituter settings for unintended additions.
- [ ] [depends:desktop-cache.remote-only-builds] Run or document a remote-only probe result with `--max-jobs 0`.
- [ ] [depends:phase-1] Build the affected `britton-desktop` configuration.
