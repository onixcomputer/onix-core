# Add Hermes Desktop Aspen3 Specification

## Purpose

Defines the `add-hermes-desktop-aspen3` capability.

## Requirements

### Requirement: Hermes desktop app is installed on aspen3 only

r[onix.hermes_desktop.install] The `hermes-desktop` package from the pinned `llm-agents` input MUST be installed for brittonr on `aspen3` via the managed `llm-agents` clan service. The shared `llm-client` package set MUST remain unchanged on every other machine, including `britton-desktop`.

#### Scenario: App is present on aspen3

r[onix.hermes_desktop.install.aspen3]
- GIVEN the `aspen3` NixOS configuration is evaluated
- WHEN the resolved `environment.systemPackages` is inspected
- THEN the `hermes-desktop` package MUST be present
- AND the package MUST provide its `hermes-desktop` binary and desktop entry.

#### Scenario: Other llm-client machines are unchanged

r[onix.hermes_desktop.install.scope]
- GIVEN the `britton-desktop` NixOS configuration is evaluated
- WHEN the resolved `environment.systemPackages` is inspected
- THEN the `hermes-desktop` package MUST be absent
- AND the pre-existing `pi`, `openspec`, and `hermes-agent` packages MUST remain present.

### Requirement: Service settings stay contract-validated

r[onix.hermes_desktop.validation] The `llm-agents` role settings MUST remain validated by the service settings contracts, including the `packages` field, with positive and negative verification coverage.

#### Scenario: Valid package list is accepted

r[onix.hermes_desktop.validation.positive]
- GIVEN a valid `llm-agents` role settings record supplies a string array for `packages`
- WHEN the settings contract validation runs
- THEN validation MUST pass without errors.

#### Scenario: Malformed package list is rejected

r[onix.hermes_desktop.validation.negative]
- GIVEN an `llm-agents` role settings record supplies a non-array value for `packages`
- WHEN the settings contract validation runs
- THEN validation MUST produce an error naming the `packages` field.
