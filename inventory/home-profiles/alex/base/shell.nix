{ pkgs, ... }:
{
  # Shell-agnostic aliases that apply to all shells
  home.shellAliases = {
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
    cul = "clan machines update $hostname --target-host localhost";
    coc = "cd $HOME/git/onix-core";
    cocn = "cd $HOME/git/onix-core && nvim .";
  };

  # Fish shell configuration
  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      # Atuin manual setup
      if type -q atuin
        set -gx ATUIN_NOBIND "true"
        atuin init fish | source

        bind \cr _atuin_search
        bind -M insert \cr _atuin_search
        bind -M insert \e\[A _atuin_bind_up
        bind -M insert \eOA _atuin_bind_up
      end
    '';

    shellInit = ''
      # Disable greeting
      set -g fish_greeting

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

      # Colors
      set -g fish_color_autosuggestion 555 brblack
      set -g fish_color_command green
      set -g fish_color_error red --bold
      set -g fish_color_param cyan
      set -g fish_color_quote yellow

      # Block cursor for vi modes
      set -g fish_cursor_default block
      set -g fish_cursor_insert block
      set -g fish_cursor_replace_one underscore
      set -g fish_cursor_visual block
      set -g fish_vi_force_cursor 1

      # Cursor function stub
      function __fish_vi_cursor --argument-names mode
      end

      # Vi key bindings
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
  ];
}
