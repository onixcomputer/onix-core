## Why

The package updater creates its temporary PR branch without an explicit start point, so Git bases it on whatever `HEAD` the operator currently has checked out. Running PR mode from a feature branch can therefore include unrelated commits in an automated package-update pull request.

## What Changes

- Resolve and fetch the remote default branch before creating an update worktree.
- Create every update branch from the observed `origin/<default>` commit, independent of the caller's current branch.
- Verify ancestry and changed-path scope before push or PR creation.
- Add isolated temporary-repository tests for default-branch and feature-branch invocation.

## Impact

- **Files**: `pkgs/updater/__main__.py`, new updater tests, package check wiring, and operator documentation.
- **Risk**: PR mode will fail when the remote default branch cannot be resolved or fetched instead of guessing a base.
- **Non-goals**: Do not open or update an existing remote PR branch implicitly.
- **Testing**: Cover invocation from default and feature branches, missing origin/default metadata, fetch failure, unrelated ancestry, and clean update-only diffs.
