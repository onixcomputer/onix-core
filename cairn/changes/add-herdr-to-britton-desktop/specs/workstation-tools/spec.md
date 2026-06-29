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
