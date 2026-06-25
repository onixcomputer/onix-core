{
  config,
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

  # NCL theme → Material 3 color mapping for the generated Onix.json palette.
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

in
{
  programs.noctalia = {
    enable = true;

    # The upstream v5 module validates the generated TOML at build time.
    # Keep validation disabled while the settings schema is migrating from the
    # older noctalia-shell module shape.
    validateConfig = false;

    customPalettes.Onix = builtins.fromJSON onixColorscheme;

    # Merge all section settings.
    settings = bar // general // notifications // wallpaper // launcher // session // system // extras;
  };

  xdg.configFile = {
    # Force-overwrite Noctalia configs — runtime writes can turn managed
    # symlinks into regular files, leaving .hm-bak files that block deploys.
    "noctalia/config.toml".force = true;
    "noctalia/palettes/Onix.json".force = true;
  };
}
