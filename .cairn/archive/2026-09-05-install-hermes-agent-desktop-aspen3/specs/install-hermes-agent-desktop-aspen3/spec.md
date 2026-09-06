# Install Official Hermes Agent Desktop on aspen3

## ADDED Requirements

### Requirement: Official Hermes Desktop is installed for brittonr on aspen3

r[onix.hermes_agent.install] The official Hermes Agent from `NousResearch/hermes-agent` MUST be installed for brittonr on `aspen3` through its Home Manager module. The install MUST include the `hermes` command line and the Hermes Desktop Electron application with a Linux launcher entry.

#### Scenario: Desktop launcher is present

r[onix.hermes_agent.install.desktop]
- GIVEN the aspen3 home-manager configuration for brittonr is evaluated
- WHEN the resolved `home.packages` and the desktop package contents are inspected
- THEN a package named `hermes-desktop` MUST be present in `home.packages`
- AND its `/share/applications/hermes.desktop` launcher entry MUST exist.

#### Scenario: CLI is present

r[onix.hermes_agent.install.cli]
- GIVEN the aspen3 home-manager configuration for brittonr is evaluated
- WHEN the resolved `home.packages` is inspected
- THEN the official Hermes CLI package MUST be present
- AND its `bin/hermes` executable MUST exist.

### Requirement: Installation is scoped to aspen3

r[onix.hermes_agent.scope] The official Hermes Desktop install MUST NOT add a `hermes-desktop` home package on `britton-desktop`. aspen3 MUST NOT carry a second `hermes-desktop` in `environment.systemPackages`. The effective package set on the other `llm-client` machines MUST stay unchanged.

#### Scenario: britton-desktop is unchanged

r[onix.hermes_agent.scope.britton_desktop]
- GIVEN the britton-desktop home-manager configuration for brittonr is evaluated
- WHEN the resolved `home.packages` is inspected
- THEN no package named `hermes-desktop` MUST be present
- AND no official `hermes-agent` package MUST be added by this change.

#### Scenario: no duplicate desktop on aspen3

r[onix.hermes_agent.scope.system]
- GIVEN the aspen3 NixOS configuration is evaluated
- WHEN the resolved `environment.systemPackages` is inspected
- THEN no package named `hermes-desktop` MUST be present
- AND no `hermes-agent` from the `llm-agents` role MUST remain, because the official install replaces it.

#### Scenario: other llm-client machines keep their set

r[onix.hermes_agent.scope.llm_client]
- GIVEN the aspen1, aspen2, and britton-desktop NixOS configurations are evaluated
- WHEN the resolved `environment.systemPackages` is inspected
- THEN each machine MUST still contain `pi`, `openspec`, and the `hermes-agent` CLI that the `llm-client` role provided before this change.

### Requirement: Change is contract-validated

r[onix.hermes_agent.validation] The service settings and user-profile inventory MUST stay valid under the Nickel contracts, with positive and negative verification coverage for the new wiring.

#### Scenario: Inventories validate

r[onix.hermes_agent.validation.inventory]
- GIVEN the updated `llm-agents` service settings and the new aspen3 user profile instance
- WHEN `ncl export` runs on `inventory/services/services.ncl` and `inventory/core/users.ncl`
- THEN export MUST succeed without contract errors.

#### Scenario: Malformed packages setting is rejected

r[onix.hermes_agent.validation.negative]
- GIVEN an `llm-agents` role settings record with a non-array `packages` value
- WHEN the settings contract validation runs
- THEN validation MUST report an error naming the `packages` field.
