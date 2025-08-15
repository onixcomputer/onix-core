_: {
  # Atuin - magical shell history
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableBashIntegration = true;

    settings = {
      # UI settings
      style = "compact";
      inline_height = 20;
      show_preview = true;

      # Search settings
      search_mode = "fuzzy";
      filter_mode = "directory";
      filter_mode_shell_up_key_binding = "directory";

      # Sync settings (disabled by default, enable when ready)
      sync_address = "https://api.atuin.sh";
      sync_frequency = "10m";
      auto_sync = false; # Set to true when you want to enable sync

      # History settings - filter out sensitive commands
      history_filter = [
        "^secret"
        "^pass"
        "^token"
      ];

      # Key bindings
      ctrl_n_shortcuts = true;

      # Display settings
      show_help = true;
      exit_mode = "return-original";
    };
  };
}
