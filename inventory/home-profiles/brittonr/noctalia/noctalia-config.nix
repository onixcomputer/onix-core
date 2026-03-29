{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Import each section, passing config as parameter
  bar = import ./noctalia-sections/bar.nix config;
  general = import ./noctalia-sections/general.nix config;
  notifications = import ./noctalia-sections/notifications.nix config;
  wallpaper = import ./noctalia-sections/wallpaper.nix config;
  launcher = import ./noctalia-sections/launcher.nix config;
  session = import ./noctalia-sections/session.nix config;
  system = import ./noctalia-sections/system.nix config;
  extras = import ./noctalia-sections/extras.nix config;

  templateDir = ./templates;
  activePalette = config.theme.active;

  # Generate starship palette template with the active palette name
  # instead of hardcoding it in a static file.
  starshipPaletteTemplate = pkgs.writeText "starship-palette.toml" ''
    [palettes.${activePalette}]
    color_bg1 = "{{colors.surface.default.hex}}"
    color_bg3 = "{{colors.surface_container_high.default.hex}}"
    color_cyan = "{{colors.on_surface_variant.default.hex}}"
    color_fg0 = "{{colors.on_surface.default.hex}}"
    color_gray = "{{colors.outline.default.hex}}"
    color_green = "{{colors.surface_container.default.hex}}"
    color_orange = "{{colors.on_surface.default.hex}}"
    color_red = "{{colors.on_surface_variant.default.hex | darken 5}}"
    color_yellow = "{{colors.on_surface_variant.default.hex | lighten 5}}"
  '';

  # NCL theme → Material 3 color mapping. Single definition used by both
  # programs.noctalia-shell.colors and the generated Onix.json colorscheme.
  mkM3Colors = t: {
    mPrimary = t.accent.hex;
    mOnPrimary = t.bg.hex;
    mSecondary = t.accent2.hex;
    mOnSecondary = t.bg.hex;
    mTertiary = t.purple.hex;
    mOnTertiary = t.bg.hex;
    mError = t.red.hex;
    mOnError = t.bg.hex;
    mSurface = t.bg.hex;
    mOnSurface = t.fg.hex;
    mSurfaceVariant = t.bg_highlight.hex;
    mOnSurfaceVariant = t.fg_dim.hex;
    mOutline = t.border.hex;
    mShadow = t.bg_dark.hex;
    mHover = t.bg_highlight.hex;
    mOnHover = t.fg.hex;
  };

  mkTerminalColors = t: {
    normal = {
      black = t.term_black.hex;
      red = t.term_red.hex;
      green = t.term_green.hex;
      yellow = t.term_yellow.hex;
      blue = t.term_blue.hex;
      magenta = t.term_magenta.hex;
      cyan = t.term_cyan.hex;
      white = t.term_white.hex;
    };
    bright = {
      black = t.term_bright_black.hex;
      red = t.term_bright_red.hex;
      green = t.term_bright_green.hex;
      yellow = t.term_bright_yellow.hex;
      blue = t.term_bright_blue.hex;
      magenta = t.term_bright_magenta.hex;
      cyan = t.term_bright_cyan.hex;
      white = t.term_bright_white.hex;
    };
    foreground = t.term_fg.hex;
    background = t.term_bg.hex;
    selectionFg = t.bg.hex;
    selectionBg = t.accent.hex;
    cursorText = t.bg.hex;
    cursor = t.accent.hex;
  };

  # Full colorscheme variant: M3 colors + terminal palette.
  mkVariant = t: mkM3Colors t // { terminal = mkTerminalColors t; };

  # Generated from onix-dark.ncl / onix-light.ncl — single source of truth.
  onixColorscheme = builtins.toJSON {
    dark = mkVariant config.theme.allData."onix-dark";
    light = mkVariant config.theme.allData."onix-light";
  };

  # Post-hook: replace starship palette section with template output,
  # then reload running instances via SIGHUP.
  starshipPostHook = pkgs.writeShellApplication {
    name = "starship-palette-update";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      STARSHIP="''${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
      PALETTE="''${XDG_CACHE_HOME:-$HOME/.cache}/noctalia/starship-palette.toml"
      [ -f "$STARSHIP" ] && [ -f "$PALETTE" ] || exit 0
      # Strip the header line from the generated palette fragment
      TMPCOLORS=$(mktemp)
      sed '1d' "$PALETTE" > "$TMPCOLORS"
      # Delete existing palette values, then insert new ones from file
      sed -i '/^\[palettes\.${activePalette}\]/,/^\[/{/^\[palettes\.${activePalette}\]/!{/^\[/!d}}' "$STARSHIP"
      sed -i "/^\[palettes\.${activePalette}\]/r $TMPCOLORS" "$STARSHIP"
      rm -f "$TMPCOLORS"
    '';
  };
in
{
  programs.noctalia-shell = {
    enable = true;

    colors = mkM3Colors config.theme.data;

    # User templates for apps without built-in Noctalia support.
    # Built-in templates handle: niri, kitty, btop, helix.
    # User templates handle: fish, bat, delta, eza, starship, swayosd, wezterm.
    user-templates = {
      templates = {
        fish = {
          input_path = "${templateDir}/fish-colors.fish";
          output_path = "~/.config/fish/conf.d/noctalia-colors.fish";
        };
        bat = {
          input_path = "${templateDir}/bat.tmTheme";
          output_path = "~/.config/bat/themes/noctalia.tmTheme";
          post_hook = "bat cache --build 2>/dev/null || true";
        };
        delta = {
          input_path = "${templateDir}/delta.gitconfig";
          output_path = "~/.config/git/noctalia-delta-colors";
        };
        eza = {
          input_path = "${templateDir}/eza-theme.yml";
          output_path = "~/.config/eza/theme.yml";
        };
        starship = {
          input_path = "${starshipPaletteTemplate}";
          output_path = "~/.cache/noctalia/starship-palette.toml";
          post_hook = lib.getExe starshipPostHook;
        };
        swayosd = {
          input_path = "${templateDir}/swayosd.css";
          output_path = "~/.config/swayosd/style.css";
          post_hook = "systemctl --user restart swayosd.service 2>/dev/null || true";
        };
        wezterm = {
          input_path = "${templateDir}/wezterm-colors.lua";
          output_path = "~/.config/wezterm/noctalia-colors.lua";
        };
      };
    };

    # Merge all section settings
    settings = bar // general // notifications // wallpaper // launcher // session // system // extras;

    # wl-walls as default wallpaper plugin — declarative so rebuilds
    # don't reset runtime tweaks (shape, dither, etc.).
    pluginSettings.wl-walls = {
      autoStart = true;
      shape = "random";
      fps = "30";
      speed = 1;
      lineWidth = 2.0;
      alpha = 0.85;
      fade = 0.005;
      ditherStrength = 0.0;
      ditherLevels = 8;
      ditherScale = 1.0;
      useThemeColors = true;
      bgColor = "#1d1f23";
      fgColors = "#fb4934,#98971a,#fcb157,#83a598,#d3869b,#8ec07c,#e4d398";
    };
  };

  # Install Onix color scheme where Noctalia discovers downloaded schemes.
  # Generated from onix-dark.ncl / onix-light.ncl — single source of truth.
  xdg.configFile."noctalia/colorschemes/Onix/Onix.json".text = onixColorscheme;
}
