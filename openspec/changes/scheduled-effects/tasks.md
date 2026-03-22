## 1. Secrets Infrastructure

- [x] 1.1 Add clan vars generator `onix-effects-secrets` on aspen1 — prompted for GitHub PAT, outputs SOPS-encrypted JSON in hercules-ci format (`{ "github": { "data": { "token": "..." } } }`)
- [x] 1.2 Wire `effects.perRepoSecretFiles` in buildbot clan module pointing `"github:onixcomputer/onix-core"` to the generated secret path
- [x] 1.3 Run `clan vars generate --machine aspen1` and provide the fine-grained PAT (scoped to onix-core with `contents:write` + `pull_requests:write`)

## 2. Effect Derivation

- [x] 2.1 Create `flake-outputs/effects.nix` with the `herculesCI` function skeleton — accept args, return `onSchedule` attrset
- [x] 2.2 Implement the `flake-update` schedule with `when = { hour = [ 4 ]; dayOfWeek = [ "Mon" "Thu" ]; }`
- [x] 2.3 Write the update effect derivation — uses `hci-effects.flakeUpdate` from hercules-ci-effects (handles clone, update, commit, diff, push, dedup, PR creation)
- [x] 2.4 Dedup handled by `hci-effects.flakeUpdate` via branch-based approach (`auto/flake-update` branch, `baseMergeMethod = "reset"`)
- [x] 2.5 Eval pre-check skipped — `hci-effects.flakeUpdate` doesn't support it natively, and buildbot's eval workers handle this with proper memory limits
- [x] 2.6 Branch push handled by `hci-effects.flakeUpdate` (`updateBranch = "auto/flake-update"`)
- [x] 2.7 PR creation handled by `hci-effects.flakeUpdate` (`createPullRequest = true`, custom title and body)

## 3. Flake Integration

- [x] 3.1 Merge `flake-outputs/effects.nix` into the `flake` attrset in `flake.nix` (herculesCI is a top-level output)
- [x] 3.2 Verified `nix eval .#herculesCI --apply '...'` returns `["flake-update"]` and effect derivation evaluates to a store path

## 4. Validation

- [x] 4.1 Deployed to aspen1 (`clan machines update aspen1`) — buildbot-master restarted cleanly, secret deployed
- [x] 4.2 Confirmed buildbot registered `onixcomputer-onix-core-scheduled-flake-update-update` (schedulerid 149) via `/api/v2/schedulers`
- [x] 4.3 Pushed to main — buildbot-nix created the Nightly scheduler
- [x] 4.4 Manual test run succeeded — PR #27 created at https://github.com/onixcomputer/onix-core/pull/27 with 16 input updates
- [ ] 4.5 Confirm merge-when-green picks up the PR and auto-merges after buildbot checks pass
