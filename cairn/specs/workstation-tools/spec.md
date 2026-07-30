# Workstation Tools Specification

## Purpose

Defines the `workstation-tools` capability.

## Requirements

### Requirement: Herdr source package

r[onix.britton-desktop.herdr.source] The system MUST source Herdr from the pinned `llm-agents` package set.

#### Scenario: llm-agents package is used

r[onix.britton-desktop.herdr.source.llm_agents]
- GIVEN the existing `llm-agents` input points at a revision that exposes `packages.${system}.herdr`
- WHEN `britton-desktop` declares the Herdr package
- THEN it uses `inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr`
- AND no separate upstream `herdr` flake input or `nixpkgs-herdr` lock node is required

### Requirement: britton-desktop installation

r[onix.britton-desktop.herdr.install] `britton-desktop` MUST install Herdr through the system package list.

#### Scenario: Herdr is installed

r[onix.britton-desktop.herdr.install.present]
- GIVEN `britton-desktop` evaluates its `environment.systemPackages`
- WHEN package names are rendered
- THEN `herdr` is present in the package list

#### Scenario: Existing package entries are preserved

r[onix.britton-desktop.herdr.install.preserve_existing]
- GIVEN `britton-desktop` already has machine-specific package entries
- WHEN Herdr is added
- THEN existing entries such as `opendeck` and `ttsim` remain present

### Requirement: Herdr config generation

r[onix.britton-desktop.herdr.config] `britton-desktop` MUST manage Herdr's `config.toml` from typed Nickel data.

#### Scenario: Nickel renders Herdr TOML

r[onix.britton-desktop.herdr.config.toml]
- GIVEN the `brittonr/herdr` Home Manager profile is assigned to `britton-desktop`
- WHEN the profile evaluates its Nickel config data
- THEN Home Manager renders `herdr/config.toml`
- AND the Herdr profile derives its prefix and plugin action chords from `inventory/home-profiles/brittonr/base/keymap.ncl`
- AND the rendered config sets `onboarding = false`
- AND the rendered config disables Herdr background version and manifest checks
- AND the rendered config sets `keys.prefix = "alt+space"`

#### Scenario: Bare Alt limitation is documented

r[onix.britton-desktop.herdr.config.alt_limit]
- GIVEN Herdr 0.7.0 requires a configured prefix to include a non-modifier key
- WHEN the managed Herdr profile documents its prefix choice
- THEN it records that bare `Alt` is unsupported by the packaged parser
- AND it uses `alt+space` as the closest valid Alt-based prefix chord

### Requirement: jj workspace plugin bindings

r[onix.britton-desktop.herdr.jj-plugin] `britton-desktop` MUST provide Herdr keybindings for the jj workspace plugin actions without making Home Manager activation perform network plugin installs.

#### Scenario: Plugin actions are bound

r[onix.britton-desktop.herdr.jj-plugin.bindings]
- GIVEN the managed Herdr config is rendered
- WHEN `herdr/config.toml` is inspected
- THEN it contains a `prefix+a` plugin action for `nathanflurry.jj-workspace.new`
- AND it contains a `prefix+shift+a` plugin action for `nathanflurry.jj-workspace.new-tab`
- AND it contains a `prefix+d` plugin action for `nathanflurry.jj-workspace.remove`

#### Scenario: Plugin install remains Herdr-managed

r[onix.britton-desktop.herdr.jj-plugin.install]
- GIVEN the plugin source is `NathanFlurry/herdr-plugin-jj-workspace`
- WHEN the Home Manager profile evaluates
- THEN it documents the Herdr plugin install source in typed Nickel data
- AND it does not run `herdr plugin install` from Nix evaluation or activation

### Requirement: Niri Alt binding removal

r[onix.britton-desktop.herdr.niri-alt] Niri MUST NOT reserve Alt-based window manager bindings that conflict with Herdr's Alt-based terminal prefix.

#### Scenario: Niri no longer binds Alt chords

r[onix.britton-desktop.herdr.niri-alt.removed]
- GIVEN Niri keybindings are generated from `niri-keybinds.ncl`
- WHEN the structured binding data is inspected
- THEN no generated Niri binding key uses the `Alt` modifier from `keymap.modifiers.secondary`
- AND existing Mod-based focus, move, workspace, and launcher bindings remain available

### Requirement: Package-list verification

r[onix.britton-desktop.herdr.package-list] Validation MUST check both positive and negative package-list expectations for the Herdr addition.

#### Scenario: Positive Herdr match succeeds

r[onix.britton-desktop.herdr.package-list.positive]
- GIVEN the evaluated `britton-desktop` package names
- WHEN checking for `herdr`
- THEN the check returns true

#### Scenario: Bogus Herdr match fails

r[onix.britton-desktop.herdr.package-list.negative]
- GIVEN the evaluated `britton-desktop` package names
- WHEN checking for `herdr-bogus`
- THEN the check returns false

### Requirement: Focused system evaluation

r[onix.britton-desktop.herdr.verification] The change MUST keep focused `britton-desktop` system evaluation successful.

#### Scenario: System derivation evaluates

r[onix.britton-desktop.herdr.verification.system_eval]
- GIVEN the `llm-agents` Herdr package entry is present
- WHEN `britton-desktop` system derivation evaluation runs
- THEN evaluation succeeds and returns a system derivation path

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
