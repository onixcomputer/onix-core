{
  programs.zellij = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
    attachExistingSession = false;
    exitShellOnExit = false;
    settings = {
      theme = "tokyo-night-dark";
      show_startup_tips = false;
      keybinds = {
        normal = {
          "bind \"Alt t\"" = {
            NewTab = { };
          };
          "bind \"Alt x\"" = {
            CloseTab = { };
          };
        };
      };
    };
  };
}
