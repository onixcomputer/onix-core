_: {
  programs.eza = {
    enable = true;

    # Enable colors in output
    colors = "auto";

    # Show git status
    git = true;

    # Display icons
    icons = "auto";

    # Enable shell integrations
    enableBashIntegration = true;
    enableFishIntegration = true;
    enableZshIntegration = true;
    # Extra options
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];

    # Onix Dark theme colors
    theme = {
      # File type colors
      "fi" = "38;2;230;230;230"; # Regular file - white (#e6e6e6)
      "di" = "38;2;68;136;255"; # Directory - blue (#4488ff)
      "ex" = "38;2;68;255;68"; # Executable - green (#44ff44)
      "ln" = "38;2;0;255;255"; # Symlink - cyan (#00ffff)
      "so" = "38;2;255;68;255"; # Socket - magenta (#ff44ff)
      "pi" = "38;2;255;170;0"; # Pipe - yellow (#ffaa00)

      # Permission bits
      "ur" = "38;2;255;68;68"; # User read - red (#ff4444)
      "uw" = "38;2;68;255;68"; # User write - green (#44ff44)
      "ux" = "38;2;255;170;0"; # User execute - yellow (#ffaa00)
      "ue" = "38;2;255;170;0"; # User execute (other) - yellow (#ffaa00)

      # Git status
      "gm" = "38;2;255;170;0"; # Git modified - yellow (#ffaa00)
      "ga" = "38;2;68;255;68"; # Git added - green (#44ff44)
      "gd" = "38;2;255;68;68"; # Git deleted - red (#ff4444)
      "gv" = "38;2;0;255;255"; # Git renamed - cyan (#00ffff)
      "gt" = "38;2;68;136;255"; # Git typechange - blue (#4488ff)
    };
  };

  programs.fish.shellAliases = {
    ls = "eza --icons";
    l = "eza -l --icons";
    la = "eza -la --icons";
    ll = "eza -la --icons --git";
    lt = "eza --tree --icons";
  };
}
