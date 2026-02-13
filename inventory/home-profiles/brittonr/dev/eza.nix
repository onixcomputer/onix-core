{ config, ... }:
let
  c = config.colors;
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

    # Onix Dark theme colors
    theme = {
      # File type colors
      "fi" = c.hexToAnsi c.fg;
      "di" = c.hexToAnsi c.blue;
      "ex" = c.hexToAnsi c.green;
      "ln" = c.hexToAnsi c.cyan;
      "so" = c.hexToAnsi c.magenta;
      "pi" = c.hexToAnsi c.yellow;

      # Permission bits
      "ur" = c.hexToAnsi c.red;
      "uw" = c.hexToAnsi c.green;
      "ux" = c.hexToAnsi c.yellow;
      "ue" = c.hexToAnsi c.yellow;

      # Git status
      "gm" = c.hexToAnsi c.yellow;
      "ga" = c.hexToAnsi c.green;
      "gd" = c.hexToAnsi c.red;
      "gv" = c.hexToAnsi c.cyan;
      "gt" = c.hexToAnsi c.blue;
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
