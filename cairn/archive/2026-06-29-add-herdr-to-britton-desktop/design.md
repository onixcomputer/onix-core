## Context

Herdr is available from `numtide/llm-agents.nix` under `packages/herdr/package.nix`. The repo already pins `llm-agents` for terminal AI agent packages, so this change uses that existing package set instead of carrying a narrow `nixpkgs-herdr` input for Herdr only. The `britton-desktop` module already installs a few machine-specific tools directly from `environment.systemPackages`, including packages exposed by this repo's flake outputs.

## Decisions

### 1. Use llm-agents.nix Herdr

**Choice:** Use `inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.herdr` from the existing `numtide/llm-agents.nix` input.

**Rationale:** The `llm-agents` input already contains the Herdr package definition under `packages/herdr/package.nix`, including the source build and Zig cache handling needed by upstream Herdr. Reusing that input avoids a separate Herdr flake input, a local package derivation, or a temporary extra nixpkgs pin.

### 2. Install directly in `britton-desktop`

**Choice:** Add `herdr` to `machines/britton-desktop/configuration.nix` inside the existing `with pkgs;` package list.

**Rationale:** This keeps the change scoped to the requested machine and avoids exposing Herdr as an onix-core package when no local wrapper or overlay is needed.

### 3. Generate Herdr config from Nickel

**Choice:** Add a `brittonr/herdr` Home Manager profile for `britton-desktop`. Its `config.toml` is rendered from `inventory/home-profiles/brittonr/herdr/lib/config.ncl` with `pkgs.formats.toml`, and Herdr-specific chords are derived from the shared `inventory/home-profiles/brittonr/base/keymap.ncl` source.

**Rationale:** Herdr's documented config file is `~/.config/herdr/config.toml`, so a wrapper is unnecessary for ordinary config. Nickel remains the source of truth and validates the small managed surface before Nix renders TOML. Reusing the shared keymap keeps Herdr aligned with the same modifier and action-key conventions consumed by Niri, terminal emulators, Helix, and shell bindings.

### 4. Use the closest valid Alt-based Herdr prefix

**Choice:** Set `keys.prefix = "alt+space"` and remove Niri's Alt-based window bindings.

**Rationale:** The Herdr configuration docs describe explicit key strings such as `ctrl+b`, `alt+1`, and `esc`; Herdr 0.7.0's parser requires a non-modifier key, so bare `Alt` would be invalid and fall back to the default. `alt+space` keeps the prefix Alt-based without conflicting with normal text input, while removing Niri's `Alt+F` and `Alt+H/J/K/L` bindings prevents the window manager from stealing Alt chords before Herdr sees them.

### 5. Bind jj workspace plugin actions, but do not install plugins during activation

**Choice:** Render `[[keys.command]]` entries for `nathanflurry.jj-workspace.new`, `nathanflurry.jj-workspace.new-tab`, and `nathanflurry.jj-workspace.remove` from Nickel data. Keep `NathanFlurry/herdr-plugin-jj-workspace` as the documented Herdr install source instead of running `herdr plugin install` from Nix or Home Manager activation.

**Rationale:** Herdr plugin installation is explicitly a user-runtime operation that clones, previews, builds with Cargo, and writes Herdr-managed plugin state. Running that network/build side effect during Home Manager activation would make rebuilds impure and fragile. Declarative config can safely provide the action keybindings; the user can install or reinstall the trusted plugin with Herdr's native plugin command.

## Risks / Trade-offs

- The installed Herdr version follows the pinned `llm-agents` input.
- Herdr shares the existing `llm-agents` source used for other terminal AI tools instead of adding a package-only nixpkgs pin.
- Bare `Alt` remains unsupported by the packaged Herdr config parser; if upstream adds modifier-only prefixes later, this profile can switch from `alt+space` to `alt`.
- jj workspace plugin keybindings require the plugin to be installed in Herdr state; this change avoids automatic network/build activation side effects.
