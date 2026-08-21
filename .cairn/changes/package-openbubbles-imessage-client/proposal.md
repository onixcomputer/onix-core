# Package OpenBubbles Desktop Client

## Why

The social Home Manager profile installs `pkgs.bluebubbles`, the legacy BlueBubbles client. That client requires an always-on companion Mac server and is inert without one. OpenBubbles is the serverless fork: it talks to Apple directly, needs a Mac only once for hardware activation, and is packaged nowhere (no nixpkgs entry, no local package). The desktop fleet runs only x86_64-linux machines, so the official Linux release bundle is a safe, non-Mac target.

## What Changes

- Add a local `openbubbles` package (`pkgs/openbubbles`) that wraps the pinned official Linux release tarball with `autoPatchelfHook` and keeps the Flutter bundle layout (`data/` and `lib/` beside the executable).
- Expose `openbubbles` as an x86_64-linux flake package in `flake-outputs/tools.nix`.
- Replace the legacy `pkgs.bluebubbles` install in the shared social profile with the local `openbubbles` package.

## Impact

- **Files**: `pkgs/openbubbles/default.nix`, `flake-outputs/tools.nix`, `inventory/home-profiles/shared/social/openbubbles.nix` (replaces `bluebubbles.nix`), `inventory/home-profiles/brittonr/social/import.nix`.
- **Risk**: None beyond the desktop profile switching messaging clients. The legacy package remains available in nixpkgs if it needs to be re-added.
- **Non-goals**: No clan service module, no secret management (activation is interactive in the app), no iPhone/phone-number registration wiring, no Android packaging, no source-level Flutter build.
- **Testing**: Build the `openbubbles` package, verify all bundled ELF files resolve their libraries, run treefmt, deadnix, and statix, evaluate the britton-desktop social profile, and gate the change.
