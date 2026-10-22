# Add Hermes Desktop Aspen3 Specification Delta

## REMOVED Requirements

### Requirement: Hermes desktop app is installed on aspen3 only
r[onix.hermes_desktop.install] The `hermes-desktop` package from the pinned `llm-agents` input MUST be installed for brittonr on `aspen3` via the managed `llm-agents` clan service. The shared `llm-client` package set MUST remain unchanged on every other machine, including `britton-desktop`.

### Requirement: Service settings stay contract-validated
r[onix.hermes_desktop.validation] The `llm-agents` role settings MUST remain validated by the service settings contracts, including the `packages` field, with positive and negative verification coverage.

Removal rationale: `install-hermes-agent-desktop-aspen3` replaced this community package on 2026-09-05, and the operator dropped Hermes Desktop entirely on 2026-10-21.
