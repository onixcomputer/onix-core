## Context

The repo has two color systems that evolved independently:

1. **`config.colors`** — brittonr's CLI palette defined in 8 Nix files under `inventory/home-profiles/brittonr/base/colors/`. Consumed by 12 modules (fish, starship, eza, helix, btop, bat, git/delta, media, bar/waybar, noctalia Material You mapping, niri screencast, shell-theme). Carries utility functions (`noHash`, `hexToRgb`, `hexToAnsi`) as part of the option value.

2. **`config.theme.colors`** — Desktop theme system with 5 themes built through `mk-theme.nix`. Consumed by 5 modules (kitty, niri, swayosd, btop-shared, theme.nix itself for GTK/Qt). Uses base16 surface ramp (base00-07), semantic colors, terminal 16-color palette, and app-specific blocks (hypr, gtk, waybar, wallpapers, opacity).

Both define red/orange/yellow/green/cyan/blue/purple/magenta. The hex→RGB conversion is duplicated. Neither validates hex format. The repo already uses NCL with contracts for machines, services, and sysctl — and has a WASM-based `evalNickelFile` in `lib/wasm.nix`.

## Goals / Non-Goals

**Goals:**
- Single `config.theme` option consumed by all 17 modules
- NCL contracts validate hex color format and theme schema completeness
- NCL pre-computes all derived forms (noHash, rgb, ansi) — no utility functions in Nix
- CLI sub-palettes (editor, zen, rainbow, btop, waybar, misc) are optional theme extensions
- Existing themes (tokyo-night, onix-dark, onix-light, everblush, solarized-dark) preserved
- `pkgs`-dependent fields (GTK packages, wallpaper fetchurl) handled cleanly in Nix
- Noctalia controls system-wide theming at runtime — all apps update live when wallpaper/dark-mode changes
- Each consumer's config supports runtime override from Noctalia-generated files

