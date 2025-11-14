_: {
  programs.zellij = {
    enable = true;
    enableBashIntegration = false;
    enableFishIntegration = false;
    enableZshIntegration = false;
    settings = {
      # Minimal UI configuration
      simplified_ui = true;
      pane_frames = false;
      default_mode = "locked";
      default_layout = "minimal";

      # Behavior
      show_startup_tips = false;
      auto_layout = false;
      on_force_close = "quit";

      # Session management
      session_serialization = true;

      keybinds = {
        normal = {
          "bind \"Alt t\"" = {
            NewTab = { };
          };
          "bind \"Alt x\"" = {
            CloseTab = { };
          };
          "bind \"Alt p\"" = {
            NewPane = { };
          };
        };
      };
    };
  };

  # Create minimal layout file
  xdg.configFile."zellij/layouts/minimal.kdl".text = ''
    layout {
      default_tab_template {
        pane
      }
    }
  '';
}
