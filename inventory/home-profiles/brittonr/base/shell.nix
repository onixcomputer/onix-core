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
    cu = "clan m update \\$hostname";
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

      # Enable vi key bindings with helix-like modifications
      fish_vi_key_bindings

      # Helix-like: Escape goes to normal mode (keep default vi behavior)
      # But in Helix, movements automatically select

      # Normal mode movements (helix-like: implicit selection on movement)
      bind -M default w forward-word
      bind -M default b backward-word
      bind -M default e forward-word
      bind -M default W forward-bigword
      bind -M default B backward-bigword
      bind -M default E forward-bigword

      # x selects current line (helix key) - NEVER deletes, only selects
      # This completely overrides vi-mode's default x (delete char) behavior
      bind -M default x 'commandline -f beginning-of-line begin-selection end-of-line; set fish_bind_mode visual; commandline -f repaint-mode'

      # X extends selection to line bounds (helix key) - enters visual mode
      bind -M default X 'commandline -f begin-selection end-of-line; set fish_bind_mode visual; commandline -f repaint-mode'

      # % selects entire file (helix key) - enters visual mode
      bind -M default '%' 'commandline -f beginning-of-buffer begin-selection end-of-buffer; set fish_bind_mode visual; commandline -f repaint-mode'

      # d deletes selection and returns to default mode
      bind -M visual d 'commandline -f kill-selection end-selection; set fish_bind_mode default; commandline -f repaint-mode'

      # c changes selection (delete and enter insert mode)
      bind -M visual c 'commandline -f kill-selection; set fish_bind_mode insert; commandline -f repaint-mode'

      # y yanks/copies selection and returns to default mode
      bind -M visual y 'commandline -f yank end-selection; set fish_bind_mode default; commandline -f repaint-mode'

      # p pastes after selection (helix key)
      bind -M default p 'commandline -f yank repaint-mode'
      bind -M visual p 'commandline -f yank repaint-mode'

      # u undo (helix key)
      bind -M default u 'commandline -f undo repaint-mode'

      # U redo (helix key - uppercase U)
      bind -M default U 'commandline -f redo repaint-mode'

      # ~ switch case (only works on selections)
      bind -M visual '~' 'commandline -f togglecase-selection repaint-mode'

      # v enters select/extend mode (helix key)
      bind -M default v 'commandline -f begin-selection repaint-mode'

      # Escape exits visual mode
      bind -M visual escape 'commandline -f end-selection; set fish_bind_mode default; commandline -f repaint-mode'

      # i enters insert mode (helix key)
      bind -M default i 'set fish_bind_mode insert; commandline -f repaint-mode'

      # Visual mode movements extend selection
      bind -M visual w 'commandline -f forward-word'
      bind -M visual b 'commandline -f backward-word' 
      bind -M visual e 'commandline -f forward-word'
      bind -M visual h 'commandline -f backward-char'
      bind -M visual l 'commandline -f forward-char'
      bind -M visual j 'commandline -f down-line'
      bind -M visual k 'commandline -f up-line'

      # Basic movements in default mode (no selection)
      bind -M default h 'commandline -f backward-char'
      bind -M default l 'commandline -f forward-char'
      bind -M default j 'commandline -f history-search-forward'
      bind -M default k 'commandline -f history-search-backward'
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
