{ config, ... }:
let
  theme = config.theme.colors;
in
{
  programs.kitty = {
    enable = true;

    font = {
      name = "CaskaydiaMono Nerd Font Mono";
      size = 12;
    };

    settings = {
      # Window settings
      window_padding_width = 14;
      background_opacity = "1.0"; # No transparency

      # Font settings
      bold_font = "CaskaydiaMono Nerd Font Mono Bold";
      italic_font = "CaskaydiaMono Nerd Font Mono Italic";
      bold_italic_font = "CaskaydiaMono Nerd Font Mono Bold Italic";

      # Cursor settings - block cursor with blinking and trail effect
      cursor_shape = "block";
      cursor_blink_interval = "0.5";
      cursor_stop_blinking_after = 0; # Never stop blinking
      cursor_trail = 3; # Smear/trail effect (0-5, higher = longer trail)

      # Theme colors
      background = theme.bg;
      foreground = theme.fg; # Use normal foreground, not dim

      # Color adjustments for better readability
      # Higher values = more aggressive contrast adjustment (max 21)
      minimum_contrast = "7.0";

      # Selection colors
      selection_background = theme.accent;
      selection_foreground = theme.bg;

      # Cursor color
      cursor = theme.fg; # Use normal foreground for cursor
      cursor_text_color = theme.bg;

      # Terminal colors - Normal
      color0 = theme.term_black;
      color1 = theme.term_red;
      color2 = theme.term_green;
      color3 = theme.term_yellow;
      color4 = theme.term_blue;
      color5 = theme.term_magenta;
      color6 = theme.term_cyan;
      color7 = theme.term_white;

      # Terminal colors - Bright
      color8 = theme.term_bright_black;
      color9 = theme.term_bright_red;
      color10 = theme.term_bright_green;
      color11 = theme.term_bright_yellow;
      color12 = theme.term_bright_blue;
      color13 = theme.term_bright_magenta;
      color14 = theme.term_bright_cyan;
      color15 = theme.term_bright_white;

      # URL colors
      url_color = theme.accent;
      url_style = "single";

      # Tab bar colors
      active_tab_background = theme.accent;
      active_tab_foreground = theme.bg;
      inactive_tab_background = theme.bg_highlight;
      inactive_tab_foreground = theme.fg_dim;
      tab_bar_background = theme.bg_dark;

      # Performance
      repaint_delay = 10;
      input_delay = 3;
      sync_to_monitor = true;

      # Scrollback
      scrollback_lines = 10000;

      # Scrollbar - visible for touchscreen use
      scrollbar = "always";
      scrollbar_width = 1;
      scrollbar_hover_width = 2;
      scrollbar_radius = "0.5";
      scrollbar_gap = "0.1";
      scrollbar_handle_opacity = "0.6";
      scrollbar_track_opacity = "0.1";
      scrollbar_interactive = true;
      scrollbar_jump_on_click = true;
      scrollbar_min_handle_height = 2;
      scrollbar_handle_color = theme.fg_dim;
      scrollbar_track_color = theme.bg_highlight;

      # Bell and notifications - all disabled
      enable_audio_bell = false;
      visual_bell_duration = 0;
      window_alert_on_bell = false;
      command_on_bell = "none";

      # Mouse
      mouse_hide_wait = 3;

      # Disable remote control to prevent permission notifications
      allow_remote_control = "no";

      # Enable shell integration but control cursor ourselves
      shell_integration = "enabled no-cursor";

      # Disable update checking
      update_check_interval = 0;

      # Window decorations
      hide_window_decorations = false;

      # Tabs
      tab_bar_edge = "bottom";
      tab_bar_style = "powerline";
      tab_powerline_style = "slanted";

      # Copy on select
      copy_on_select = false;

      # Paste behavior
      paste_actions = "quote-urls-at-prompt";

      # Terminal bell
      terminal_bell_path = "none";

      # Resize in steps
      resize_in_steps = false;

      # Don't confirm when closing with active processes
      confirm_os_window_close = 0;
    };

    keybindings = {
      # Font size controls
      "ctrl+shift+equal" = "change_font_size all +1.0";
      "ctrl+shift+minus" = "change_font_size all -1.0";
      "ctrl+shift+0" = "change_font_size all 0";

      # Copy/paste
      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+shift+v" = "paste_from_clipboard";

      # Tab management
      "ctrl+shift+t" = "new_tab";
      "ctrl+shift+q" = "close_tab";
      "ctrl+shift+right" = "next_tab";
      "ctrl+shift+left" = "previous_tab";

      # Window management
      "ctrl+shift+enter" = "new_window";
      "ctrl+shift+w" = "close_window";
      "ctrl+shift+]" = "next_window";
      "ctrl+shift+[" = "previous_window";

      # Scrolling
      "ctrl+shift+up" = "scroll_line_up";
      "ctrl+shift+down" = "scroll_line_down";
      "ctrl+shift+page_up" = "scroll_page_up";
      "ctrl+shift+page_down" = "scroll_page_down";
      "ctrl+shift+home" = "scroll_home";
      "ctrl+shift+end" = "scroll_end";

      # Clear scrollback
      "ctrl+shift+k" = "clear_terminal scrollback active";
    };

    # Extra config for advanced features
    extraConfig = ''
      # Add live config reload support
      # When theme changes, kitty can be signaled to reload

      # Performance tuning for Wayland
      linux_display_server wayland
      wayland_enable_ime yes

      # Better rendering on HiDPI with contrast adjustment
      # First number is gamma (text thickness), second is how much to scale based on bg/fg luminance
      text_composition_strategy 1.0 1.75

      # Dim inactive windows slightly
      inactive_text_alpha 0.8

      # URL handling
      detect_urls yes
      open_url_with default

      # Strip trailing spaces on paste
      strip_trailing_spaces smart

      # Clipboard integration
      clipboard_control write-clipboard write-primary read-clipboard read-primary
    '';
  };
}
