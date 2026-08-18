# Home Manager 26.05 State Migration Specification

## Purpose

Define how `britton-desktop` migrates its managed Home Manager compatibility state to 26.05 while making Neovim provider behavior explicit and verifiable.

## Requirements

### Requirement: Migration scope inventory

r[onix.home-manager.2605.scope.inventory] The migration MUST identify which managed Home Manager users import the shared Neovim base profile before changing provider defaults.

#### Scenario: Managed Neovim profile importers are known

r[onix.home-manager.2605.scope.inventory.importers]
- GIVEN the managed Home Manager profile assignments are defined in inventory
- WHEN the migration changes the shared `brittonr/base/neovim.nix` profile
- THEN the implementation records which managed user assignments import the base profile
- AND the migration remains scoped to the intended workstation behavior

### Requirement: Pre-migration state confirmation

r[onix.home-manager.2605.scope.state] The migration MUST confirm the pre-migration effective Home Manager state version for `britton-desktop`.

#### Scenario: Baseline state version is known

r[onix.home-manager.2605.scope.state.baseline]
- GIVEN `britton-desktop` evaluates before the state-version override is added
- WHEN the effective `home-manager.users.brittonr.home.stateVersion` is inspected
- THEN the migration records the baseline value

### Requirement: Explicit workstation state-version override

r[onix.home-manager.2605.scope.override] `britton-desktop` MUST set its managed Home Manager state version to `26.05` explicitly without requiring a NixOS `system.stateVersion` bump.

#### Scenario: Home Manager state is overridden for britton-desktop

r[onix.home-manager.2605.scope.override.desktop]
- GIVEN `britton-desktop` evaluates its managed Home Manager user
- WHEN `home-manager.users.brittonr.home.stateVersion` is inspected
- THEN the effective value is `26.05`
- AND `system.stateVersion` remains independently controlled

### Requirement: Neovim provider defaults

r[onix.home-manager.2605.neovim.providers] The managed Neovim profile MUST adopt the Home Manager 26.05 defaults for Ruby and Python provider support explicitly.

#### Scenario: Ruby provider is disabled explicitly

r[onix.home-manager.2605.neovim.providers.ruby]
- GIVEN the managed Neovim profile evaluates
- WHEN `programs.neovim.withRuby` is inspected
- THEN the effective value is `false`

#### Scenario: Python provider is disabled explicitly

r[onix.home-manager.2605.neovim.providers.python]
- GIVEN the managed Neovim profile evaluates
- WHEN `programs.neovim.withPython3` is inspected
- THEN the effective value is `false`

### Requirement: Effective state verification

r[onix.home-manager.2605.verify.effective_state] Validation MUST include a positive check for the effective `britton-desktop` Home Manager state version.

#### Scenario: State version positive check succeeds

r[onix.home-manager.2605.verify.effective_state.positive]
- GIVEN `britton-desktop` evaluates after the migration
- WHEN the effective Home Manager state version is compared to `26.05`
- THEN the check succeeds

### Requirement: Neovim provider verification

r[onix.home-manager.2605.verify.neovim_providers] Validation MUST include positive checks for the effective Neovim Ruby and Python provider values.

#### Scenario: Provider positive checks succeed

r[onix.home-manager.2605.verify.neovim_providers.positive]
- GIVEN `britton-desktop` evaluates after the migration
- WHEN the effective Neovim Ruby and Python provider values are inspected
- THEN both checks report `false`

### Requirement: Negative legacy verification

r[onix.home-manager.2605.verify.negative_legacy] Validation MUST include a negative check proving the migrated effective state no longer matches the legacy value.

#### Scenario: Legacy state expectation fails

r[onix.home-manager.2605.verify.negative_legacy.state]
- GIVEN `britton-desktop` evaluates after the migration
- WHEN the effective Home Manager state version is compared to the legacy baseline value
- THEN the check reports that the legacy expectation is false

### Requirement: Focused system evaluation

r[onix.home-manager.2605.verify.system_eval] The migration MUST keep focused `britton-desktop` system derivation evaluation successful.

#### Scenario: System derivation evaluates

r[onix.home-manager.2605.verify.system_eval.toplevel]
- GIVEN the Home Manager state-version override and Neovim provider choices are present
- WHEN `britton-desktop` system derivation evaluation runs
- THEN evaluation succeeds and returns a system derivation path

### Requirement: Cairn validation

r[onix.home-manager.2605.verify.cairn] The migration MUST keep the repository's Cairn lifecycle artifacts valid.

#### Scenario: Cairn validation succeeds

r[onix.home-manager.2605.verify.cairn.valid]
- GIVEN the migration change package is present
- WHEN Cairn validation runs with the repo policy
- THEN it reports the lifecycle layout as valid
