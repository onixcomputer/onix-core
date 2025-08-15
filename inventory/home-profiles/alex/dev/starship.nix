{ pkgs, ... }:
{
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    enableFishIntegration = true;
    enableBashIntegration = true;

    settings =
      # Start with nerd-font-symbols preset for the icons
      (builtins.fromTOML (
        builtins.readFile "${pkgs.starship}/share/starship/presets/nerd-font-symbols.toml"
      ))
      // {
        # Format with curved line connector like oh-my-zsh fox theme
        format = "╭─$username$hostname$directory$git_branch$git_status$nix_shell$cmd_duration\n╰─$character ";

        # Always show username
        username = {
          show_always = true;
          format = "[$user]($style)@";
          style_user = "bold blue";
          style_root = "bold red";
        };

        # Always show hostname
        hostname = {
          ssh_only = false;
          format = "[$hostname]($style) in ";
          style = "bold green";
        };

        # Show command duration with stopwatch emoji
        cmd_duration = {
          min_time = 2000;
          format = "[⏱ $duration]($style) ";
        };

        # Show nix shell status - just snowflake when in shell
        nix_shell = {
          format = "[$symbol]($style) ";
          symbol = "❄️";
        };

        # Prompt character
        character = {
          success_symbol = "[❯](bold green)";
          error_symbol = "[❯](bold red)";
        };
      };
  };
}
