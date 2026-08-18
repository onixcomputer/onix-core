# Workstation Tools Specification Delta

## Purpose

Make the managed Herdr installation compatible with the separate Pueue dashboard and provide typed popup and split action bindings.

## ADDED Requirements

### Requirement: Herdr supports the Pueue dashboard manifest

r[onix.britton-desktop.herdr.pueue.version] `britton-desktop` MUST select Herdr `0.7.4` or newer from the existing pinned `llm-agents` package set.

#### Scenario: Managed Herdr accepts popup plugins

r[onix.britton-desktop.herdr.pueue.version.compatible]
- GIVEN the Pueue dashboard manifest requires popup pane support
- WHEN the managed Herdr package version is evaluated
- THEN the version is at least `0.7.4`
- AND the package still comes from `inputs.llm-agents.packages.${system}.herdr`

### Requirement: Herdr provides typed Pueue dashboard bindings

r[onix.britton-desktop.herdr.pueue.bindings] The managed Herdr config MUST provide distinct typed actions for popup and tiled Pueue dashboards.

#### Scenario: Both dashboard placements are bound

r[onix.britton-desktop.herdr.pueue.bindings.rendered]
- GIVEN the shared keymap defines popup and split Pueue chords
- WHEN Home Manager renders `herdr/config.toml`
- THEN one command invokes `dev.herdr.pueue.open-dashboard`
- AND another command invokes `dev.herdr.pueue.open-dashboard-split`
- AND the two commands use distinct keys

### Requirement: Herdr retains plugin-state ownership

r[onix.britton-desktop.herdr.pueue.ownership] Nix evaluation and Home Manager activation MUST NOT install, link, build, or restart the Pueue plugin.

#### Scenario: Declarative configuration remains side-effect free

r[onix.britton-desktop.herdr.pueue.ownership.runtime]
- GIVEN the plugin source remains in `/home/brittonr/git/herdr-plugin-pueue`
- WHEN the Herdr profile evaluates or activates
- THEN it only renders configuration data
- AND Herdr-managed plugin registration remains an explicit runtime operation

### Requirement: Pueue integration has positive and negative validation

r[onix.britton-desktop.herdr.pueue.validation] The repository MUST verify the Herdr compatibility version and rendered Pueue action IDs.

#### Scenario: Focused Herdr Pueue check passes

r[onix.britton-desktop.herdr.pueue.validation.focused]
- GIVEN the managed Herdr package and generated configuration
- WHEN the focused check runs
- THEN it accepts Herdr `0.7.4` or newer
- AND it finds both supported Pueue action IDs
- AND it rejects an invalid Pueue action ID
