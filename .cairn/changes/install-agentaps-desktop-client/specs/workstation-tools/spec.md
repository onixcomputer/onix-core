# Workstation Tools Specification Delta

## ADDED Requirements

### Requirement: The selected workstations install Agentaps

r[onix.agentaps.install] `britton-desktop` and `aspen3` MUST install the
`agentaps` package in `brittonr`'s Home Manager packages. No other machine
MUST gain it.

#### Scenario: Selected machines install the client

r[onix.agentaps.install.selected]
- GIVEN the evaluated `home-manager.users.brittonr.home.packages` of the
  selected machines
- WHEN package names are rendered
- THEN `agentaps` MUST be present on `britton-desktop`
- AND `agentaps` MUST be present on `aspen3`

#### Scenario: Existing package entries are preserved

r[onix.agentaps.install.preserve_existing]
- GIVEN each machine already has machine-specific Home Manager packages
- WHEN Agentaps is added
- THEN the existing entries MUST remain present

### Requirement: Agentaps comes from onixpkgs

r[onix.agentaps.source] On the working branch, the client MUST resolve as
`pkgs.agentaps` from the onixpkgs overlay at the revision pinned in
onix-core's lock. That branch MUST NOT gain a flake input or a package
definition in onix-core. `britton-desktop`'s deployed lineage predates the
overlay, so it MUST take `agentaps` from the same onixpkgs revision's
`packages` output. Its only flake change MUST be the `onixpkgs` input and
the lock nodes that input adds.

#### Scenario: The overlay supplies the package

r[onix.agentaps.source.overlay]
- GIVEN the relocked `onixpkgs` input on the working branch
- WHEN a selected machine resolves `pkgs.agentaps`
- THEN the derivation MUST come from onixpkgs `pkgs/agentaps`
- AND the onix-core flake input list MUST be unchanged

#### Scenario: The desktop lineage takes the same package definition

r[onix.agentaps.source.desktop_lineage]
- GIVEN the commit that `britton-desktop` runs
- WHEN Agentaps is added to that lineage
- THEN the package MUST come from the `packages` output of the onixpkgs
  revision that the working branch locks
- AND no existing input's locked revision MUST change

### Requirement: The selected machines run a system with Agentaps

r[onix.agentaps.deployment] Each selected machine MUST be deployed from the
lineage it already runs, to a system whose `brittonr` profile contains
Agentaps. Each candidate closure MUST be compared with the running system
before activation.

#### Scenario: The desktop keeps its deployed lineage

r[onix.agentaps.deployment.lineage]
- GIVEN `britton-desktop` runs a commit that is not on the working branch
- WHEN its candidate system is compared with the running system
- THEN the difference MUST contain only Agentaps and the profile, unit, and
  version paths that include it

#### Scenario: The deployed profile resolves the client

r[onix.agentaps.deployment.path]
- GIVEN the deployed system on `britton-desktop` and `aspen3`
- WHEN `agentaps` is resolved on `brittonr`'s `PATH` on each target
- THEN each host MUST report the packaged executable
