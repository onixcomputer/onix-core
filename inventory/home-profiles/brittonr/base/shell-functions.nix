_: {
  programs.fish.interactiveShellInit = ''
    # Manual zellij attach function
    function zj
      # Check if already in zellij
      if set -q ZELLIJ
        echo "Already in a zellij session. Exit first or use Ctrl+o,d to detach."
        return 1
      end

      # If there's a .envrc, eval direnv first to get ZELLIJ_SESSION_NAME
      if test -f .envrc
        set -l direnv_export (direnv export fish 2>/dev/null)
        if test $status -eq 0
          eval $direnv_export
        end
      end

      # Determine session name
      set -l session_name
      if set -q ZELLIJ_SESSION_NAME; and test -n "$ZELLIJ_SESSION_NAME"
        set session_name $ZELLIJ_SESSION_NAME
      else
        set session_name (basename $PWD | string replace -a '.' '_')
        if test -z "$session_name"
          set session_name "main"
        end
      end

      echo "Attaching to session: $session_name"
      # Force attach regardless of attachment status
      zellij attach --create "$session_name"
    end

    # Import systemd environment and propagate SSH agent to all fish instances
    if command -q systemctl
      for var in (systemctl --user show-environment | string match 'SSH_AUTH_SOCK=*')
        set -gx (string split -m 1 '=' $var)
      end
    end
    for var in SSH_AUTH_SOCK SSH_CONNECTION SSH_CLIENT
      if set -q $var
        set -Ux $var $$var
      end
    end

    # Custom function for clipboard copy (file contents)
    function cc
      bat $argv | wl-copy
    end

    # Copy current directory (or given path) to clipboard
    function copypath
      set -l p
      if test (count $argv) -eq 0
        set p $PWD
      else
        set p $argv[1]
      end
      set p (realpath "$p")
      echo "$p" | wl-copy 2>/dev/null
      echo "$p"
    end

    # Walk up the directory tree looking for a file
    function upfind
      if test (count $argv) -ne 1
        echo "upfind FILE_NAME"
        return 1
      end
      set -l previous ""
      set -l current $PWD
      while test -d "$current" -a "$current" != "$previous"
        if test -f "$current/$argv[1]"
          echo "$current/$argv[1]"
          return 0
        end
        set previous $current
        set current (dirname $current)
      end
      return 1
    end

    # make/ninja auto-discover build files from subdirectories
    function make
      set -l build_path (upfind "Makefile")
      if test -n "$build_path"
        set build_path (dirname $build_path)
      else
        set build_path "."
      end
      command make -C "$build_path" -j(nproc) $argv
    end

    function ninja
      set -l build_path (upfind "build.ninja")
      if test -n "$build_path"
        set build_path (dirname $build_path)
      else
        set build_path "."
      end
      command ninja -C "$build_path" $argv
    end

    # Smart cd: file → parent dir, fallback to zoxide
    functions --copy cd _builtin_cd 2>/dev/null
    function cd
      if test "$argv[1]" = --
        set argv $argv[2..-1]
      else if test "$argv[1]" = -
        _builtin_cd -
        return
      end

      if test (count $argv) -eq 0
        _builtin_cd
        return
      end

      set -l to $argv[1]

      # If target is a file, cd to its parent
      if test -f "$to"
        set to (dirname $to)
      end

      # Try builtin cd first, fall back to zoxide
      if not _builtin_cd "$to"
        if type -q __zoxide_z
          __zoxide_z $to
        end
      end
    end

    # mkdir + cd in one step
    function mkcd
      mkdir -p "$argv[1]"; and cd "$argv[1]"
    end

    # Shallow clone into a temp dir for quick inspection
    function clone
      if test (count $argv) -eq 0
        echo "clone <GIT_URL>"
        return 1
      end
      cd (mktemp -d) || return 1
      git clone --depth=1 "$argv[1]"
      cd *
    end

    # Generate xkcd-style passwords (word-word-word7)
    function passgen
      set -l pass (xkcdpass -d '-' -n 3 -C capitalize $argv)
      echo "$pass$(random 1 10)"
    end

    # Auto-list directory after cd
    set -g _ls_after_cd_oldpwd $PWD
    function _ls_after_cd --on-event fish_prompt
      if test "$_ls_after_cd_oldpwd" != "$PWD"
        set -g _ls_after_cd_oldpwd $PWD
        ls
      end
    end

    # PATH dedup — remove duplicate and nonexistent entries
    function _clean_up_path
      set -l new_path
      for p in $PATH
        if not contains $p $new_path
          if test -e $p
            set new_path $new_path $p
          end
        end
      end
      set -x PATH $new_path
    end
    _clean_up_path

    # CDPATH: cd to repos from anywhere (e.g. `cd onix-core` finds ~/git/onix-core)
    set -x CDPATH . ~/git

    # Delta side-by-side on wide terminals
    function _delta_side_by_side --on-signal WINCH
      if test $COLUMNS -ge 140
        set -gx DELTA_FEATURES side-by-side
      else
        set -gx DELTA_FEATURES ""
      end
    end
    # Run once at startup
    if test $COLUMNS -ge 140
      set -gx DELTA_FEATURES side-by-side
    else
      set -gx DELTA_FEATURES ""
    end

    # fzf defaults: reverse history search, fd as file finder
    set -gx FZF_CTRL_R_OPTS --reverse
    if type -q fd
      set -gx FZF_DEFAULT_COMMAND 'fd --type f'
    end
    if type -q fzf-share
      source (fzf-share)/key-bindings.fish
    end

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
}
