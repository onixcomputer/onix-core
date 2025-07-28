{ pkgs, ... }:
{
  home.packages = with pkgs; [
    nautilus
    sushi # Quick file previewer

    # Thumbnail support
    ffmpegthumbnailer

    # Archive support
    file-roller
  ];

  xdg.mimeApps.defaultApplications = {
    "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
  };
}
