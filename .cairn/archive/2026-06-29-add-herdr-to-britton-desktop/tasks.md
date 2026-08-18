## Phase 1: Add Herdr declaratively

- [x] [serial] Use the existing `llm-agents` input that exposes `packages.${system}.herdr`. r[onix.britton-desktop.herdr.source]
- [x] [serial] Remove the narrow `nixpkgs-herdr` input now that `llm-agents` provides Herdr. r[onix.britton-desktop.herdr.source]
- [x] [serial] Add Herdr to `britton-desktop` system packages without removing existing package entries. r[onix.britton-desktop.herdr.install]

## Phase 2: Configure Herdr key handling

- [x] [serial] Add a desktop-scoped Home Manager Herdr profile backed by typed Nickel data. r[onix.britton-desktop.herdr.config]
- [x] [serial] Render Herdr `config.toml` with `keys.prefix = "alt+space"` derived from the shared keymap, `onboarding = false`, and Nix-appropriate update checks disabled. r[onix.britton-desktop.herdr.config]
- [x] [serial] Add Herdr plugin-action keybindings for the jj workspace plugin without running network plugin installs during activation. r[onix.britton-desktop.herdr.jj-plugin]
- [x] [serial] Remove Niri Alt bindings so Herdr owns Alt-prefixed terminal chords. r[onix.britton-desktop.herdr.niri-alt]

## Phase 3: Validate

- [x] [serial] Evaluate the `britton-desktop` system derivation before the change to establish a baseline. r[onix.britton-desktop.herdr.verification]
- [x] [serial] Evaluate the `britton-desktop` system derivation after the change. r[onix.britton-desktop.herdr.verification]
- [x] [serial] Verify the rendered package list includes `herdr` and does not accidentally match a bogus Herdr package name. r[onix.britton-desktop.herdr.package-list]
- [x] [serial] Validate the Nickel-backed Herdr profile exports the expected managed config and jj workspace plugin bindings. r[onix.britton-desktop.herdr.config] r[onix.britton-desktop.herdr.jj-plugin]
- [x] [serial] Validate the Niri keybinding data no longer contains Alt bindings. r[onix.britton-desktop.herdr.niri-alt]
- [x] [serial] Evaluate focused `britton-desktop` Home Manager config with the Herdr profile. r[onix.britton-desktop.herdr.verification]
