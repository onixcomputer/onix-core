{ config, ... }:
let
  c = config.colors;
in
{
  programs.fish.interactiveShellInit = ''
    # Onix Dark theme
    set -g fish_color_normal ${c.noHash c.fg}
    set -g fish_color_autosuggestion ${c.noHash c.comment}
    set -g fish_color_command ${c.noHash c.green}
    set -g fish_color_error ${c.noHash c.red} --bold
    set -g fish_color_param ${c.noHash c.blue}
    set -g fish_color_quote ${c.noHash c.yellow}
    set -g fish_color_redirection ${c.noHash c.orange}
    set -g fish_color_end ${c.noHash c.cyan}
    set -g fish_color_comment ${c.noHash c.comment} --italics
    set -g fish_color_operator ${c.noHash c.orange}
    set -g fish_color_escape ${c.noHash c.cyan}
    set -g fish_color_cwd ${c.noHash c.blue}
    set -g fish_color_cwd_root ${c.noHash c.red}
    set -g fish_color_user ${c.noHash c.orange}
    set -g fish_color_host ${c.noHash c.green}
    set -g fish_color_host_remote ${c.noHash c.yellow}
    set -g fish_color_cancel -r
    set -g fish_color_search_match --background=${c.noHash c.bg_highlight}
    set -g fish_color_selection --background=${c.noHash c.bg_highlight}
    set -g fish_color_status ${c.noHash c.red}
    set -g fish_color_valid_path --underline
    set -g fish_color_history_current --bold

    # Pager colors
    set -g fish_pager_color_completion ${c.noHash c.fg}
    set -g fish_pager_color_description ${c.noHash c.comment} --italics
    set -g fish_pager_color_prefix ${c.noHash c.cyan} --bold --underline
    set -g fish_pager_color_progress ${c.noHash c.fg} --background=${c.noHash c.bg_highlight}
    set -g fish_pager_color_selected_background --background=${c.noHash c.bg_highlight}

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
