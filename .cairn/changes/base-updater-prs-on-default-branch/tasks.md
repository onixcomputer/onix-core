## Phase 1: Base and scope isolation

- [ ] [serial] Add pure parsing/selection logic for an observed remote default branch and commit. r[onix.updater.pr.base]
- [ ] [serial] Fetch the remote default branch and create update worktrees from its recorded commit rather than current `HEAD`. r[onix.updater.pr.base]
- [ ] [serial] Fail before mutation when origin/default resolution or fetch cannot establish a base. r[onix.updater.pr.base]
- [ ] [serial] Validate update-branch ancestry against the recorded base before publication. r[onix.updater.pr.scope]
- [ ] [serial] Validate changed paths against the selected package and reviewed lock-file allowlist. r[onix.updater.pr.scope]
- [ ] [serial] Prevent push and PR commands after any ancestry or scope failure. r[onix.updater.pr.scope]

## Phase 2: Validation

- [ ] [serial] Add positive temporary-repository tests when invoked from default and feature branches. r[onix.updater.pr.validation]
- [ ] [serial] Add negative tests for missing origin, unresolved default branch, fetch failure, stale base, and unrelated file changes. r[onix.updater.pr.validation]
- [ ] [serial] Enable updater package tests without contacting hosted providers. r[onix.updater.pr.validation]
- [ ] [serial] Run focused pytest/package checks plus Cairn validation and gates. r[onix.updater.pr.validation]
