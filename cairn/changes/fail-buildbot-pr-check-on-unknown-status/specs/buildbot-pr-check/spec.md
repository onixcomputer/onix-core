# Buildbot PR Check Specification Delta

## Purpose

Make Buildbot PR status suitable for CI by reserving success for complete verified evidence.

## ADDED Requirements

### Requirement: Exit zero means every required build passed

r[onix.buildbot_pr_check.exit_contract] `buildbot-pr-check` MUST return exit code zero only when at least one required Buildbot build is discovered and every required parent and triggered build has a terminal accepted status.

#### Scenario: All required builds pass

r[onix.buildbot_pr_check.exit_contract.success]
- GIVEN Buildbot discovery returns required parent and triggered builds
- AND every required build reports a terminal accepted status
- WHEN the CLI aggregates the PR result
- THEN it exits zero
- AND reports verified success

#### Scenario: A required build fails

r[onix.buildbot_pr_check.exit_contract.failure]
- GIVEN at least one required parent or triggered build reports failure, exception, or cancellation
- WHEN the CLI aggregates the PR result
- THEN it exits with the documented CI-failure code
- AND identifies the failed build status

### Requirement: Unknown CI state fails closed

r[onix.buildbot_pr_check.indeterminate] `buildbot-pr-check` MUST return a nonzero indeterminate/tool-error result when required status cannot be verified.

#### Scenario: No Buildbot builds are discovered

r[onix.buildbot_pr_check.indeterminate.no_builds]
- GIVEN the PR lookup returns no verified Buildbot build URLs
- WHEN the CLI evaluates the result
- THEN it exits nonzero
- AND reports that success could not be established

#### Scenario: API request fails

r[onix.buildbot_pr_check.indeterminate.api_error]
- GIVEN a required GitHub, Gitea, or Buildbot request fails, times out, or returns malformed data
- WHEN the CLI evaluates the result
- THEN it exits with the documented tool-error code
- AND does not replace the error with an empty successful result

#### Scenario: Build remains pending or retrying

r[onix.buildbot_pr_check.indeterminate.pending]
- GIVEN a required build is pending, retrying, or has an unknown result code
- WHEN the CLI aggregates the PR result
- THEN it exits nonzero
- AND reports the non-terminal status

### Requirement: Status policy is a testable core

r[onix.buildbot_pr_check.core] The status aggregation policy MUST be a pure deterministic function, while HTTP, provider CLI calls, printing, and process exit remain in a thin imperative shell.

#### Scenario: In-memory outcomes classify deterministically

r[onix.buildbot_pr_check.core.unit]
- GIVEN an in-memory set of discovered build outcomes
- WHEN the aggregation core evaluates them repeatedly
- THEN it returns the same classified result and reasons
- AND no network or process setup is required

### Requirement: Buildbot package tests are authoritative

r[onix.buildbot_pr_check.validation] The Nix package MUST run hermetic positive and negative tests for the public status and exit-code contract.

#### Scenario: Offline tests run during package check

r[onix.buildbot_pr_check.validation.package]
- GIVEN recorded or synthetic responses contain no live credentials
- WHEN the Nix package check runs
- THEN passing, failing, pending, absent, malformed, and unavailable cases are executed
- AND the package build fails if their exit classifications regress
