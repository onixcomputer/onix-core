# Herdr Workflow Plugins Delta

## Purpose

Add the requested Herdr workflow plugins to `britton-desktop` without transferring plugin-state ownership to Nix.

## ADDED Requirements

### Requirement: Herdr workflow plugin sources are pinned

r[onix.britton-desktop.herdr.workflow_plugins.sources] The managed Herdr profile MUST define all requested plugin sources with exact release commit references.

#### Scenario: Five exact sources are present

r[onix.britton-desktop.herdr.workflow_plugins.sources.complete]
- GIVEN typed Nickel data owns the plugin source list
- WHEN the Herdr profile evaluates
- THEN the list contains File Viewer, reviewr, Vim Herdr Navigation, the `ghzinga` Herdr subdirectory, and Mirror
- AND each source uses an exact 40-character Git commit
- AND no source uses an unpinned branch or tag reference

### Requirement: Plugin synchronization remains explicit

r[onix.britton-desktop.herdr.workflow_plugins.sync] The managed profile MUST provide an explicit command that synchronizes pinned plugins through Herdr. Home Manager activation MUST NOT run that command.

#### Scenario: Operator runs the synchronization command

r[onix.britton-desktop.herdr.workflow_plugins.sync.manual]
- GIVEN `sync-herdr-plugins` is installed for `brittonr`
- WHEN the operator runs the command
- THEN it calls `herdr plugin install` once for each typed source
- AND each call passes the exact source commit through `--ref`
- AND each call accepts the already reviewed source through `--yes`

#### Scenario: Activation remains pure

r[onix.britton-desktop.herdr.workflow_plugins.sync.activation]
- GIVEN Home Manager evaluates or activates the Herdr profile
- WHEN activation scripts are inspected
- THEN no script runs `herdr plugin install`
- AND no script runs `herdr plugin link`
- AND plugin registry mutation remains an explicit operator action

#### Scenario: Plugin scripts receive a clean CDPATH

r[onix.britton-desktop.herdr.workflow_plugins.sync.cdpath]
- GIVEN Fish uses `CDPATH` for interactive directory navigation
- WHEN Fish starts and the synchronization command runs
- THEN Fish keeps `CDPATH` as a non-exported global
- AND the synchronization command clears an inherited `CDPATH` before plugin builds
- AND Bash plugin scripts can compute one root path from `cd` and `pwd`

### Requirement: Herdr workflow actions and editor handoff are configured

r[onix.britton-desktop.herdr.workflow_plugins.bindings] The managed profile MUST configure typed actions for File Viewer, reviewr, and Vim Herdr Navigation. Neovim MUST support edge handoff to Herdr.

#### Scenario: Plugin actions are rendered

r[onix.britton-desktop.herdr.workflow_plugins.bindings.rendered]
- GIVEN the shared keymap defines distinct plugin chords
- WHEN Home Manager renders `herdr/config.toml`
- THEN File Viewer has split and tab actions
- AND reviewr has a toggle action
- AND Vim navigation has left, down, up, and right actions
- AND no configured action uses a bogus plugin id

#### Scenario: Neovim hands off at a split edge

r[onix.britton-desktop.herdr.workflow_plugins.bindings.neovim]
- GIVEN the fixed Vim Herdr Navigation source contains the Neovim adapter
- WHEN Home Manager installs the managed Neovim file
- THEN normal-mode `Ctrl+h/j/k/l` mappings use the upstream adapter
- AND the adapter calls the current Herdr binary only at a Neovim split edge

### Requirement: ghzinga runtime is Nix-owned

r[onix.britton-desktop.herdr.workflow_plugins.ghzinga] Onix MUST expose the pinned `ghzinga` package. The Herdr profile MUST install it for `brittonr`.

#### Scenario: Both ghzinga commands are available

r[onix.britton-desktop.herdr.workflow_plugins.ghzinga.commands]
- GIVEN the pinned `ghzinga` source release builds
- WHEN the package output is inspected
- THEN it contains `gzg`
- AND it contains `ghzinga`
- AND the package version matches the pinned plugin source release

#### Scenario: Bogus package is absent

r[onix.britton-desktop.herdr.workflow_plugins.ghzinga.negative]
- GIVEN the evaluated Home Manager package list
- WHEN package names are inspected
- THEN `ghzinga` is present
- AND `ghzinga-bogus` is absent

### Requirement: Herdr workflow plugin validation covers positive and negative paths

r[onix.britton-desktop.herdr.workflow_plugins.validation] Repository checks MUST cover package availability, exact source pins, generated actions, editor integration, and activation ownership.

#### Scenario: Focused workflow plugin check passes

r[onix.britton-desktop.herdr.workflow_plugins.validation.focused]
- GIVEN the generated sync command, Herdr config, Neovim adapter, and Home Manager package list
- WHEN the focused Nix check runs
- THEN it accepts every required package, source, key, action, and adapter mapping
- AND it rejects an unpinned source, a bogus action, a bogus package, and activation mutation
