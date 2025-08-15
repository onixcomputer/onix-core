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
    lg = "lazygit";

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
    '';
  };

  # Zsh shell configuration
  programs.zsh = {
    enable = true;

    # Enable directory auto-cd
    autocd = true;

    # Enable autosuggestions
    autosuggestion = {
      enable = true;
      strategy = [
        "history"
        "completion"
      ];
    };

    # Enable syntax highlighting
    syntaxHighlighting.enable = true;

    # Enable completions
    enableCompletion = true;

    # History configuration
    history = {
      size = 10000;
      save = 10000;
      share = true;
      extended = true;
      ignoreDups = true;
      ignoreSpace = true;
    };

    # Zsh-specific initialization
    initContent = ''
      # Import systemd environment (for SSH_AUTH_SOCK from gnome-keyring)
      if command -v systemctl &> /dev/null; then
        export $(systemctl --user show-environment | grep SSH_AUTH_SOCK | xargs)
      fi

      # Custom function for clipboard copy (zsh version)
      function cc() {
        bat "$@" | wl-copy
      }
    '';
  };

  # Shell utilities used by aliases
  home.packages = with pkgs; [
    bat
    lazygit
  ];
}
