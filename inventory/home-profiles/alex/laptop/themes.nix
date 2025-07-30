{ pkgs, ... }:
let
  darkForestWallpaper = pkgs.fetchurl {
    name = "dark-forest-wallpaper.jxl";
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/dark-forest.jxl";
    sha256 = "sha256-jbY5p0vKLdearaZh1kuQytVsPia6h2AsEbOAqGpxEWw=";
  };
in
{
  home.packages = with pkgs; [
    # Tokyo Night GTK theme for GTK3 apps
    tokyo-night-gtk

    # Icon themes
    papirus-icon-theme

  ];

  # GTK theme configuration
  gtk = {
    enable = true;

    theme = {
      name = "Tokyonight-Dark";
      package = pkgs.tokyo-night-gtk;
    };

    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # Set GTK_THEME environment variable
  home.sessionVariables = {
    GTK_THEME = "Tokyonight-Dark";
  };

  # dconf settings for GNOME/GTK apps dark mode
  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "Tokyonight-Dark";
        icon-theme = "Papirus-Dark";
      };
    };
  };

  # Qt theme configuration to match GTK
  qt = {
    enable = true;
    platformTheme.name = "gtk";
    style.name = "adwaita-dark";
  };

  # Wallpaper configuration
  services.hyprpaper = {
    enable = true;
    settings = {
      ipc = "on";
      splash = false;

      preload = [
        "${darkForestWallpaper}"
      ];

      wallpaper = [
        ",${darkForestWallpaper}"
      ];
    };
  };
}
