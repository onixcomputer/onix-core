## Context

Herdr is available in current nixpkgs, but the root nixpkgs pin does not expose `pkgs.herdr`. A root nixpkgs bump makes unrelated `pnpm-10.29.2` insecurity handling block `britton-desktop` system evaluation, so this change uses a narrow `nixpkgs-herdr` input for Herdr only. The `britton-desktop` module already installs a few machine-specific tools directly from `environment.systemPackages`, including packages exposed by this repo's flake outputs.

## Decisions

### 1. Use nixpkgs Herdr

**Choice:** Use `inputs.nixpkgs-herdr.legacyPackages.${pkgs.stdenv.hostPlatform.system}.herdr` from a narrow nixpkgs input pinned to a revision where that package exists.

**Rationale:** `nix-shell -p herdr` confirms Herdr is packaged in nixpkgs. A narrow nixpkgs input keeps the source as nixpkgs, avoids a separate Herdr flake input or local package derivation, and avoids the unrelated fallout from advancing the root nixpkgs pin.

### 2. Install directly in `britton-desktop`

**Choice:** Add `herdr` to `machines/britton-desktop/configuration.nix` inside the existing `with pkgs;` package list.

**Rationale:** This keeps the change scoped to the requested machine and avoids exposing Herdr as an onix-core package when no local wrapper or overlay is needed.

### 3. Generate Herdr config from Nickel

**Choice:** Add a `brittonr/herdr` Home Manager profile for `britton-desktop`. Its `config.toml` is rendered from `inventory/home-profiles/brittonr/herdr/lib/config.ncl` with `pkgs.formats.toml`.

**Rationale:** Herdr's documented config file is `~/.config/herdr/config.toml`, so a wrapper is unnecessary for ordinary config. Nickel remains the source of truth and validates the small managed surface before Nix renders TOML.

### 4. Use the closest valid Alt-based Herdr prefix

**Choice:** Set `keys.prefix = "alt+space"` and remove Niri's Alt-based window bindings.

**Rationale:** The Herdr configuration docs describe explicit key strings such as `ctrl+b`, `alt+1`, and `esc`; Herdr 0.7.0's parser requires a non-modifier key, so bare `Alt` would be invalid and fall back to the default. `alt+space` keeps the prefix Alt-based without conflicting with normal text input, while removing Niri's `Alt+F` and `Alt+H/J/K/L` bindings prevents the window manager from stealing Alt chords before Herdr sees them.

### 5. Bind jj workspace plugin actions, but do not install plugins during activation

**Choice:** Render `[[keys.command]]` entries for `nathanflurry.jj-workspace.new`, `nathanflurry.jj-workspace.new-tab`, and `nathanflurry.jj-workspace.remove` from Nickel data. Keep `NathanFlurry/herdr-plugin-jj-workspace` as the documented Herdr install source instead of running `herdr plugin install` from Nix or Home Manager activation.

**Rationale:** Herdr plugin installation is explicitly a user-runtime operation that clones, previews, builds with Cargo, and writes Herdr-managed plugin state. Running that network/build side effect during Home Manager activation would make rebuilds impure and fragile. Declarative config can safely provide the action keybindings; the user can install or reinstall the trusted plugin with Herdr's native plugin command.

## Risks / Trade-offs

- The installed Herdr version follows the narrow `nixpkgs-herdr` pin until root nixpkgs catches up.
- Two nixpkgs pins are temporarily present, but only the Herdr package is sourced from the narrow pin.
- Bare `Alt` remains unsupported by the packaged Herdr config parser; if upstream adds modifier-only prefixes later, this profile can switch from `alt+space` to `alt`.
- jj workspace plugin keybindings require the plugin to be installed in Herdr state; this change avoids automatic network/build activation side effects.
