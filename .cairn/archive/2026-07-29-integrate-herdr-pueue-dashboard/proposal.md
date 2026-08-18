## Why

`britton-desktop` installs Herdr `0.7.1` from the pinned `llm-agents` input. The Pueue dashboard requires Herdr `0.7.4` or newer for popup panes, so the live Herdr server cannot load its manifest.

## What Changes

- Update the existing `llm-agents` lock input to a revision that packages Herdr `0.7.5`.
- Add typed popup and split action chords for `dev.herdr.pueue` to the Herdr profile.
- Keep the plugin source in its separate repository and keep registration as a Herdr-managed runtime operation.
- Add focused positive and negative checks for the Herdr version and rendered Pueue action bindings.

## Impact

- **Files**: generated `flake.lock`, the shared Nickel keymap, the Herdr Nickel profile, its Nix rendering shell, and focused Home Manager checks.
- **Risk**: Updating `llm-agents` can update package definitions beyond Herdr, so focused system evaluation must verify the resulting desktop closure.
- **Non-goals**: Do not copy the plugin into `onix-core`, run network installation during activation, or restart the live Herdr server.
- **Testing**: Evaluate the typed profile, build the focused check, confirm Herdr `0.7.5`, and evaluate `britton-desktop`.
