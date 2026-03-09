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

  # xfconf settings removed - Thunar will use GTK theme from theme.nix

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = [ "thunar.desktop" ];
  };
}
