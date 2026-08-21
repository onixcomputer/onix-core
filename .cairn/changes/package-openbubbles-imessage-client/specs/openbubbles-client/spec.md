# OpenBubbles Desktop Client Specification Delta

## Purpose

Provide a Nix-packaged OpenBubbles desktop client for x86_64-linux and replace the legacy BlueBubbles install in the social profile.

## ADDED Requirements

### Requirement: OpenBubbles package wraps the pinned release bundle

r[onix.openbubbles.package] The repository MUST provide an `openbubbles` package for x86_64-linux that wraps the pinned official release tarball, keeps the Flutter bundle layout with `data/` and `lib/` beside the executable, and resolves every bundled ELF file against the system libraries reported by `ldd` on that artifact.

#### Scenario: Release bundle patches cleanly

r[onix.openbubbles.package.patches]

- GIVEN the pinned OpenBubbles Linux release tarball
- WHEN the package builds on x86_64-linux
- THEN every bundled ELF binary resolves its required shared libraries
- AND the packaged executable launches under the bundled wrapper

#### Scenario: Bundle layout is preserved

r[onix.openbubbles.package.layout]

- GIVEN the built `openbubbles` package
- WHEN its bundle is inspected
- THEN the executable, `data/`, and `lib/` are siblings in a read-only store path
- AND the wrapper exports the packaged `lib/` on `LD_LIBRARY_PATH`

### Requirement: OpenBubbles is exposed as a flake package

r[onix.openbubbles.flake] The flake MUST expose `openbubbles` in its x86_64-linux package set.

#### Scenario: Flake package evaluates

r[onix.openbubbles.flake.evaluates]

- GIVEN the onix-core flake on x86_64-linux
- WHEN the `openbubbles` package attribute is evaluated
- THEN the derivation builds and its store path contains the `openbubbles` executable

### Requirement: Social profile installs OpenBubbles

r[onix.openbubbles.profile] The shared social Home Manager profile MUST install the local `openbubbles` package instead of the legacy `bluebubbles` package.

#### Scenario: Desktop social profile contains OpenBubbles

r[onix.openbubbles.profile.desktop]

- GIVEN the `brittonr` social profile enabled on `britton-desktop`
- WHEN the Home Manager configuration evaluates
- THEN `openbubbles` is present among the user packages
- AND `bluebubbles` is absent from that list

### Requirement: Change gates cleanly

r[onix.openbubbles.gates] The change MUST pass Cairn validation and gates, repository formatting and lint hooks, and focused package and profile checks.

#### Scenario: Validation and lint pass

r[onix.openbubbles.gates.pass]

- GIVEN the completed change package
- WHEN Cairn validation and the proposal, design, and tasks gates run with treefmt, deadnix, and statix
- THEN all gates pass
- AND formatting and lint checks report no violations
