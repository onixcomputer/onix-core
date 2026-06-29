## Why

`britton-desktop` should provide Herdr as a declarative workstation tool so the terminal agent multiplexer is available after normal system rebuilds instead of being installed imperatively with curl, Homebrew, or mise.

## What Changes

- Add a narrow `nixpkgs-herdr` input pinned to a `nixpkgs-unstable` revision that exposes `herdr`.
- Install that nixpkgs `herdr` package in `britton-desktop` system packages.
- Avoid adding a separate Herdr flake input because Herdr is available from nixpkgs.
- Preserve existing workstation package additions such as `ttsim`.

## Impact

- **Scope**: narrow nixpkgs package input, lock node, and `britton-desktop` system package set.
- **Risk**: The Herdr package comes from a second nixpkgs pin until the root nixpkgs pin catches up.
- **Testing**: Evaluate the `britton-desktop` system derivation and verify the rendered package list includes `herdr` and rejects a bogus Herdr package name.
