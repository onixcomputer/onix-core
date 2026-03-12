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

    # Material 3 color mapping from onix-dark palette
    colors = {
      mPrimary = config.colors.accent;
      mOnPrimary = config.colors.bg;
      mSecondary = config.colors.accent2;
      mOnSecondary = config.colors.bg;
      mTertiary = config.colors.purple;
      mOnTertiary = config.colors.bg;
      mError = config.colors.red;
      mOnError = config.colors.bg;
      mSurface = config.colors.bg;
      mSurfaceVariant = config.colors.bg_highlight;
      mOnSurface = config.colors.fg;
      mOnSurfaceVariant = config.colors.fg_dim;
      mOutline = config.colors.border;
      mShadow = config.colors.bg_dark;
      mHover = config.colors.bg_highlight;
      mOnHover = config.colors.fg;
    };

    # Merge all section settings
    settings = bar // general // notifications // wallpaper // launcher // session // system // extras;
  };
}
