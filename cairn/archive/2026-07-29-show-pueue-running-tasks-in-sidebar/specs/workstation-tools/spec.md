# Workstation Tools Specification Delta

## Purpose

Render the Pueue plugin's bounded running-task metadata in the managed Herdr sidebar.

## MODIFIED Requirements

### Requirement: Herdr supports the Pueue dashboard manifest

r[onix.britton-desktop.herdr.pueue.version] `britton-desktop` MUST select Herdr `0.7.5` or newer from the existing pinned `llm-agents` package set.

#### Scenario: Managed Herdr accepts workspace metadata rows

r[onix.britton-desktop.herdr.pueue.version.compatible]
- GIVEN the Pueue dashboard manifest and overview require workspace metadata support
- WHEN the managed Herdr package version is evaluated
- THEN the version is at least `0.7.5`
- AND the package still comes from `inputs.llm-agents.packages.${system}.herdr`.

## ADDED Requirements

### Requirement: Herdr renders the bounded Pueue running-task overview

r[onix.britton-desktop.herdr.pueue.sidebar_overview] The managed Herdr config MUST render plugin-owned Pueue workspace metadata through typed custom Space rows. It MUST configure one status row and no more than two running-task rows.

#### Scenario: Safe overview rows are rendered

r[onix.britton-desktop.herdr.pueue.sidebar_overview.rendered]
- GIVEN the Pueue plugin reports bounded workspace metadata
- WHEN Home Manager renders `herdr/config.toml`
- THEN the Space layout MUST contain `$pueue_status`, `$pueue_running_1`, and `$pueue_running_2`
- AND missing metadata values MUST remain absent through Herdr's normal custom-token elision.

#### Scenario: Configuration does not expand the privacy boundary

r[onix.britton-desktop.herdr.pueue.sidebar_overview.privacy]
- GIVEN Pueue status can contain task environments, paths, raw JSON, and child diagnostics
- WHEN the managed Space token names are inspected
- THEN no configured Pueue token MUST request environments, paths, raw output, or diagnostics
- AND Nix evaluation and activation MUST NOT report or persist runtime task values.

#### Scenario: Runtime ownership remains outside Home Manager

r[onix.britton-desktop.herdr.pueue.sidebar_overview.ownership]
- GIVEN the plugin publishes expiring metadata while its dashboard runs
- WHEN the Home Manager profile evaluates or activates
- THEN it MUST only render token placement and style
- AND it MUST NOT run a monitor, start a service, execute the plugin, or restart Herdr.
