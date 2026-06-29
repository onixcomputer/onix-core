# britton-desktop-herdr Specification

## Purpose

Define how `britton-desktop` receives Herdr as a declarative workstation tool.

## Requirements

### Requirement: Herdr source package

r[onix.britton-desktop.herdr.source] The system MUST source Herdr from a pinned nixpkgs package set.

#### Scenario: Nixpkgs package is used

r[onix.britton-desktop.herdr.source.nixpkgs]
- GIVEN a narrow `nixpkgs-herdr` input points at a revision that exposes `herdr`
- WHEN `britton-desktop` declares the Herdr package
- THEN it uses `inputs.nixpkgs-herdr.legacyPackages.${pkgs.stdenv.hostPlatform.system}.herdr`
- AND no separate upstream `herdr` flake input or lock node is required

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
- GIVEN the narrow nixpkgs Herdr package entry is present
- WHEN `britton-desktop` system derivation evaluation runs
- THEN evaluation succeeds and returns a system derivation path
