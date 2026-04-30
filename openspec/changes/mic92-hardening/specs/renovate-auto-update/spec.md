## ADDED Requirements

### Requirement: renovate config present at repo root
A `renovate.json` file SHALL exist at the repository root with the Renovate JSON schema reference, dependency dashboard enabled, and Nix support enabled.

#### Scenario: renovate detects nix inputs
- **WHEN** Renovate runs against the repository
- **THEN** it identifies flake inputs as dependencies and creates PRs for available updates

### Requirement: renovate config is minimal
The renovate configuration SHALL be minimal — enable Nix, enable the dependency dashboard, and nothing else. Custom schedule, automerge, or grouping rules are out of scope for this change.

#### Scenario: config file is valid JSON
- **WHEN** `renovate.json` is parsed
- **THEN** it is valid JSON conforming to the Renovate schema with `nix.enabled: true` and `dependencyDashboard: true`

### Requirement: renovate does not interfere with manual updates
The renovate configuration SHALL not auto-merge PRs. All input updates require human review.

#### Scenario: renovate PR requires manual merge
- **WHEN** Renovate creates a PR for a flake input update
- **THEN** the PR remains open until a maintainer merges it manually
