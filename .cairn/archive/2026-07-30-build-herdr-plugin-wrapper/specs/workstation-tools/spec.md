## ADDED Requirements

### Requirement: Herdr wrapper provides the reviewed plugin set

r[onix.britton-desktop.herdr.wrapper.plugins] The Herdr wrapper MUST provide immutable Nix builds for File Viewer, reviewr, Vim Herdr Navigation, ghzinga, Mirror, jj workspace, and the Pueue dashboard.

#### Scenario: All bundled plugins are present

r[onix.britton-desktop.herdr.wrapper.plugins.complete]
- GIVEN Nix builds the Herdr plugin bundle
- WHEN the generated static registry is inspected
- THEN it MUST contain exactly the seven reviewed plugin ids
- AND each plugin root MUST resolve to an immutable Nix store path
- AND each declared runtime binary or script MUST exist.

#### Scenario: Plugin artifacts are fixed

r[onix.britton-desktop.herdr.wrapper.plugins.fixed]
- GIVEN a plugin has a public remote source
- WHEN Nix evaluates its source declaration
- THEN the declaration MUST use an exact commit and fixed content hash
- AND the unpublished Pueue plugin MUST use the reviewed vendored commit snapshot.

### Requirement: Herdr merges static and mutable plugin registries

r[onix.britton-desktop.herdr.wrapper.registry] Herdr MUST merge the registry from `HERDR_STATIC_PLUGIN_REGISTRY` with its mutable user registry without writing static entries to the user registry.

#### Scenario: Static and user plugins load together

r[onix.britton-desktop.herdr.wrapper.registry.merge]
- GIVEN the mutable registry contains an unrelated user plugin
- AND the static registry contains the reviewed plugins
- WHEN Herdr loads or refreshes plugins
- THEN the runtime registry MUST contain both sets
- AND a static entry MUST replace a mutable entry with the same plugin id.

#### Scenario: Static registry input is absent or invalid

r[onix.britton-desktop.herdr.wrapper.registry.negative]
- GIVEN the static registry variable is absent, unreadable, or malformed
- WHEN Herdr loads plugins
- THEN valid mutable plugins MUST remain available
- AND Herdr MUST NOT replace or rewrite the mutable registry.

#### Scenario: Mutable registry update keeps static plugins

r[onix.britton-desktop.herdr.wrapper.registry.update]
- GIVEN Herdr changes an unrelated mutable plugin entry
- WHEN it saves and reloads the mutable registry
- THEN the saved file MUST contain only mutable entries
- AND the returned runtime registry MUST still contain all static entries.

### Requirement: britton-desktop installs the wrapped Herdr package

r[onix.britton-desktop.herdr.wrapper.install] `britton-desktop` MUST install a wrapped Herdr package whose base is `inputs.llm-agents.packages.${system}.herdr`.

#### Scenario: Wrapper environment selects the generated registry

r[onix.britton-desktop.herdr.wrapper.install.environment]
- GIVEN the system package list contains `herdr`
- WHEN the executable wrapper is inspected
- THEN it MUST set `HERDR_STATIC_PLUGIN_REGISTRY` to the generated store registry
- AND it MUST add the plugin runtime commands to `PATH`.

#### Scenario: Base provider remains unchanged

r[onix.britton-desktop.herdr.wrapper.install.provider]
- GIVEN the wrapper package evaluates
- WHEN its base package and version are inspected
- THEN the base MUST come from the pinned `llm-agents` package set
- AND the selected Herdr version MUST remain compatible with every bundled manifest.

### Requirement: Wrapper startup and activation preserve user ownership

r[onix.britton-desktop.herdr.wrapper.ownership] Home Manager activation and Herdr wrapper startup MUST NOT install, link, download, build, disable, or remove plugins.

#### Scenario: Activation remains free of plugin mutation

r[onix.britton-desktop.herdr.wrapper.ownership.activation]
- GIVEN Home Manager evaluates or activates the Herdr profile
- WHEN activation scripts and installed helper commands are inspected
- THEN no command MUST run `herdr plugin install` or `herdr plugin link`
- AND the profile MUST NOT install `sync-herdr-plugins`.

#### Scenario: Mutable Herdr data remains writable

r[onix.britton-desktop.herdr.wrapper.ownership.mutable]
- GIVEN the wrapped Herdr executable starts
- WHEN Herdr resolves configuration, state, session, and log paths
- THEN it MUST use the normal user XDG paths
- AND the wrapper MUST NOT replace `XDG_CONFIG_HOME` or `XDG_STATE_HOME` with store paths.

### Requirement: Herdr wrapper validation covers positive and negative paths

r[onix.britton-desktop.herdr.wrapper.validation] Repository checks MUST verify the static registry merge, plugin artifacts, wrapper environment, profile ownership, and package selection.

#### Scenario: Focused wrapper checks pass

