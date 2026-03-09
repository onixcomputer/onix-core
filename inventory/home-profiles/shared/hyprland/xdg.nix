_: {
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
      XDG_SCREENSHOTS_DIR = "$HOME/Screenshots";
      XDG_PROJECTS_DIR = "$HOME/dev";
    };
  };
}
