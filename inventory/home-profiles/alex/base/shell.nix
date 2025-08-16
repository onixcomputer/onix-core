{ pkgs, ... }:
{
  # Shell-agnostic aliases that apply to all shells
  home.shellAliases = {
    # Eza (better ls)
    ll = "eza -la --icons --git";
    la = "eza -la --icons";
    ls = "eza --icons";
    lt = "eza --tree --icons";

    # Safety nets
    cp = "cp -i";
    mv = "mv -i";
    rm = "rm -i";

    # Navigation shortcuts
    ".." = "cd ..";
    "..." = "cd ../..";
    "...." = "cd ../../..";

    # Git shortcuts
    g = "git";
    gs = "git status";
    ga = "git add";
    gaa = "git add -A";
    gc = "git commit";
    gll = "git pull";
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

    # general shortcuts
    c = "clear";
    v = "validate";
    cmu = "clan machines update";
    cu = "clan machines update $hostname";
    coc = "cd $HOME/dev/onix-core";
    cocn = "cd $HOME/dev/onix-core && nvim .";
  };

  # Fish shell configuration
  programs.fish = {
    enable = true;

    shellInit = ''
      # Disable greeting
      set -g fish_greeting

      # Import systemd environment (for SSH_AUTH_SOCK from gnome-keyring)
      if command -q systemctl
        for var in (systemctl --user show-environment | string match 'SSH_AUTH_SOCK=*')
          set -gx (string split -m 1 '=' $var)
        end
      end

      # Compare home-profile directories
      function comp
        if test (count $argv) -ne 2
          echo "Usage: comp <user1/profile> <user2/profile>"
          echo "Example: comp alex/hyprland brittonr/hyprland"
          return 1
        end
        echo "Files only in $argv[1]:"
        comm -23 (cd ~/dev/onix-core/inventory/home-profiles/$argv[1] 2>/dev/null && ls -1 | sort | psub) (cd ~/dev/onix-core/inventory/home-profiles/$argv[2] 2>/dev/null && ls -1 | sort | psub)
        echo ""
        echo "Files only in $argv[2]:"
        comm -13 (cd ~/dev/onix-core/inventory/home-profiles/$argv[1] 2>/dev/null && ls -1 | sort | psub) (cd ~/dev/onix-core/inventory/home-profiles/$argv[2] 2>/dev/null && ls -1 | sort | psub)
      end

      # Better colors for suggestions (subtle gray)
      set -g fish_color_autosuggestion 555 brblack
      set -g fish_color_command green
      set -g fish_color_error red --bold
      set -g fish_color_param cyan
      set -g fish_color_quote yellow

      # Vi mode is optional in fish - let's keep normal mode for simplicity
      fish_default_key_bindings
    '';
  };

  # Zsh shell configuration
  programs.zsh = {
    enable = true;

    # Set default keymap to vi mode
    defaultKeymap = "viins";

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

    # Additional ZSH options
    initContent = ''
      # Import systemd environment (for SSH_AUTH_SOCK from gnome-keyring)
      if command -v systemctl &> /dev/null; then
        export $(systemctl --user show-environment | grep SSH_AUTH_SOCK | xargs)
      fi

      # Enable vi mode
      bindkey -v
      export KEYTIMEOUT=1

      # Fix common keybindings in vi mode
      bindkey -M viins '^A' beginning-of-line
      bindkey -M viins '^E' end-of-line
      bindkey -M viins '^K' kill-line
      bindkey -M viins '^W' backward-kill-word
      bindkey -M viins '^H' backward-delete-char
      bindkey -M viins '^?' backward-delete-char
      bindkey -M viins '^L' clear-screen

      # Better history search with arrow keys
      bindkey '^[[A' history-search-backward
      bindkey '^[[B' history-search-forward
      bindkey -M viins '^[[A' history-search-backward
      bindkey -M viins '^[[B' history-search-forward

      # Case insensitive completion
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

      # Colored completion
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}

      # Menu selection for completion
      zstyle ':completion:*' menu select
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
  ];
}
