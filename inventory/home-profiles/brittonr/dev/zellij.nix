{
  programs.zellij = {
    enable = true;
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    attachExistingSession = false;
    exitShellOnExit = false;
    settings = {
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
