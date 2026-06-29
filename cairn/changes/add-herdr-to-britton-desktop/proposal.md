## Why

`britton-desktop` should provide Herdr as a declarative workstation tool so the terminal agent multiplexer is available after normal system rebuilds instead of being installed imperatively with curl, Homebrew, or mise.

## What Changes

- Add a narrow `nixpkgs-herdr` input pinned to a `nixpkgs-unstable` revision that exposes `herdr`.
- Install that nixpkgs `herdr` package in `britton-desktop` system packages.
- Add a desktop-scoped Home Manager Herdr profile whose `config.toml` is generated from typed Nickel data.
- Configure Herdr with an Alt-based prefix chord and disable Nix-inappropriate upstream update checks.
- Add keybindings for the `NathanFlurry/herdr-plugin-jj-workspace` plugin actions.
- Remove Niri's Alt keybindings so Herdr owns Alt-prefixed terminal chords.
- Avoid adding a separate Herdr flake input because Herdr is available from nixpkgs.
- Preserve existing workstation package additions such as `ttsim`.

## Impact

- **Scope**: narrow nixpkgs package input, lock node, `britton-desktop` system package set, desktop Home Manager profile assignment, Herdr config generation, and Niri Alt bindings.
- **Risk**: The Herdr package comes from a second nixpkgs pin until the root nixpkgs pin catches up. Bare `Alt` is not a valid Herdr 0.7.0 `keys.prefix`, so the managed config uses `alt+space` as the closest valid Alt-based prefix chord.
- **Testing**: Evaluate the `britton-desktop` system derivation, verify the rendered package list includes `herdr` and rejects a bogus Herdr package name, export the Nickel-backed Herdr/Niri data, and verify rendered desktop Home Manager config includes `herdr/config.toml` with the Alt-based prefix and jj workspace plugin action bindings.
