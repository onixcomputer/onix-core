{ config, ... }:
let
  c = config.theme.data;
in
{
  programs.fish.interactiveShellInit = ''
    # Theme colors (seed — Noctalia overrides via conf.d/noctalia-colors.fish)
    set -g fish_color_normal ${c.fg.no_hash}
    set -g fish_color_autosuggestion ${c.comment.no_hash}
    set -g fish_color_command ${c.green.no_hash}
    set -g fish_color_error ${c.red.no_hash} --bold
    set -g fish_color_param ${c.blue.no_hash}
    set -g fish_color_quote ${c.yellow.no_hash}
    set -g fish_color_redirection ${c.orange.no_hash}
    set -g fish_color_end ${c.cyan.no_hash}
    set -g fish_color_comment ${c.comment.no_hash} --italics
    set -g fish_color_operator ${c.orange.no_hash}
    set -g fish_color_escape ${c.cyan.no_hash}
    set -g fish_color_cwd ${c.blue.no_hash}
    set -g fish_color_cwd_root ${c.red.no_hash}
    set -g fish_color_user ${c.orange.no_hash}
    set -g fish_color_host ${c.green.no_hash}
    set -g fish_color_host_remote ${c.yellow.no_hash}
    set -g fish_color_cancel -r
    set -g fish_color_search_match --background=${c.bg_highlight.no_hash}
    set -g fish_color_selection --background=${c.bg_highlight.no_hash}
    set -g fish_color_status ${c.red.no_hash}
    set -g fish_color_valid_path --underline
    set -g fish_color_history_current --bold

    # Pager colors
    set -g fish_pager_color_completion ${c.fg.no_hash}
    set -g fish_pager_color_description ${c.comment.no_hash} --italics
    set -g fish_pager_color_prefix ${c.cyan.no_hash} --bold --underline
    set -g fish_pager_color_progress ${c.fg.no_hash} --background=${c.bg_highlight.no_hash}
    set -g fish_pager_color_selected_background --background=${c.bg_highlight.no_hash}

    # Block cursor for vi modes
    set -g fish_cursor_default block
    set -g fish_cursor_insert block
    set -g fish_cursor_replace_one underscore
    set -g fish_cursor_visual block
    set -g fish_vi_force_cursor 1

    # Cursor function stub
    function __fish_vi_cursor --argument-names mode
    end
  '';
}
