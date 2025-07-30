{ pkgs, ... }:
{
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

    # Additional ZSH options
    initContent = ''
      # Better history search with arrow keys
      bindkey '^[[A' history-search-backward
      bindkey '^[[B' history-search-forward

      # Case insensitive completion
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

      # Colored completion
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}

      # Menu selection for completion
      zstyle ':completion:*' menu select
    '';
  };

  # Shell utilities
  home.packages = with pkgs; [
    bat
    eza
    fzf
    delta
    jq
    yq
  ];

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

    # Shortcuts
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
    cat = "bat";
    grep = "grep --color=auto";
    df = "df -h";
    du = "du -h";

    # Nix shortcuts
    nrs = "sudo nixos-rebuild switch";
    nfu = "nix flake update";
    ncg = "nix-collect-garbage -d";

    # Clan shortcuts
    cufw = "clan machines update alex-fw";
  };
}
