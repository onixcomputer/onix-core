{ config, ... }:
let
  k = config.keymap;
in
{
  programs.fish.interactiveShellInit = ''
    # Enable vi key bindings with helix-like modifications
    fish_vi_key_bindings

    # Helix-like: Escape goes to normal mode (keep default vi behavior)
    # But in Helix, movements automatically select

    # Normal mode movements (helix-like: implicit selection on movement)
    bind -M default ${k.word.forward} forward-word
    bind -M default ${k.word.backward} backward-word
    bind -M default ${k.word.end} forward-word
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
    bind -M visual ${k.word.forward} 'commandline -f forward-word'
    bind -M visual ${k.word.backward} 'commandline -f backward-word'
    bind -M visual ${k.word.end} 'commandline -f forward-word'
    bind -M visual ${k.nav.left} 'commandline -f backward-char'
    bind -M visual ${k.nav.right} 'commandline -f forward-char'
    bind -M visual ${k.nav.down} 'commandline -f down-line'
    bind -M visual ${k.nav.up} 'commandline -f up-line'

    # Basic movements in default mode (no selection)
    bind -M default ${k.nav.left} 'commandline -f backward-char'
    bind -M default ${k.nav.right} 'commandline -f forward-char'
    bind -M default ${k.nav.down} 'commandline -f history-search-forward'
    bind -M default ${k.nav.up} 'commandline -f history-search-backward'
  '';
}
