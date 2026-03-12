{ lib, ... }:
{
  # Make programs use XDG directories whenever supported
  home.preferXdgDirectories = true;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    documents = "$HOME/Documents";
    download = "$HOME/Downloads";
    music = "$HOME/Music";
    pictures = "$HOME/Pictures";
    videos = "$HOME/Videos";
    extraConfig = {
      SCREENSHOTS = lib.mkForce "$HOME/Pictures/Screenshots";
      PROJECTS = lib.mkForce "$HOME/git";
    };
  };
}
