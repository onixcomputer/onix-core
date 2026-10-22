# Herdr Fleet Installation

## Context

Herdr is already packaged by `pkgs/herdr` with a static seven-plugin registry and runtime commands. Machine configurations select that package through `self.packages`; the `brittonr/herdr` profile renders typed TOML and the Neovim navigation adapter.

## Decisions

- Reuse the machine-local package pattern from Aspen3. Preserve the existing packages on Aspen1, Aspen2, and Bonsai.
- Rename the Aspen3-specific Home Manager instance to `hm-herdr-fleet` and explicitly target Aspen1, Aspen2, Aspen3, and Bonsai. This avoids enabling Herdr on unrelated machines through broad server or laptop tags.
- Keep britton-desktop's existing profile list unchanged. Do not change Herdr versions, plugins, keybindings, user state, or activation behavior.

## Verification

Evaluate every target's Herdr package selection, generated `herdr/config.toml`, Neovim adapter, and NixOS system derivation. Build the shared wrapper and generated TOML, then run `herdr config check` against the generated config using a temporary home. Validate the native Cairn change and repository policy. No remote activation is part of this change.