**Non-Goals:**
- Generating themes from wallpaper colors (Material You stays in Noctalia upstream)
- Moving non-color config to NCL (hyprland gaps/rounding, opacity values stay in theme but aren't the focus)
- Upstream contribution of NCL theme tooling
- Writing new Noctalia built-in template plugins (use hooks + scripts instead)

## Decisions

### 1. NCL pre-computes derived forms instead of carrying Nix utility functions

**Choice**: Every color in the NCL palette exports a record `{ hex, no_hash, rgb, ansi }` instead of a raw string.

**Rationale**: Currently `c.hexToAnsi c.blue` and `c.noHash c.fg` are called at Nix eval time. Moving colors to NCL means the JSON export has no functions. Pre-computing is the clean answer — NCL has the string manipulation to do hex→decimal conversion, and the consumer API becomes `c.blue.hex` / `c.blue.ansi` instead of `c.hexToAnsi c.blue`.

**Alternative considered**: Keep utility functions in Nix, import raw hex from NCL. Rejected because it splits the color logic across two languages and still requires the Nix-side helpers. The whole point is that NCL owns the color domain.

**API change**: `c.red` → `c.red.hex` (or `c.red.no_hash`, `c.red.rgb`, `c.red.ansi`). All 17 consumers update. Since we're already touching every consumer for the unification, this cost is absorbed.

### 2. Theme file structure: NCL for data, package map in theme.nix

```
inventory/home-profiles/shared/desktop/themes/
├── contracts.ncl          # Color + theme schema contracts
├── mk-theme.ncl           # Builder: defaults, derived forms, validation
├── tokyo-night.ncl        # Pure color data
├── onix-dark.ncl          # Pure color data
├── onix-light.ncl
├── everblush.ncl
└── solarized-dark.ncl
```

`theme.nix` (the option module) contains a single `themePackages` attrset mapping theme names to their `pkgs`-dependent fields:

```nix
themePackages = {
  tokyo-night = {
    gtk.theme = { name = "Tokyonight-Dark"; package = pkgs.tokyonight-gtk-theme; };
    gtk.iconTheme = { name = "Papirus-Dark"; package = pkgs.papirus-icon-theme; };
    wallpapers.collection."tokyo-night_nix.png" = {
      source = pkgs.fetchurl { url = "..."; sha256 = "..."; };
    };
  };
  onix-dark = { ... };
};
```

**Rationale**: NCL owns all color/style data and validates it. Package references live in one place (`theme.nix`) instead of scattered across per-theme wrapper files. Adding a theme means one NCL file + one attrset entry. No wrapper directory, no boilerplate.

**Alternative considered**: Per-theme Nix wrapper files that each call `evalNickelFile` and merge packages. Rejected — unnecessary ceremony for 3-4 fields per theme. A single attrset is clearer and easier to maintain.

### 3. CLI sub-palettes become optional theme extensions

**Choice**: The theme schema has required fields (base00-07, semantic colors, terminal 16-color) and optional extension blocks (`editor`, `zen`, `rainbow`, `btop`, `waybar`, `misc`). The NCL `mk-theme` builder provides defaults for extensions when omitted.

**Rationale**: Desktop themes (tokyo-night, everblush) don't need to define editor semantic colors or zen-mode palettes — those are brittonr's personal additions. But onix-dark does. Making them optional keeps community themes simple while allowing full customization.

### 4. Unified option is `config.theme`, not `config.colors`

**Choice**: The merged option lives at `config.theme` with sub-attrs for everything. `config.colors` is removed.

**Rationale**: `theme` is the broader concept — it includes colors but also opacity, waybar styling, hyprland borders. The desktop system already uses `config.theme.colors` so this is the smaller migration for desktop consumers.

### 5. Reuse existing `evalNickelFile` WASM infrastructure

**Choice**: Use `lib/wasm.nix`'s `evalNickelFile` to consume NCL themes at Nix eval time. No `ncl` CLI dependency at build time.

**Rationale**: Already proven in the repo for machines/services. The WASM evaluator handles imports, so `mk-theme.ncl` can import `contracts.ncl` normally.

### 6. Noctalia as runtime color authority

**Choice**: All consumer configs are structured so Noctalia can override colors at runtime. Three patterns depending on app capability:

**Pattern A — Include override file** (apps with include/source support):
Build-time Nix writes the base config. An include at the end loads a Noctalia-generated override file (last-write-wins). Noctalia already does this for niri (`include "./noctalia.kdl"`) and kitty (`include themes/noctalia.conf`). Extend to:
- **helix** — theme files in `~/.config/helix/themes/`. Helix auto-watches for changes. Noctalia writes `noctalia-dark.toml` / `noctalia-light.toml`.
- **fish** — `conf.d/` directory sourced on each prompt. Noctalia writes `conf.d/noctalia-colors.fish` with `set -g` commands.
- **btop** — theme file at `~/.config/btop/themes/`. btop watches for changes. Noctalia overwrites the theme file.
- **swayosd** — CSS file at `stylePath`. Noctalia overwrites and restarts service via hook.

**Pattern B — Re-read on invocation** (per-invocation CLI tools):
These read config each time they run. Noctalia updates the config file; next invocation picks it up automatically. No reload signal needed.
- **bat** — tmTheme file, rebuilt via hook script
- **delta** — reads gitconfig includes, Noctalia writes an include file
- **eza** — reads theme config, Noctalia writes the theme file
- **starship** — re-reads `starship.toml` on each prompt render. Noctalia overwrites the palette section.

**Pattern C — Hook script** (apps needing restart/special handling):
Noctalia's `hooks.darkModeChange` and `hooks.wallpaperChange` run scripts that regenerate configs and restart services.
- **swayosd** — rewrite CSS + `systemctl --user restart swayosd`

**Rationale**: Noctalia already has the template system (niri, kitty built-in) and hooks (darkModeChange, wallpaperChange). Rather than writing upstream Noctalia template plugins for every app, use hooks with a single `noctalia-theme-sync.sh` script that regenerates all config files from Noctalia's exported color variables. The Nix-built configs become the seed/default; Noctalia overrides at runtime.

**Alternative considered**: Writing individual Noctalia template plugins for each app. Rejected — requires upstream Noctalia changes or forking. Hook scripts achieve the same result with existing infrastructure.

### 7. Noctalia theme sync script

**Choice**: A single `noctalia-theme-sync.sh` script (generated by Nix, installed to `~/.local/bin/`) reads Noctalia's current color state and regenerates config snippets for all apps. Noctalia's hooks call this script on wallpaper/dark-mode changes.

The script reads Noctalia's color export (Material You palette exposed via `noctalia-shell color-export` or the dconf schema) and writes override files for each app using templates baked in by Nix at build time.

**Rationale**: One script, one hook entry, all apps update. Each app's template is a heredoc in the script with color variable substitution. Build-time Nix controls *which* apps get templates (based on which home-manager modules are active). Runtime Noctalia controls *what colors* fill them.

## Risks / Trade-offs

**[API churn across 17 files]** → One-time migration. Mechanical find-replace for most consumers (`c.red` → `c.red.hex`, `c.noHash c.fg` → `c.fg.no_hash`, `c.hexToAnsi c.blue` → `c.blue.ansi`). Write a validation check that `config.colors` is no longer referenced.

**[NCL string manipulation for hex→decimal]** → NCL doesn't have native hex parsing. Need to implement `hex_to_dec` in NCL using match/array. This is ~20 lines, tested once, used by `mk-theme.ncl`. Alternatively, compute derived forms via a simple Nix function at import time and pass them through — but this defeats the goal of NCL owning the color domain.

**[Package map maintenance]** → Adding a theme requires both an NCL file and an entry in `themePackages`. Mitigated by the fact that the NCL file is the real work — the package entry is 5-6 lines of boilerplate and rarely changes.

**[Debugging NCL eval errors]** → NCL contract violations produce clear error messages ("unknown tag", "invalid hex color"). Worse case is the WASM eval failing opaquely — mitigated by running `ncl export` directly during development for better error output.

**[Noctalia color export API stability]** → The script depends on how Noctalia exposes its current colors (dconf, env vars, or CLI). If the API changes upstream, the sync script breaks. Mitigated by pinning the Noctalia input and wrapping the color-read in a function that's easy to update.

**[Apps that can't reload]** → Some apps (bat tmTheme compilation) have heavier reload requirements. Mitigated by accepting that per-invocation tools just pick up changes on next run — no user-visible lag.

**[Fish color persistence]** → Fish `set -g` in `conf.d/` only affects new shells, not existing ones. Mitigated by also running `fish -c 'source conf.d/noctalia-colors.fish'` in running sessions via the hook, or accepting that existing shells keep old colors until next prompt.
