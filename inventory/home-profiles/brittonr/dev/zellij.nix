{ config, ... }:
let
  k = config.keymap;
in
{
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
          # Vim-style navigation (hjkl)
          "bind \"Alt ${k.nav.left}\"" = {
            MoveFocusOrTab = "Left";
          };
          "bind \"Alt ${k.nav.right}\"" = {
            MoveFocusOrTab = "Right";
          };
          "bind \"Alt ${k.nav.down}\"" = {
            MoveFocus = "Down";
          };
          "bind \"Alt ${k.nav.up}\"" = {
            MoveFocus = "Up";
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
