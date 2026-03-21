{ pkgs, ... }:
{
  home.packages = with pkgs; [
    thunar
    thunar-volman
    thunar-archive-plugin
    tumbler
    xfconf
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

  # MIME association for inode/directory is in xdg.ncl
}
