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

in
{
  programs.noctalia = {
    enable = true;

    # The upstream v5 module validates the generated TOML at build time.
    # Keep validation disabled while the settings schema is migrating from the
    # older noctalia-shell module shape.
    validateConfig = false;

    # Merge all section settings.
    settings = bar // general // notifications // wallpaper // launcher // session // system // extras;
  };

  # Force-overwrite Noctalia's runtime-writable config on each activation.
  xdg.configFile."noctalia/config.toml".force = true;
}
