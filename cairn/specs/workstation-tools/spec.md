# Workstation Tools Specification

## Purpose

Defines the `workstation-tools` capability.

## Requirements

### Requirement: Herdr source package

r[onix.britton-desktop.herdr.source] The system MUST use the pinned `llm-agents` Herdr package as the base of the Onix wrapper.

#### Scenario: llm-agents package is wrapped

r[onix.britton-desktop.herdr.source.llm_agents]
- GIVEN the existing `llm-agents` input exposes `packages.${system}.herdr`
- WHEN Onix builds the wrapped Herdr package
- THEN the wrapper base MUST be `inputs.llm-agents.packages.${system}.herdr`
- AND no separate upstream Herdr flake input or lock node MUST be required.

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

r[onix.britton-desktop.herdr.pueue.version] `britton-desktop` MUST select wrapped Herdr `0.7.5` or newer from the existing pinned `llm-agents` package set.

#### Scenario: Managed Herdr accepts workspace metadata rows

r[onix.britton-desktop.herdr.pueue.version.compatible]
- GIVEN the Pueue dashboard manifest and overview require workspace metadata support
- WHEN the wrapped Herdr package version is evaluated
- THEN the version MUST be at least `0.7.5`
- AND the wrapper base MUST come from `inputs.llm-agents.packages.${system}.herdr`.

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

### Requirement: Herdr workflow plugin sources are pinned

r[onix.britton-desktop.herdr.workflow_plugins.sources] The Herdr package and managed profile MUST define all bundled plugin sources with fixed content identities.

#### Scenario: Seven fixed sources are present

r[onix.britton-desktop.herdr.workflow_plugins.sources.complete]
- GIVEN Nix and typed Nickel data own the plugin source lists
- WHEN the Herdr package and profile evaluate
- THEN both lists MUST contain File Viewer, reviewr, Vim navigation, ghzinga, Mirror, jj workspace, and Pueue
- AND every remote source MUST use an exact Git commit and fixed content hash
- AND the local Pueue source MUST identify the exact vendored commit.

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

r[onix.britton-desktop.herdr.workflow_plugins.validation] Repository checks MUST cover plugin builds, fixed sources, actions, editor integration, wrapper behavior, and activation ownership.

#### Scenario: Focused workflow plugin check passes

r[onix.britton-desktop.herdr.workflow_plugins.validation.focused]
- GIVEN the wrapped Herdr package, static registry, generated configuration, Neovim adapter, and Home Manager package list
- WHEN the focused Nix check runs
- THEN it MUST accept every required artifact, source, key, action, runtime command, and adapter mapping
- AND it MUST reject a bogus action, bogus package, missing artifact, runtime registration, or activation mutation.

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
