# Upstream Compositor Specification

## Purpose

Use the upstream Niri flake for interactive Niri hosts and ensure Aspen3's greeter and compositor select the same validated revision.

## Requirements

### Requirement: Upstream package for Niri consumers [r[onix.niri.upstream.source]]

The Niri flake input MUST resolve to the canonical upstream `niri-wm/niri` repository. The shared Home Manager compositor and its gesture and sticky-window consumers MUST use that input's package without a fork-specific build-input override.

#### Scenario: Locked upstream compositor [r[onix.niri.upstream.source.lock]]

- GIVEN the repository flake is evaluated for x86_64-linux
- WHEN the Niri executable is built
- THEN its input is pinned to an upstream revision
- AND the resulting executable runs without the removed local package override

### Requirement: Aspen3 upstream session [r[onix.niri.upstream.aspen3]]

Aspen3's greetd command MUST launch the pinned upstream `niri-session`; its Home Manager Niri service MUST execute a wrapper built from the same upstream input, not a different compositor binary or an old profile launcher.

#### Scenario: Selected Aspen3 greeter and service [r[onix.niri.upstream.aspen3.selection]]

- GIVEN the Aspen3 NixOS/Home Manager configuration
- WHEN greetd starts a new Niri session
- THEN its launcher is the upstream package's `niri-session`
- AND the Home Manager user service starts the wrapped upstream compositor

### Requirement: Upstream-valid user configuration [r[onix.niri.upstream.config]]

The generated Niri KDL MUST validate with the upstream package and the initial Noctalia include. Fork-only overview, spatial-focus, and fit-columns/grid directives MUST NOT remain in the rendered configuration; Aspen3's disable-while-typing and disabled tap-to-click settings MUST remain intact.

#### Scenario: First activation [r[onix.niri.upstream.config.initial]]

- GIVEN Aspen3's generated config and seeded Noctalia theme
- WHEN upstream Niri validates the combined configuration
- THEN validation succeeds
- AND no unsupported fork-only action is bound
- AND touchpad palm rejection remains enabled
