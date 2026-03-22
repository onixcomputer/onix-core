## 1. NCL Contracts and Color Utilities

- [x] 1.1 Create `inventory/home-profiles/shared/desktop/themes/contracts.ncl` with `HexColor` contract (validates `^#[0-9a-fA-F]{6}$`)
- [x] 1.2 Implement `mk_color` function in contracts.ncl: takes hex string, returns `{ hex, no_hash, rgb, ansi }` with hex→decimal conversion
- [x] 1.3 Write `ThemeSchema` contract: required fields (base00-07, semantic colors, terminal 16-color), optional extension blocks (editor, zen, rainbow, btop, waybar, misc)
- [x] 1.4 Test contracts with `ncl export` — verify valid themes pass, invalid hex rejected, missing fields rejected

## 2. NCL Theme Builder

- [x] 2.1 Create `inventory/home-profiles/shared/desktop/themes/mk-theme.ncl` — accepts theme spec, merges defaults (terminal colors from semantic, optional extensions, opacity, waybar), applies `mk_color` to all color fields
- [x] 2.2 Port `tokyo-night.nix` → `tokyo-night.ncl` using mk-theme builder
- [x] 2.3 Port `onix-dark.nix` → `onix-dark.ncl`
- [x] 2.4 Port `onix-light.nix` → `onix-light.ncl`
- [x] 2.5 Port `everblush.nix` → `everblush.ncl`
- [x] 2.6 Port `solarized-dark.nix` → `solarized-dark.ncl`
- [x] 2.7 Fold CLI sub-palettes into theme schema: merge `colors/editor.nix`, `colors/zen.nix`, `colors/rainbow.nix`, `colors/btop.nix`, `colors/bar.nix`, `colors/misc.nix` into onix-dark.ncl as extension blocks (and defaults in mk-theme.ncl)

## 3. Rewrite theme.nix

- [x] 3.1 Rewrite `inventory/home-profiles/shared/desktop/theme.nix` — call `evalNickelFile` on the active theme's NCL file, add `themePackages` attrset mapping theme names to pkgs-dependent fields (GTK packages, icon themes, wallpaper fetchurl), merge both into unified `config.theme` option, remove `config.theme.colors` indirection and `config.colors` option

## 4. Migrate CLI Consumers (config.colors → config.theme)

- [x] 4.1 Update `shell-theme.nix`: `c.noHash c.fg` → `c.fg.no_hash`, etc.
- [x] 4.2 Update `starship.nix`: `c.grayscale.white` → `c.grayscale.white.hex`, etc.
- [x] 4.3 Update `eza.nix`: `c.hexToAnsi c.blue` → `c.blue.ansi`, etc.
- [x] 4.4 Update `helix-theme.nix`: `c.red` → `c.red.hex`, `e.function_dark` → `c.editor.function_dark.hex`, etc.
- [x] 4.5 Update `helix-zen-theme.nix`: zen sub-palette references
- [x] 4.6 Update `btop-theme.nix`: `c.btop.*` → `c.btop.*.hex`
- [x] 4.7 Update `bat.nix`: color references to `.hex`
- [x] 4.8 Update `git.nix` (delta): `c.red` → `c.red.hex`, etc.
- [x] 4.9 Update `media.nix`: color references
- [x] 4.10 Update `bar.nix`: `config.colors.orange` → `config.theme.orange.hex`, waybar sub-palette
- [x] 4.11 Update `noctalia-config.nix`: Material You mapping `config.colors.accent` → `config.theme.accent.hex`
- [x] 4.12 Update `niri.nix`: screencast colors `config.colors.screencast_active` → `config.theme.screencast_active.hex`

## 5. Migrate Desktop Consumers (config.theme.colors → config.theme)

- [x] 5.1 Update `kitty.nix`: `theme.term_red` → `config.theme.term_red.hex`, etc.
- [x] 5.2 Update `niri.nix` (desktop parts): `theme.accent` → `config.theme.accent.hex`, hypr block
- [x] 5.3 Update `swayosd.nix`: `config.theme.colors` → `config.theme`
- [x] 5.4 Update `btop.nix` (shared): `theme.accent` → `config.theme.accent.hex`, etc.

## 6. Noctalia Runtime Theme Sync

- [x] 6.1 Create `noctalia-theme-sync.sh` script template in Nix — reads Noctalia's color export, writes override files for each app
- [x] 6.2 Add fish override: script writes `~/.config/fish/conf.d/noctalia-colors.fish` with `set -g fish_color_*` commands
- [x] 6.3 Add starship override: script writes palette section to `~/.config/starship.toml` (or a separate included file)
- [x] 6.4 Add helix override: script writes `~/.config/helix/themes/noctalia-dark.toml` and `noctalia-light.toml`
- [x] 6.5 Add btop override: script writes `~/.config/btop/themes/custom-theme.theme`
- [x] 6.6 Add eza override: script writes eza theme config with ANSI color codes
- [x] 6.7 Add delta override: script writes git include file with delta color settings
- [x] 6.8 Add bat override: script writes tmTheme file and rebuilds bat cache
- [x] 6.9 Add swayosd override: script writes CSS file and restarts swayosd service
- [x] 6.10 Wire hooks in `noctalia-sections/extras.nix`: set `hooks.darkModeChange` and `hooks.wallpaperChange` to call `noctalia-theme-sync`
- [x] 6.11 Restructure consumer configs to support include/override pattern — each app's Nix config becomes the seed, Noctalia override file is included last (last-write-wins)

## 7. Cleanup and Validation

- [x] 7.1 Remove `inventory/home-profiles/brittonr/base/colors.nix` (option definition) and `colors/` directory (8 sub-palette files)
- [x] 7.2 Remove `inventory/home-profiles/shared/desktop/themes/mk-theme.nix` and old `.nix` theme files (tokyo-night.nix, onix-dark.nix, onix-light.nix, everblush.nix, solarized-dark.nix)
- [x] 7.3 Add flake check: grep for `config.colors` references in home-profiles Nix files, fail if found
- [x] 7.4 Build all machines with `build <machine>` to verify no eval errors
- [x] 7.5 Verify `ncl export` on each theme file produces valid JSON with all expected fields
- [ ] 7.6 Test runtime sync: change wallpaper, verify all app configs update and apps reflect new colors
