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

    # Custom theme colors
    theme = {
      # File type colors
      "fi" = "38;5;15"; # Regular file - white
      "di" = "38;5;12"; # Directory - blue
      "ex" = "38;5;10"; # Executable - green
      "ln" = "38;5;14"; # Symlink - cyan
      "so" = "38;5;13"; # Socket - magenta
      "pi" = "38;5;11"; # Pipe - yellow

      # Permission bits
      "ur" = "38;5;9"; # User read - red
      "uw" = "38;5;10"; # User write - green
      "ux" = "38;5;11"; # User execute - yellow
      "ue" = "38;5;11"; # User execute (other) - yellow

      # Git status
      "gm" = "38;5;11"; # Git modified - yellow
      "ga" = "38;5;10"; # Git added - green
      "gd" = "38;5;9"; # Git deleted - red
      "gv" = "38;5;14"; # Git renamed - cyan
      "gt" = "38;5;12"; # Git typechange - blue
    };
  };

  programs.fish.shellAliases = {
    ls = "eza";
    l = "eza -l";
    la = "eza -la";
    ll = "eza -l";
    lt = "eza --tree";
  };
}
