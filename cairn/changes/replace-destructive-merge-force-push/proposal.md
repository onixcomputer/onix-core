## Why

`merge-when-green` unconditionally pushes `HEAD` to the selected remote branch with `--force`. On an existing feature branch this can overwrite commits added by another actor after the local checkout last observed the branch, with no lease check or explicit operator consent.

## What Changes

- Remove unconditional force-push behavior from the default workflow.
- Use fast-forward pushes when possible and an explicit, observed-remote lease for intentional rewritten history.
- Refuse stale or unobserved remote updates with a clear recovery diagnostic.
- Add command-construction and temporary-repository tests for safe and stale branch cases.

## Impact

- **Files**: `pkgs/merge-when-green/merge-when-green.py` and its tests/documentation.
- **Risk**: Rebased branches may require an explicit lease-enabled option instead of being silently overwritten.
- **Non-goals**: Do not implement force-push without a lease or automatically discard remote-only commits.
- **Testing**: Cover new branches, fast-forward updates, explicit lease success, stale lease rejection, and absence of bare `--force`.
