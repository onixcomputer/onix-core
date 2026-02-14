{ pkgs, config, ... }:
{
  # Darkman service for automatic light/dark mode switching based on sunrise/sunset
  services.darkman = {
    enable = true;

    settings = {
      inherit (config.location) lat lng;
    };

    # Scripts to run when switching to dark mode
    darkModeScripts = {
      gtk-theme = ''
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
      '';
    };

    # Scripts to run when switching to light mode
    lightModeScripts = {
      gtk-theme = ''
        ${pkgs.dconf}/bin/dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
      '';
    };
  };

  # Configure xdg-desktop-portal to use darkman for settings
  xdg.portal.config.common."org.freedesktop.impl.portal.Settings" = [ "darkman" ];
}
