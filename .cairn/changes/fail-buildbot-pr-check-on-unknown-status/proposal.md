## Why

`buildbot-pr-check` documents exit code zero as "all builds passed successfully", yet discovery failures, unreachable APIs, absent Buildbot links, pending requests, and some exceptional statuses can currently produce zero. This makes the tool unsafe as a CI gate because inability to verify is reported as success.

## What Changes

- Define distinct verified-success, verified-failure, and indeterminate/tool-error outcomes.
- Return success only when every required parent and triggered build has a terminal accepted status.
- Propagate discovery, HTTP, parse, pending, retry, and unknown-status conditions as nonzero outcomes.
- Make the reusable `check_pr` function return an outcome instead of exiting internally.
- Restore deterministic offline tests for positive and negative outcomes.

## Impact

- **Files**: `pkgs/buildbot-pr-check/buildbot_pr_check/`, package metadata, tests, and README exit-code documentation.
- **Risk**: Automation that treated missing CI evidence as success will begin failing, as intended.
- **Non-goals**: Do not change Buildbot itself or infer success from GitHub/Gitea status text without verified Buildbot data.
- **Testing**: Replay successful and failed cassettes; inject unavailable, malformed, pending, retry, exception, and no-build responses.
