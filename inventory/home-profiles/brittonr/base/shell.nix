{ pkgs, ... }:
{
  # Home configuration
  home = {
    # Add ~/.local/bin to PATH for user-installed binaries (e.g., claude CLI)
    sessionPath = [
      "$HOME/.local/bin"
    ];

    # Shell-agnostic aliases that apply to all shells
    shellAliases = {
      # Navigation
      ".." = "cd ..";
      "..." = "cd ../..";
      "...." = "cd ../../..";

      # Git shortcuts
      g = "git";
      gs = "git status";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gl = "git log --oneline --graph";

      # Better defaults
      cat = "bat -pp";
      grep = "grep --color=auto";
      df = "df -h";
      du = "du -h";
      dd = "dd status=progress";

      # Nix shortcuts
      nrs = "sudo nixos-rebuild switch";
      nfu = "nix flake update";
      ncg = "nix-collect-garbage -d";

      # Clan shortcuts
      cu = "clan m update \\$hostname";

      # Hermes shortcuts
      hh = "hermes --yolo --tui";
    };

    # Shell utilities used by aliases
    packages = with pkgs; [
      autossh
      bat
      eza
      fzf
      delta
      jq
      yq
      lazygit
      xkcdpass
    ];
  };

  # Fish shell configuration
  programs.fish = {
    enable = true;
    plugins = [
      {
        name = "autopair";
        inherit (pkgs.fishPlugins.autopair) src;
      }
    ];
    interactiveShellInit = ''
      # Remove fish 4.3 frozen theme/keybinding migration files
      for f in $__fish_config_dir/conf.d/fish_frozen_theme.fish $__fish_config_dir/conf.d/fish_frozen_key_bindings.fish
        test -f $f; and rm -f $f
      end

      set fish_greeting # Disable greeting
    '';
  };
}
