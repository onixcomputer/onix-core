{ config, ... }:
let
  c = config.theme.data;
in
{
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

    # Theme colors
    theme = {
      # File type colors
      "fi" = c.fg.ansi;
      "di" = c.blue.ansi;
      "ex" = c.green.ansi;
      "ln" = c.cyan.ansi;
      "so" = c.magenta.ansi;
      "pi" = c.yellow.ansi;

      # Permission bits
      "ur" = c.red.ansi;
      "uw" = c.green.ansi;
      "ux" = c.yellow.ansi;
      "ue" = c.yellow.ansi;

      # Git status
      "gm" = c.yellow.ansi;
      "ga" = c.green.ansi;
      "gd" = c.red.ansi;
      "gv" = c.cyan.ansi;
      "gt" = c.blue.ansi;
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
