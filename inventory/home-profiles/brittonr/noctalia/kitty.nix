{ config, lib, ... }:
let
  theme = config.theme.colors;
  k = config.keymap;
  tm = lib.toLower k.modifiers.terminal; # "ctrl+shift"
  ta = k.terminalActions;
in
{
  programs.kitty = {
    enable = true;

    font = {
      name = config.font.mono;
      size = config.font.size.terminal;
    };

    settings = {
      # Window settings
      window_padding_width = config.layout.terminal.padding;
      background_opacity = "1.0"; # No transparency

      # Font settings
      bold_font = "${config.font.mono} Bold";
      italic_font = "${config.font.mono} Italic";
      bold_italic_font = "${config.font.mono} Bold Italic";

      # Cursor settings - block cursor with blinking and trail effect
      cursor_shape = "block";
      cursor_blink_interval = config.terminal.cursorBlinkInterval;
      cursor_stop_blinking_after = config.terminal.cursorStopBlinkingAfter;
      cursor_trail = config.terminal.cursorTrail;

      # Theme colors
      background = theme.bg;
      foreground = theme.fg; # Use normal foreground, not dim

      # Color adjustments for better readability
      # Higher values = more aggressive contrast adjustment (max 21)
      minimum_contrast = toString config.terminal.minimumContrast;

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
      repaint_delay = config.terminal.repaintDelay;
      input_delay = config.terminal.inputDelay;
      sync_to_monitor = true;

      # Scrollback
      scrollback_lines = config.terminal.scrollbackLines;

      # Scrollbar - visible for touchscreen use
      scrollbar = "always";
      scrollbar_width = config.terminal.scrollbar.width;
      scrollbar_hover_width = config.terminal.scrollbar.hoverWidth;
      scrollbar_radius = toString config.terminal.scrollbar.radius;
      scrollbar_gap = toString config.terminal.scrollbar.gap;
      scrollbar_handle_opacity = toString config.terminal.scrollbar.handleOpacity;
      scrollbar_track_opacity = toString config.terminal.scrollbar.trackOpacity;
      scrollbar_interactive = true;
      scrollbar_jump_on_click = true;
      scrollbar_min_handle_height = config.terminal.scrollbar.minHandleHeight;
      scrollbar_handle_color = theme.fg_dim;
      scrollbar_track_color = theme.bg_highlight;

      # Bell and notifications - all disabled
      enable_audio_bell = false;
      visual_bell_duration = config.terminal.visualBellDuration;
      window_alert_on_bell = false;
      command_on_bell = "none";

      # Mouse
      mouse_hide_wait = config.terminal.mouseHideWait;

      # Disable remote control to prevent permission notifications
      allow_remote_control = "no";

      # Enable shell integration but control cursor ourselves
      shell_integration = "enabled no-cursor";

      # Disable update checking
      update_check_interval = config.terminal.updateCheckInterval;

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
      "${tm}+${ta.fontUp}" = "change_font_size all +1.0";
      "${tm}+${ta.fontDown}" = "change_font_size all -1.0";
      "${tm}+${ta.fontReset}" = "change_font_size all 0";

      # Copy/paste
      "${tm}+${ta.copy}" = "copy_to_clipboard";
      "${tm}+${ta.paste}" = "paste_from_clipboard";

      # Tab management
      "${tm}+${ta.newTab}" = "new_tab";
      "${tm}+${ta.closeTab}" = "close_tab";
      "${tm}+${ta.nextTab}" = "next_tab";
      "${tm}+${ta.prevTab}" = "previous_tab";

      # Window management
      "${tm}+${ta.newWindow}" = "new_window";
      "${tm}+${ta.closeWindow}" = "close_window";
      "${tm}+${ta.nextWindow}" = "next_window";
      "${tm}+${ta.prevWindow}" = "previous_window";

      # Scrolling
      "${tm}+${ta.scrollUp}" = "scroll_line_up";
      "${tm}+${ta.scrollDown}" = "scroll_line_down";
      "${tm}+${ta.scrollPageUp}" = "scroll_page_up";
      "${tm}+${ta.scrollPageDown}" = "scroll_page_down";
      "${tm}+${ta.scrollHome}" = "scroll_home";
      "${tm}+${ta.scrollEnd}" = "scroll_end";

      # Clear scrollback (rebind from ctrl+shift+k to free k for window nav)
      "${tm}+backspace" = "clear_terminal scrollback active";

      # Vim-style tab navigation (hjkl)
      "${tm}+${k.nav.right}" = "next_tab";
      "${tm}+${k.nav.left}" = "previous_tab";

      # Vim-style window navigation (hjkl)
      "${tm}+${k.nav.down}" = "next_window";
      "${tm}+${k.nav.up}" = "previous_window";
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
      text_composition_strategy ${toString config.terminal.textComposition.gamma} ${toString config.terminal.textComposition.scale}

      # Dim inactive windows slightly
      inactive_text_alpha ${toString config.terminal.inactiveTextAlpha}

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
