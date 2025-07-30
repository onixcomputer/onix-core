{ pkgs, ... }:
{
  home.packages = with pkgs; [
    xfce.thunar
    xfce.thunar-volman # Volume management
    xfce.thunar-archive-plugin # Archive support
    xfce.tumbler # Thumbnail support

    # Additional file management tools
    xfce.xfconf # Thunar settings backend
    ffmpegthumbnailer # Video thumbnails
    webp-pixbuf-loader # WebP image support
    file-roller # Archive manager (works with Thunar)
  ];

  # File chooser settings (works across GTK apps)
  dconf.settings = {
    "org/gtk/settings/file-chooser" = {
      sort-directories-first = true;
      show-hidden = false;
    };
  };

  # Thunar configuration via xfconf
  xfconf.settings = {
    xsettings = {
      "Net/ThemeName" = "Tokyonight-Dark";
      "Net/IconThemeName" = "Papirus-Dark";
      "Gtk/CursorThemeName" = "Adwaita";
    };
  };

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = [ "thunar.desktop" ];
  };
}
