## Why

Several repository checks currently provide false confidence: Buildbot tests are disabled and fail when run, the static-server VM test reimplements rather than imports the production module, plain pytest discovers duplicate tests under Pi worktrees, and the strict mypy configuration reports extensive errors without an authoritative clean gate.

## What Changes

- Restore and enable hermetic Buildbot package tests.
- Make static-server integration coverage instantiate the real Clan/NixOS module.
- Bound Python test discovery so ignored agent worktrees and build outputs cannot duplicate modules.
- Establish a clean, explicit type-check scope and enforce it in repository checks.
- Ensure positive and negative tests are represented in the flake check graph.

## Impact

- **Files**: root `pyproject.toml`, Python package exports/tests, Nix package checks, VM tests, and `flake-outputs/dev-env.nix`/check wiring.
- **Risk**: The authoritative gate will initially expose existing failures that must be repaired before it can pass.
- **Non-goals**: Do not type-check generated or intentionally excluded third-party files.
- **Testing**: Run root and package pytest from a Pi-enabled checkout, run mypy over the declared scope, build package checks, and prove the VM test observes production module behavior.
