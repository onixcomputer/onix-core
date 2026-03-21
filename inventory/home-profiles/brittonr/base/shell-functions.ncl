# Fish shell utility functions and interactive init.
#
# Returns a record of named sections. The Nix wrapper joins them
# into programs.fish.interactiveShellInit.
{
  functions
    | { _ : String }
    | doc "Fish function definitions keyed by name"
    = {
      zj = m%"
        function zj
          if set -q ZELLIJ
            echo "Already in a zellij session. Exit first or use Ctrl+o,d to detach."
            return 1
          end

          if test -f .envrc
            set -l direnv_export (direnv export fish 2>/dev/null)
            if test $status -eq 0
              eval $direnv_export
            end
          end

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
          zellij attach --create "$session_name"
        end
      "%,

      cc = m%"
        function cc
          bat $argv | wl-copy
        end
      "%,

      copypath = m%"
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
      "%,

      upfind = m%"
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
      "%,

      make = m%"
        function make
          set -l build_path (upfind "Makefile")
          if test -n "$build_path"
            set build_path (dirname $build_path)
          else
            set build_path "."
          end
          command make -C "$build_path" -j(nproc) $argv
        end
      "%,

      ninja = m%"
        function ninja
          set -l build_path (upfind "build.ninja")
          if test -n "$build_path"
            set build_path (dirname $build_path)
          else
            set build_path "."
          end
          command ninja -C "$build_path" $argv
        end
      "%,

      cd = m%"
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

          if test -f "$to"
            set to (dirname $to)
          end

          if not _builtin_cd "$to"
            if type -q __zoxide_z
              __zoxide_z $to
            end
          end
        end
      "%,

      mkcd = m%"
        function mkcd
          mkdir -p "$argv[1]"; and cd "$argv[1]"
        end
      "%,

      clone = m%"
        function clone
          if test (count $argv) -eq 0
            echo "clone <GIT_URL>"
            return 1
          end
          cd (mktemp -d) || return 1
          git clone --depth=1 "$argv[1]"
          cd *
        end
      "%,

      passgen = m%"
        function passgen
          set -l pass (xkcdpass -d '-' -n 3 -C capitalize $argv)
          echo "$pass$(random 1 10)"
        end
      "%,

      cheat = m%"
        function cheat
          if test (count $argv) -eq 0
            echo "Usage: cheat <question>"
            echo "Example: cheat scp a folder to remote host"
            return 1
          end
          set -l key "$ANTHROPIC_API_KEY"
          if test -z "$key"
            echo "Error: ANTHROPIC_API_KEY not set" >&2
            return 1
          end
          set -l query "$argv"
          set -l payload (jq -nc \
            --arg q "$query" \
            '{
              model: "claude-haiku-4-5",
              max_tokens: 256,
              system: "Reply with only the command. Nothing else. No markdown, no code fences, no explanation.",
              messages: [{role: "user", content: $q}]
            }')
          set -l response (curl -s https://api.anthropic.com/v1/messages \
            -H "content-type: application/json" \
            -H "x-api-key: $key" \
            -H "anthropic-version: 2023-06-01" \
            -d "$payload")
          set -l error (echo "$response" | jq -r '.error.message // empty')
          if test -n "$error"
            echo "Error: $error" >&2
            return 1
          end
          echo "$response" | jq -r '.content[0].text'
        end
      "%,
    },

  init
    | { _ : String }
    | doc "Non-function init snippets keyed by concern"
    = {
      ssh_agent = m%"
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
      "%,

      ls_after_cd = m%"
        set -g _ls_after_cd_oldpwd $PWD
        function _ls_after_cd --on-event fish_prompt
          if test "$_ls_after_cd_oldpwd" != "$PWD"
            set -g _ls_after_cd_oldpwd $PWD
            ls
          end
        end
      "%,

      clean_path = m%"
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
      "%,

      cdpath = m%"
        set -x CDPATH . ~/git
      "%,

      delta = m%"
        function _delta_side_by_side --on-signal WINCH
          if test $COLUMNS -ge 140
            set -gx DELTA_FEATURES side-by-side
          else
            set -gx DELTA_FEATURES ""
          end
        end
        if test $COLUMNS -ge 140
          set -gx DELTA_FEATURES side-by-side
        else
          set -gx DELTA_FEATURES ""
        end
      "%,

      fzf = m%"
        set -gx FZF_CTRL_R_OPTS --reverse
        if type -q fd
          set -gx FZF_DEFAULT_COMMAND 'fd --type f'
        end
        if type -q fzf-share
          source (fzf-share)/key-bindings.fish
        end
      "%,

      atuin = m%"
        if type -q atuin
          set -gx ATUIN_NOBIND "true"
          atuin init fish | source

          bind \cr _atuin_search
          bind -M insert \cr _atuin_search
          bind -M insert \e\[A _atuin_bind_up
          bind -M insert \eOA _atuin_bind_up
        end
      "%,
    },
}
