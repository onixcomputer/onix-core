## Phase 1: Outcome model

- [ ] [serial] Introduce pure build-outcome and aggregate-result types for verified success, CI failure, and indeterminate state. r[onix.buildbot_pr_check.core]
- [ ] [serial] Reserve exit zero for non-empty complete terminal success and map explicit CI failures to the failure exit. r[onix.buildbot_pr_check.exit_contract]
- [ ] [serial] Propagate absent builds, pending/retry/unknown statuses, timeouts, HTTP failures, and parse failures as nonzero indeterminate results. r[onix.buildbot_pr_check.indeterminate]
- [ ] [serial] Make `check_pr` return a structured result and keep printing/process exit in `main`. r[onix.buildbot_pr_check.core]
- [ ] [serial] Add bounded HTTP timeouts and preserve provider/Buildbot errors instead of empty collections. r[onix.buildbot_pr_check.indeterminate]
- [ ] [serial] Update README exit-code and CI-integration documentation. r[onix.buildbot_pr_check.exit_contract]

## Phase 2: Validation

- [ ] [serial] Repair the public package export and hermetic cassette/test setup. r[onix.buildbot_pr_check.validation]
- [ ] [serial] Add positive tests for complete successful parent and triggered builds. r[onix.buildbot_pr_check.validation]
- [ ] [serial] Add negative tests for failure, exception, cancellation, no builds, pending, retry, malformed, timeout, and unreachable APIs. r[onix.buildbot_pr_check.validation]
- [ ] [serial] Enable package checks and run focused pytest, Nix package build, Cairn validation, and gates. r[onix.buildbot_pr_check.validation]
