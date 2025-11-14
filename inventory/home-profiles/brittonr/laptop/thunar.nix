{ pkgs, ... }:
{
  home.packages = with pkgs; [
    xfce.thunar
    xfce.thunar-volman
    xfce.thunar-archive-plugin
    xfce.tumbler
    xfce.xfconf
    ffmpegthumbnailer
    webp-pixbuf-loader
    file-roller
  ];

  dconf.settings = {
    "org/gtk/settings/file-chooser" = {
      sort-directories-first = true;
      show-hidden = false;
    };
  };

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
