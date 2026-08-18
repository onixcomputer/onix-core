# Repository Validation Specification Delta

## Purpose

Define an authoritative, reproducible validation graph that runs real package and module checks without accidental test discovery.

## ADDED Requirements

### Requirement: Python test discovery is bounded and deterministic

r[onix.validation.python.discovery] Root Python test discovery MUST exclude ignored agent worktrees, Nix outputs, secrets, caches, and generated trees while including every declared maintained test root exactly once.

#### Scenario: Pi worktrees are present

r[onix.validation.python.discovery.pi]
- GIVEN `.pi/worktrees` contains duplicate checkout test modules
- WHEN root pytest runs from the primary checkout
- THEN those worktrees are not collected
- AND each maintained primary-checkout test is collected once

#### Scenario: Declared package tests remain included

r[onix.validation.python.discovery.packages]
- GIVEN a maintained package has its own test directory
- WHEN the authoritative Python test command runs
- THEN that package test directory is executed explicitly
- AND broad exclusion patterns do not silently omit it

### Requirement: Maintained Python packages run hermetic checks

r[onix.validation.python.packages] Every maintained Python package with behavior MUST run positive and negative tests during its Nix package check without live network access or production credentials.

#### Scenario: Buildbot package tests execute

r[onix.validation.python.packages.buildbot]
- GIVEN Buildbot tests use recorded or synthetic provider responses
- WHEN the Nix package builds with checks enabled
- THEN the public API imports successfully
- AND positive success plus negative failure/error cases execute

### Requirement: Integration tests instantiate production modules

r[onix.validation.modules.production] Service integration tests MUST import and evaluate the production repository module rather than manually recreating an equivalent-looking service.

#### Scenario: Static-server policy is tested

r[onix.validation.modules.production.static_server]
- GIVEN the static-server production module defines service and firewall behavior
- WHEN its integration fixture runs
- THEN the fixture consumes that module's evaluated configuration
- AND a production access-policy regression causes the check to fail

### Requirement: Maintained Python type checking is authoritative

r[onix.validation.python.types] The repository MUST declare a bounded maintained mypy scope, keep that scope clean, and execute it in the same Nix-backed validation graph used by CI.

#### Scenario: Maintained source has a type error

r[onix.validation.python.types.negative]
- GIVEN a maintained Python source violates the configured strict type contract
- WHEN the authoritative validation graph runs
- THEN the mypy check fails
- AND the file is not omitted by an empty or accidental scope

#### Scenario: Excluded generated source is present

r[onix.validation.python.types.excluded]
- GIVEN generated or third-party Python source exists outside the maintained scope
- WHEN mypy runs
- THEN that source is excluded by an explicit reviewed rule
- AND maintained source remains checked

### Requirement: Validation includes positive and negative evidence

r[onix.validation.coverage] The authoritative repository validation graph MUST include both happy-path and failure-path assertions for changed behavioral components.

#### Scenario: Local command matches CI graph

r[onix.validation.coverage.local]
- GIVEN a developer enters the Nix development environment
- WHEN the documented local validation command runs
- THEN it executes the same maintained package, type, and integration checks as CI
- AND it performs no source mutation
