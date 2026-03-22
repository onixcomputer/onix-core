## Why

The onix-core flake has 13+ inputs (nixpkgs, clan-core, home-manager, sops-nix, disko, buildbot-nix, etc.) that drift stale between manual `nix flake update` runs. Stale inputs accumulate breakage risk — the longer between updates, the harder it is to bisect which input caused a failure. There's no automated way to keep inputs current, verify they build, and land them on main. The existing `update-prefetch` + `merge-when-green` pipeline handles the last mile (deploy after merge), but nothing feeds it.

buildbot-nix supports hercules-ci-compatible effects (`onPush` and `onSchedule`) that run impure steps with network access and secrets — exactly what's needed for git operations, GitHub API calls, and flake updates. Adding a `herculesCI` output to the flake closes the automation loop: scheduled update → buildbot verify → merge-when-green → update-prefetch → deploy.

## What Changes

- Add a `herculesCI` flake output that defines scheduled effects via `onSchedule`
- Implement a `flake-update` scheduled effect that runs 2x/week, updates `flake.lock`, pushes a branch, and opens a PR via the GitHub API
- Add a clan vars generator for the effects secret (GitHub PAT) on aspen1
- Wire `effects.perRepoSecretFiles` into the existing buildbot master config for the onix-core repo
- Add the `herculesCI.nix` module to the flake's output composition

## Capabilities

### New Capabilities
- `scheduled-flake-update`: Automated flake.lock updates via buildbot-nix scheduled effects — cron-triggered `nix flake update`, branch push, and PR creation with GitHub API secrets management

### Modified Capabilities

## Impact

- `flake.nix` — new module import for `herculesCI` output
- `machines/aspen1/buildbot.nix` — new `effects.perRepoSecretFiles` entry and vars generator for the GitHub PAT secret
- New file `herculesCI.nix` (or `flake-outputs/effects.nix`) defining the `herculesCI` function
- GitHub: a PAT or GitHub App token with `repo` scope is required for branch push + PR creation
- Buildbot: after first push to main with the new output, buildbot-nix will discover the `onSchedule` block and create a `Nightly` scheduler automatically
