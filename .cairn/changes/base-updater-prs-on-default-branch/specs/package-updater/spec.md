# Package Updater PR Isolation Specification Delta

## Purpose

Ensure automated package-update branches originate from an observed remote default branch and contain only intended update changes.

## ADDED Requirements

### Requirement: Update PR branches use the remote default base

r[onix.updater.pr.base] The updater MUST create each PR worktree branch from a fetched, observed commit of the remote default branch rather than the caller's current `HEAD`.

#### Scenario: Invocation from a feature branch remains isolated

r[onix.updater.pr.base.feature]
- GIVEN the caller is on a feature branch containing commits absent from the remote default branch
- WHEN PR mode creates an update worktree
- THEN the update branch starts at the observed remote default commit
- AND the feature-only commits are absent from the update branch

#### Scenario: Default branch metadata is unavailable

r[onix.updater.pr.base.missing]
- GIVEN the updater cannot resolve or fetch the remote default branch
- WHEN PR mode starts
- THEN it MUST fail before creating or pushing an update branch
- AND it MUST NOT guess a branch name or use current `HEAD`

### Requirement: Update PR ancestry and scope are verified

r[onix.updater.pr.scope] Before publication, the updater MUST verify that the update branch descends from the recorded base and that its diff is limited to reviewed outputs for the selected package and allowed lock files.

#### Scenario: Clean package update passes scope validation

r[onix.updater.pr.scope.positive]
- GIVEN an update branch contains only the selected package changes and allowed lock-file updates
- WHEN the pre-publication check runs
- THEN ancestry and scope validation pass
- AND publication may proceed

#### Scenario: Unrelated file change fails scope validation

r[onix.updater.pr.scope.negative]
- GIVEN a custom updater changes a file outside the selected package and allowed update set
- WHEN the pre-publication check runs
- THEN validation MUST fail
- AND no push or PR creation command is executed

### Requirement: PR isolation is covered by local repository tests

r[onix.updater.pr.validation] The updater test suite MUST include positive and negative temporary-Git-repository cases without contacting a hosted provider.

#### Scenario: Feature-branch regression test runs

r[onix.updater.pr.validation.feature]
- GIVEN a temporary origin with distinct default and feature histories
- WHEN the updater's worktree planner is exercised from the feature branch
- THEN the resulting planned base equals the remote default object
- AND a missing or stale base case fails closed