r[onix.britton-desktop.herdr.wrapper.validation.positive]
- GIVEN the patched Herdr package, plugin bundle, wrapper, and desktop configuration
- WHEN the focused checks run
- THEN they MUST accept every reviewed plugin id and required artifact
- AND they MUST accept a preserved unrelated mutable plugin
- AND they MUST accept the wrapped package in the system package list.

#### Scenario: Invalid wrapper states are rejected

r[onix.britton-desktop.herdr.wrapper.validation.negative]
- GIVEN fixtures contain a duplicate mutable id, malformed static data, a missing plugin artifact, or a mutation command
- WHEN the focused checks run
- THEN static duplicate precedence and mutable fallback MUST match the registry contract
- AND missing artifacts or mutation commands MUST fail validation.

## MODIFIED Requirements

### Requirement: Herdr source package

r[onix.britton-desktop.herdr.source] The system MUST use the pinned `llm-agents` Herdr package as the base of the Onix wrapper.

#### Scenario: llm-agents package is wrapped

r[onix.britton-desktop.herdr.source.llm_agents]
- GIVEN the existing `llm-agents` input exposes `packages.${system}.herdr`
- WHEN Onix builds the wrapped Herdr package
- THEN the wrapper base MUST be `inputs.llm-agents.packages.${system}.herdr`
- AND no separate upstream Herdr flake input or lock node MUST be required.

### Requirement: Herdr supports the Pueue dashboard manifest

r[onix.britton-desktop.herdr.pueue.version] `britton-desktop` MUST select wrapped Herdr `0.7.5` or newer from the existing pinned `llm-agents` package set.

#### Scenario: Managed Herdr accepts workspace metadata rows

r[onix.britton-desktop.herdr.pueue.version.compatible]
- GIVEN the Pueue dashboard manifest and overview require workspace metadata support
- WHEN the wrapped Herdr package version is evaluated
- THEN the version MUST be at least `0.7.5`
- AND the wrapper base MUST come from `inputs.llm-agents.packages.${system}.herdr`.

### Requirement: Herdr retains plugin-state ownership

r[onix.britton-desktop.herdr.pueue.ownership] Nix MUST build the fixed Pueue plugin. Evaluation, activation, and wrapper startup MUST NOT register, rebuild, or restart it.

#### Scenario: Declarative installation remains side-effect free

r[onix.britton-desktop.herdr.pueue.ownership.runtime]
- GIVEN Onix vendors the reviewed Pueue plugin commit
- WHEN Nix builds the plugin and Home Manager activates the profile
- THEN the wrapper MUST read the plugin from an immutable store registry
- AND activation and startup MUST NOT run `herdr plugin install` or `herdr plugin link`.

### Requirement: Pueue integration has positive and negative validation

r[onix.britton-desktop.herdr.pueue.validation] The repository MUST verify wrapper compatibility, Pueue artifacts, action ids, and the absence of runtime registration.

#### Scenario: Focused Herdr Pueue check passes

r[onix.britton-desktop.herdr.pueue.validation.focused]
- GIVEN the wrapped Herdr package, generated registry, and generated configuration
- WHEN the focused check runs
- THEN it MUST accept Herdr `0.7.5` or newer and both supported Pueue action ids
- AND it MUST reject an invalid action id, a missing artifact, or a runtime registration command.

### Requirement: Herdr workflow plugin sources are pinned

r[onix.britton-desktop.herdr.workflow_plugins.sources] The Herdr package and managed profile MUST define all bundled plugin sources with fixed content identities.

#### Scenario: Seven fixed sources are present

r[onix.britton-desktop.herdr.workflow_plugins.sources.complete]
- GIVEN Nix and typed Nickel data own the plugin source lists
- WHEN the Herdr package and profile evaluate
- THEN both lists MUST contain File Viewer, reviewr, Vim navigation, ghzinga, Mirror, jj workspace, and Pueue
- AND every remote source MUST use an exact Git commit and fixed content hash
- AND the local Pueue source MUST identify the exact vendored commit.

### Requirement: Herdr workflow plugin validation covers positive and negative paths

r[onix.britton-desktop.herdr.workflow_plugins.validation] Repository checks MUST cover plugin builds, fixed sources, actions, editor integration, wrapper behavior, and activation ownership.

#### Scenario: Focused workflow plugin check passes

r[onix.britton-desktop.herdr.workflow_plugins.validation.focused]
- GIVEN the wrapped Herdr package, static registry, generated configuration, Neovim adapter, and Home Manager package list
- WHEN the focused Nix check runs
- THEN it MUST accept every required artifact, source, key, action, runtime command, and adapter mapping
- AND it MUST reject a bogus action, bogus package, missing artifact, runtime registration, or activation mutation.

## REMOVED Requirements

### Requirement: Plugin synchronization remains explicit

r[onix.britton-desktop.herdr.workflow_plugins.sync] The managed profile MUST provide an explicit command that synchronizes pinned plugins through Herdr. Home Manager activation MUST NOT run that command.
