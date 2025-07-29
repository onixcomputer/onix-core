{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nautilus
    sushi # Quick file previewer

    # Thumbnail support
    ffmpegthumbnailer

    # Archive support
    file-roller

    # Tokyo Night GTK theme
    tokyo-night-gtk
  ];

  # GTK theme configuration
  gtk = {
    enable = true;
    theme = {
      name = "Tokyonight-Dark-B";
      package = pkgs.tokyo-night-gtk;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  # dconf settings for GNOME/Nautilus dark mode
  dconf = {
    enable = true;
    settings = {
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
        gtk-theme = "Tokyonight-Dark-B";
      };

      # Nautilus specific settings
      "org/gnome/nautilus/preferences" = {
        default-folder-viewer = "list-view";
        search-filter-time-type = "last_modified";
      };

      # File chooser (used by Nautilus dialogs)
      "org/gtk/settings/file-chooser" = {
        sort-directories-first = true;
      };
    };
  };

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
  };
}
