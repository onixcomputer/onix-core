# Workstation Tools Delta

## ADDED Requirements

### Requirement: Darwin Herdr package

r[onix.britton-air.herdr.package] The onixpkgs Herdr wrapper MUST build on `aarch64-darwin` and MUST omit the systemd-only Collie plugin there while keeping the Linux bundle unchanged.

#### Scenario: Darwin evaluates the wrapper
- **GIVEN** the pinned `llm-agents-herdr` base and the onixpkgs wrapper
- **WHEN** `pkgs.herdr` is evaluated for `aarch64-darwin`
- **THEN** the plugin roots, sources, ids, and required artifacts MUST exclude `herdr.collie`
- **AND** the other seven plugins MUST remain listed
- **AND** the same evaluation for `x86_64-linux` MUST still produce all eight plugins.

#### Scenario: The shared config does not bind Collie
- **GIVEN** the fleet Herdr profile renders `herdr/config.toml` on a Darwin host
- **WHEN** the profile evaluates
- **THEN** the rendered key bindings MUST NOT reference `herdr.collie` actions
- **AND** the profile MUST NOT declare a Collie activation on Darwin.

### Requirement: britton-air installation

r[onix.britton-air.herdr.install] `britton-air` MUST install the wrapped Herdr core in system packages and `herdr-app` from the pinned llm-agents input in `brittonr`'s Home Manager packages.

#### Scenario: The generation contains both Herdr generations
- **GIVEN** `britton-air` evaluates `darwinConfigurations.britton-air`
- **WHEN** package names are rendered
- **THEN** `herdr` MUST be present in `environment.systemPackages`
- **AND** `herdr-app` MUST be present in `home-manager.users.brittonr.home.packages`.

### Requirement: britton-air Home Manager profile

r[onix.britton-air.herdr.profile] The `home-manager-profiles` service MUST provide a `darwinModule`, and `britton-air` MUST receive the same `herdr` profile as the NixOS fleet through it.

#### Scenario: Darwin renders the profile
- **GIVEN** a profile instance assigned to a nix-darwin machine
- **WHEN** the darwin configuration evaluates
- **THEN** Home Manager's darwin module MUST import the assigned profiles
- **AND** `~/.config/herdr/config.toml` MUST be rendered from the shared Nickel data.

### Requirement: britton-air Herdr relay

r[onix.britton-air.herdr.relay] `britton-air` MUST run herdr-iroh from the pinned input as a per-user launchd agent under `brittonr`, with the `britton-grok` peer, the saved-machine gateway, and `pkgs.herdr` as `herdr_bin`.

#### Scenario: The daemon starts
- **GIVEN** the britton-air generation is activated
- **WHEN** `launchctl print gui/501/org.nix-community.home.herdr-iroh` is inspected
- **THEN** the per-user agent MUST be running as `brittonr`
- **AND** its `--config` file MUST contain `gateway = true`, `relays = true`, and the `britton-grok` endpoint id
- **AND** its state directory MUST be writable by `brittonr`.

### Requirement: Same saved machines as aspen3

r[onix.britton-air.herdr.machines] `britton-air`'s `brittonr` Herdr client MUST list the same saved SSH machines as aspen3: `britton-desktop`, `cproof-brittonr`, and `instantfill-vm`.

#### Scenario: Saved machines are listed
- **GIVEN** the machines have been added on britton-air
- **WHEN** `herdr machine list` runs as `brittonr`
- **THEN** it MUST report those three labels with their aspen3 targets and `default` sessions.

### Requirement: britton-air Herdr verification

r[onix.britton-air.herdr.verification] The deployed britton-air Herdr MUST be verified against the expected core, plugin, app, config, relay, and saved-machine state.

#### Scenario: The installation is verified
- **GIVEN** the britton-air generation is active
- **WHEN** the verification commands run
- **THEN** `herdr --version` MUST report 0.9.3
- **AND** `herdr plugin list` MUST report seven plugins without `herdr.collie`
- **AND** `herdr-app` MUST resolve in `brittonr`'s profile
- **AND** the Home Manager config link MUST point into the store
- **AND** the relay MUST be running as the per-user agent
- **AND** the saved-machine list MUST match aspen3; reachability is reported
  separately because two targets are not on this host's network.
