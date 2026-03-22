## ADDED Requirements

### Requirement: Single config.theme option replaces both color systems
The home-manager module SHALL expose a single `config.theme` option that provides all color data previously split between `config.colors` (CLI palette) and `config.theme.colors` (desktop themes). The `config.colors` option SHALL be removed.

#### Scenario: CLI consumer accesses semantic color
- **WHEN** a module references `config.theme.red.hex`
- **THEN** it receives the active theme's red hex string (e.g. `"#ff4444"`)

#### Scenario: CLI consumer accesses derived form
- **WHEN** a module references `config.theme.red.ansi`
- **THEN** it receives the pre-computed ANSI escape string (e.g. `"38;2;255;68;68"`)

#### Scenario: Desktop consumer accesses terminal color
- **WHEN** a module references `config.theme.term_red.hex`
- **THEN** it receives the active theme's terminal red hex string

#### Scenario: Consumer accesses extension block
- **WHEN** a module references `config.theme.editor.function_dark.hex`
- **THEN** it receives the editor function color hex string from the active theme

#### Scenario: Old config.colors reference fails
- **WHEN** a module references `config.colors`
- **THEN** Nix evaluation fails because the option no longer exists

### Requirement: Theme selection via config.theme.active
The home-manager module SHALL provide a `config.theme.active` option (enum of available theme names) that selects which NCL theme file to evaluate. Changing the active theme SHALL change all color values across all consumers.

#### Scenario: Select tokyo-night theme
- **WHEN** `config.theme.active = "tokyo-night"`
- **THEN** `config.theme.red.hex` returns `"#f7768e"` (tokyo-night red)

#### Scenario: Select onix-dark theme
- **WHEN** `config.theme.active = "onix-dark"`
- **THEN** `config.theme.red.hex` returns `"#ff4444"` (onix-dark red)

#### Scenario: Invalid theme name rejected
- **WHEN** `config.theme.active = "nonexistent"`
- **THEN** Nix evaluation fails with an error listing valid theme names

### Requirement: theme.nix merges package-dependent fields from a central map
The `theme.nix` option module SHALL contain a `themePackages` attrset mapping each theme name to its `pkgs`-dependent fields (GTK theme/icon packages, wallpaper fetchurl derivations). These fields SHALL be merged with the NCL-exported color data when `config.theme.active` is evaluated. No per-theme Nix wrapper files SHALL exist.

#### Scenario: GTK package available on config.theme
- **WHEN** a module references `config.theme.gtk.theme.package`
- **THEN** it receives a Nix derivation (e.g. `pkgs.tokyonight-gtk-theme`) from the `themePackages` map

#### Scenario: Wallpaper fetchurl available on config.theme
- **WHEN** a module references `config.theme.wallpapers.collection."tokyo-night_nix.png".source`
- **THEN** it receives a Nix store path from `pkgs.fetchurl` defined in the `themePackages` map

#### Scenario: Theme without packages entry still works
- **WHEN** a theme has no entry in `themePackages`
- **THEN** `config.theme` contains only the NCL-exported color data with no package fields

### Requirement: All 17 consumers updated to unified API
Every module that currently references `config.colors` or `config.theme.colors` SHALL be updated to use `config.theme` with the new derived-form API. No module SHALL use the old `noHash`, `hexToRgb`, or `hexToAnsi` utility functions.

#### Scenario: shell-theme.nix uses new API
- **WHEN** fish shell theme references foreground color
- **THEN** it uses `config.theme.fg.no_hash` instead of `config.colors.noHash config.colors.fg`

#### Scenario: eza.nix uses new API
- **WHEN** eza theme references blue color ANSI code
- **THEN** it uses `config.theme.blue.ansi` instead of `config.colors.hexToAnsi config.colors.blue`

#### Scenario: kitty.nix uses new API
- **WHEN** kitty config references terminal red
- **THEN** it uses `config.theme.term_red.hex` instead of `config.theme.colors.term_red`

#### Scenario: noctalia-config.nix uses new API
- **WHEN** Noctalia Material You mapping references accent color
- **THEN** it uses `config.theme.accent.hex` instead of `config.colors.accent`

### Requirement: Consumer configs support Noctalia runtime override
Every consumer module that outputs a config file SHALL structure it so Noctalia can override colors at runtime without a NixOS rebuild. Apps with include/source support SHALL include a Noctalia-generated override file. Per-invocation tools SHALL read from a config file that Noctalia can update.

#### Scenario: Fish picks up Noctalia colors on next prompt
- **WHEN** Noctalia writes `~/.config/fish/conf.d/noctalia-colors.fish` with updated `set -g` commands
- **THEN** the next fish prompt uses the new colors

#### Scenario: Helix picks up Noctalia theme automatically
- **WHEN** Noctalia writes `~/.config/helix/themes/noctalia-dark.toml`
- **THEN** helix detects the file change and applies the new theme colors

#### Scenario: btop picks up Noctalia theme
- **WHEN** Noctalia writes `~/.config/btop/themes/custom-theme.theme`
- **THEN** btop applies the new colors on its next refresh cycle

#### Scenario: Starship picks up palette change on next prompt
- **WHEN** Noctalia writes an updated palette section to `~/.config/starship.toml`
- **THEN** the next starship prompt render uses the new colors

#### Scenario: eza picks up colors on next invocation
- **WHEN** Noctalia updates the eza theme config file
- **THEN** the next `eza` invocation uses the new colors

### Requirement: Noctalia theme sync script propagates colors to all apps
A `noctalia-theme-sync` script SHALL be generated by Nix and installed to the user's PATH. The script SHALL read Noctalia's current color state and write override config files for all themed apps. Noctalia's `darkModeChange` and `wallpaperChange` hooks SHALL call this script.

#### Scenario: Wallpaper change triggers full theme sync
- **WHEN** the user changes their wallpaper in Noctalia
- **THEN** the wallpaperChange hook runs `noctalia-theme-sync` and all apps receive updated colors

#### Scenario: Dark mode toggle triggers full theme sync
- **WHEN** darkman or the user toggles dark/light mode
- **THEN** the darkModeChange hook runs `noctalia-theme-sync` and all apps switch to the appropriate variant

#### Scenario: Sync script is idempotent
- **WHEN** `noctalia-theme-sync` runs twice with the same Noctalia colors
- **THEN** the output config files are identical and no unnecessary app restarts occur

### Requirement: Flake check validates no stale color references
A flake check SHALL verify that no Nix file under `inventory/home-profiles/` references `config.colors` (the removed option) or calls the removed utility functions (`noHash`, `hexToRgb`, `hexToAnsi`).

#### Scenario: Stale reference detected
- **WHEN** a Nix file contains `config.colors.red`
- **THEN** `nix flake check` fails with a message identifying the file and suggesting the new API

#### Scenario: Clean codebase passes
- **WHEN** no Nix file references the old API
- **THEN** `nix flake check` passes the stale-reference check
