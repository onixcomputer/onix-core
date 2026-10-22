# Install Hermes Agent Desktop Aspen3 Specification Delta

## REMOVED Requirements

### Requirement: Official Hermes Desktop is installed for brittonr on aspen3
r[onix.hermes_agent.install] The official Hermes Agent from `NousResearch/hermes-agent` MUST be installed for brittonr on `aspen3` through its Home Manager module. The install MUST include the `hermes` command line and the Hermes Desktop Electron application with a Linux launcher entry.

### Requirement: Installation is scoped to aspen3
r[onix.hermes_agent.scope] The official Hermes Desktop install MUST NOT add a `hermes-desktop` home package on `britton-desktop`. aspen3 MUST NOT carry a second `hermes-desktop` in `environment.systemPackages`. The effective package set on the other `llm-client` machines MUST stay unchanged.

### Requirement: Change is contract-validated
r[onix.hermes_agent.validation] The service settings and user-profile inventory MUST stay valid under the Nickel contracts, with positive and negative verification coverage for the new wiring.

Removal rationale: the operator dropped Hermes Desktop on 2026-10-21. No machine installs it, and `aspen3` takes the `hermes-agent` CLI from the shared `llm-agents` list like every other `llm-client` host.
