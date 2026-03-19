{ config, ... }:
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
in
{
  programs.noctalia-shell = {
    enable = true;

    # Material 3 color mapping from theme palette
    colors = {
      mPrimary = config.theme.data.accent.hex;
      mOnPrimary = config.theme.data.bg.hex;
      mSecondary = config.theme.data.accent2.hex;
      mOnSecondary = config.theme.data.bg.hex;
      mTertiary = config.theme.data.purple.hex;
      mOnTertiary = config.theme.data.bg.hex;
      mError = config.theme.data.red.hex;
      mOnError = config.theme.data.bg.hex;
      mSurface = config.theme.data.bg.hex;
      mSurfaceVariant = config.theme.data.bg_highlight.hex;
      mOnSurface = config.theme.data.fg.hex;
      mOnSurfaceVariant = config.theme.data.fg_dim.hex;
      mOutline = config.theme.data.border.hex;
      mShadow = config.theme.data.bg_dark.hex;
      mHover = config.theme.data.bg_highlight.hex;
      mOnHover = config.theme.data.fg.hex;
    };

    # Merge all section settings
    settings = bar // general // notifications // wallpaper // launcher // session // system // extras;
  };
}
