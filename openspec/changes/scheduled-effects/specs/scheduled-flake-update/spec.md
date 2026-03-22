## ADDED Requirements

### Requirement: herculesCI flake output
The flake SHALL export a `herculesCI` function that buildbot-nix can evaluate to discover `onSchedule` blocks. The function SHALL accept the standard hercules-ci args (`{ branch, rev, shortRev, name, tag, remoteHttpUrl, primaryRepo }`).

#### Scenario: Buildbot discovers scheduled effects
- **WHEN** buildbot-nix evaluates the flake's `herculesCI` output after a push to main
- **THEN** it SHALL find the `onSchedule.flake-update` block and create a Buildbot `Nightly` scheduler

#### Scenario: No effects on non-main branches
- **WHEN** buildbot-nix evaluates the `herculesCI` output for a branch other than `main`
- **THEN** the `onSchedule` block SHALL still be present (schedules are discovered from any eval, but only run against the default branch)

### Requirement: Scheduled flake-update trigger
The `onSchedule.flake-update` block SHALL define a `when` schedule that triggers the update effect twice per week at 04:00 UTC.

#### Scenario: Schedule fires on Monday
- **WHEN** the Buildbot Nightly scheduler reaches Monday 04:00 UTC
- **THEN** the `flake-update` effect SHALL be triggered against the repo's default branch

#### Scenario: Schedule fires on Thursday
- **WHEN** the Buildbot Nightly scheduler reaches Thursday 04:00 UTC
- **THEN** the `flake-update` effect SHALL be triggered against the repo's default branch

### Requirement: Flake lock update
The update effect SHALL clone the repository, run `nix flake update`, and detect whether `flake.lock` changed.

#### Scenario: Inputs have updates available
- **WHEN** the effect runs `nix flake update` and `flake.lock` differs from main
- **THEN** the effect SHALL proceed to push a branch and create a PR

#### Scenario: No updates available
- **WHEN** the effect runs `nix flake update` and `flake.lock` is unchanged
- **THEN** the effect SHALL exit successfully without pushing or creating a PR

### Requirement: Branch creation and push
The effect SHALL create a git branch named `auto/flake-update-YYYYMMDD` and push it to the origin remote using the GitHub PAT for authentication.

#### Scenario: Branch pushed successfully
- **WHEN** `flake.lock` has changed and no branch with the same name exists
- **THEN** the effect SHALL push the branch with a commit message `flake.lock: scheduled update YYYY-MM-DD`

#### Scenario: Branch already exists
- **WHEN** a branch named `auto/flake-update-YYYYMMDD` already exists on the remote
- **THEN** the effect SHALL exit successfully without pushing a duplicate branch

### Requirement: Pull request creation
The effect SHALL create a GitHub pull request via the REST API from the update branch to `main`.

#### Scenario: PR created successfully
- **WHEN** the branch is pushed and no open PR exists from that branch
- **THEN** the effect SHALL create a PR with title `flake.lock: scheduled update YYYY-MM-DD` and a body describing the automated update

#### Scenario: PR already exists
- **WHEN** an open PR from the same branch already exists
- **THEN** the effect SHALL exit successfully without creating a duplicate PR

### Requirement: Eval pre-check
The effect SHALL run `nix flake check --no-build` after updating `flake.lock` as a fast eval sanity check.

#### Scenario: Eval succeeds
- **WHEN** `nix flake check --no-build` exits 0
- **THEN** the effect SHALL proceed normally and the PR body SHALL NOT contain a warning

#### Scenario: Eval fails
- **WHEN** `nix flake check --no-build` exits non-zero
- **THEN** the effect SHALL still push the branch and create the PR, but the PR body SHALL include a warning that eval failed

### Requirement: Effects secrets management
The buildbot master SHALL provide a secrets file for the onix-core repo via `effects.perRepoSecretFiles`. The secret SHALL be generated via a clan vars generator and contain a GitHub PAT in the hercules-ci JSON format.

#### Scenario: Secret available to effect
- **WHEN** the scheduled effect runs inside bubblewrap
- **THEN** the GitHub PAT SHALL be readable from `$HERCULES_CI_SECRETS_JSON` at path `.github.data.token`

#### Scenario: Secret generated via clan vars
- **WHEN** `clan vars generate --machine aspen1` is run
- **THEN** the operator SHALL be prompted for the GitHub PAT, and it SHALL be SOPS-encrypted and stored in the vars tree
