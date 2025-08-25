{ pkgs, ... }:
{
  # Shell-agnostic aliases that apply to all shells
  home.shellAliases = {
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

    # Nix shortcuts
    nrs = "sudo nixos-rebuild switch";
    nfu = "nix flake update";
    ncg = "nix-collect-garbage -d";

    # Clan shortcuts
    cu = "clan m update $hostname";
  };

  # Fish shell configuration
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting # Disable greeting

      # Import systemd environment (for SSH_AUTH_SOCK from gnome-keyring)
      if command -q systemctl
        for var in (systemctl --user show-environment | string match 'SSH_AUTH_SOCK=*')
          set -gx (string split -m 1 '=' $var)
        end
      end

      # Custom function for clipboard copy
      function cc
        bat $argv | wl-copy
      end

      # Better colors for suggestions (subtle gray)
      set -g fish_color_autosuggestion 555 brblack
      set -g fish_color_command green
      set -g fish_color_error red --bold
      set -g fish_color_param cyan
      set -g fish_color_quote yellow

      # Force block cursor for all vi modes
      set -g fish_cursor_default block
      set -g fish_cursor_insert block
      set -g fish_cursor_replace_one underscore
      set -g fish_cursor_visual block

      # Enable vi key bindings
      fish_vi_key_bindings
    '';
  };

  # Shell utilities used by aliases
  home.packages = with pkgs; [
    bat
    eza
    fzf
    delta
    jq
    yq
    lazygit
  ];
}
