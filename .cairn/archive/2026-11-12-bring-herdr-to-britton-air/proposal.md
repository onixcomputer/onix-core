# Bring Herdr to britton-air

## Why

`britton-air` is the Darwin workstation that has no Herdr installation. The
fleet's Herdr setup exists on the Linux servers and britton-desktop, but the
laptop cannot run the terminal multiplexer, its plugin bundle, the desktop
`herdr-app`, or the herdr-iroh relay. Its Nix cannot evaluate this flake
because it lacks `builtins.wasm`, and its nix-darwin generation cannot receive
Home Manager profiles because the `home-manager-profiles` clan service exposes
only a NixOS module.

## What Changes

- Make `pkgs/herdr` platform-aware in onixpkgs: Collie is a systemd/Linux
  phone bridge, so the wrapped Herdr on Darwin keeps the other seven plugins
  and omits `herdr.collie` instead of depending on an unbuildable package.
- Add a `darwinModule` to `modules/home-manager-profiles` so profile
  assignments work on nix-darwin through Home Manager's darwin module.
- Give `britton-air` the same Herdr setup as `aspen3`: the wrapped core in
  system packages, `herdr-app` in the user profile, the Nickel-rendered
  `herdr/config.toml` and Neovim integration through the fleet `herdr` profile.
- Run the same herdr-iroh relay on Darwin as a per-user `launchd` agent: same
  `britton-grok` peer, gateway enabled, `pkgs.herdr` as `herdr_bin`, and a
  user-owned state directory. A system LaunchDaemon cannot spawn store
  binaries on this macOS, so the agent lives in the `herdr` Home Manager
  profile.
- Register the same saved SSH machines that aspen3's `brittonr` profile has
  (`britton-desktop`, `cproof-brittonr`, `instantfill-vm`) and verify them.
- Publish the onixpkgs package change, update the locked input, build the
  Darwin toplevel, and activate it on `britton-air`.

## Impact

The Linux fleet keeps its eight-plugin Herdr package, its systemd relay, and
its existing profiles. The shared `home-manager-profiles` module changes shape
but produces the same NixOS module. `britton-air` gains the Herdr core, app,
config, plugins, relay, and saved machines; no existing macOS settings or
services are replaced. Deployment uses `britton-air`'s remote store because its
Nix cannot evaluate the wasm-backed Nickel inventory.

## Affected Specs

- `workstation-tools`: Darwin package support, the britton-air installation
  and profile, the launchd relay, and the saved-machine state.
