{ lib, ... }:
let
  hexDigits = {
    "0" = 0;
    "1" = 1;
    "2" = 2;
    "3" = 3;
    "4" = 4;
    "5" = 5;
    "6" = 6;
    "7" = 7;
    "8" = 8;
    "9" = 9;
    "a" = 10;
    "b" = 11;
    "c" = 12;
    "d" = 13;
    "e" = 14;
    "f" = 15;
  };
  hexByteToDec =
    hex:
    hexDigits.${builtins.substring 0 1 (lib.toLower hex)} * 16
    + hexDigits.${builtins.substring 1 1 (lib.toLower hex)};
in
{
  options.colors = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      red = "#ff4444";
      orange = "#ff6600";
      yellow = "#ffaa00";
      green = "#44ff44";
      cyan = "#00ffff";
      blue = "#4488ff";
      purple = "#aa44ff";
      magenta = "#ff44ff";

      bg = "#1a1a1a";
      bg_dark = "#0d0d0d";
      bg_highlight = "#262626";
      fg = "#e6e6e6";
      fg_dim = "#b3b3b3";
      border = "#404040";
      comment = "#595959";

      accent = "#ff6600";
      accent2 = "#ffaa00";

      # Terminal palette (16-color) - Tokyo Night
      term_black = "#32344a";
      term_red = "#f7768e";
      term_green = "#9ece6a";
      term_yellow = "#e0af68";
      term_blue = "#7aa2f7";
      term_magenta = "#ad8ee6";
      term_cyan = "#449dab";
      term_white = "#787c99";

      term_bright_black = "#444b6a";
      term_bright_red = "#ff7a93";
      term_bright_green = "#b9f27c";
      term_bright_yellow = "#ff9e64";
      term_bright_blue = "#7da6ff";
      term_bright_magenta = "#bb9af7";
      term_bright_cyan = "#0db9d7";
      term_bright_white = "#acb0d0";

      # Terminal-specific overrides (may differ from UI bg/fg)
      term_bg = "#1a1b26";
      term_fg = "#a9b1d6";
      term_selection = "#7aa2f7";

      # Grayscale ramp
      grayscale = {
        white = "#ffffff";
        light = "#e6e6e6";
        medium = "#b3b3b3";
        dim = "#808080";
        dark = "#666666";
        muted = "#999999";
      };

      # Editor semantic colors (dark/light theme pairs)
      editor = {
        black = "#000000";
        selection_dark = "#333333";
        selection_light = "#e6f3ff";
        popup_dark = "#2a2a2a";
        popup_light = "#f0f0f0";
        surface_dark = "#2a2a2a";
        surface_light = "#f5f5f5";
        keyword_control = "#ff3300";
        keyword_control_light = "#cc3300";
        function_dark = "#0099ff";
        function_builtin_dark = "#0066cc";
        function_light = "#0066cc";
        function_builtin_light = "#004499";
        string_dark = "#00cc66";
        string_regexp_dark = "#009944";
        string_light = "#008844";
        string_regexp_light = "#006633";
        constant_dark = "#ffcc00";
        constant_light = "#cc8800";
        type_dark = "#cccccc";
        type_builtin_dark = "#aaaaaa";
        type_light = "#555555";
        type_builtin_light = "#333333";
        variable_param_dark = "#ccccff";
        variable_param_light = "#4455cc";
        comment_dark = "#777777";
        comment_light = "#999999";
        bracket_dark = "#cccccc";
        bracket_light = "#666666";
        error_red = "#cc0000";
        hint_color = "#888888";
        statusline_select_dark = "#888888";
        statusline_select_light = "#666666";
      };

      # Waybar / status bar colors (Tokyo Night derived)
      waybar = {
        bg = "#16161e";
        fg = "#c0caf5";
        accent = "#7aa2f7";
        tooltip_bg = "#24283b";
        muted = "#313244";
        warning = "#f9e2af";
        critical = "#f38ba8";
        critical_bg = "#1e1e2e";
        charging = "#a6e3a1";
      };

      # btop theme colors
      btop = {
        main_fg = "#cfc9c2";
        hi_fg = "#7dcfff";
        selected_bg = "#414868";
        inactive_fg = "#565f89";
      };

      # Misc application colors
      docker_accent = "#83a598";

      # Screencasting indicator colors
      screencast_active = "#f38ba8";
      screencast_inactive = "#7d0d2d";

      # Rainbow palette for indent guides and bracket matching
      rainbow = {
        red = "#E06C75";
        yellow = "#E5C07B";
        blue = "#61AFEF";
        orange = "#D19A66";
        green = "#98C379";
        violet = "#C678DD";
        cyan = "#56B6C2";
      };

      # Zen theme colors (distraction-free prose writing)
      zen = {
        dark = {
          # Backgrounds
          bg = "#1c1c1c";
          bg_elevated = "#2a2a2a";
          bg_surface = "#252525";

          # Foregrounds
          fg = "#d4d4d4";
          fg_muted = "#888888";
          fg_inactive = "#555555";
          fg_linenr = "#444444";
          fg_linenr_selected = "#666666";
          fg_punctuation = "#777777";

          # Cursor
          cursor = "#5a5a6a";
          cursor_primary = "#7a9ec2";
          cursor_match = "#4a5a4a";

          # Selection
          selection = "#333344";
          selection_primary = "#3a3a4a";

          # Statusline
          statusline_insert_bg = "#3a5a3a";
          statusline_select_bg = "#4a4a5a";

          # Menu
          menu_selected_bg = "#3a4a5a";
          menu_selected_fg = "#ffffff";

          # Markup / headings
          heading = "#7a9ec2";
          heading1 = "#8ab4f8";
          heading3 = "#6a8eb2";
          italic = "#b4c4d4";
          link = "#7ab4c2";
          link_url = "#5a8a9a";
          quote = "#888899";
          raw = "#9ab48a";
          list_checked = "#6a9a6a";
          list_unchecked = "#9a6a6a";

          # Syntax
          keyword = "#c49a6a";
          type = "#8ab48a";
          variable = "#b4b4c4";
          constant = "#c4a47a";

          # Diagnostics
          diag_hint = "#5a7a5a";
          diag_info = "#5a7a9a";
          diag_warning = "#9a8a5a";
          diag_error = "#9a5a5a";

          # Diff
          diff_plus = "#5a8a5a";
          diff_minus = "#8a5a5a";
          diff_delta = "#7a7a5a";
        };

        light = {
          # Backgrounds
          bg = "#fafafa";
          bg_elevated = "#e8e8e8";
          bg_surface = "#f0f0f0";

          # Foregrounds
          fg = "#333333";
          fg_muted = "#666666";
          fg_inactive = "#aaaaaa";
          fg_linenr = "#cccccc";
          fg_linenr_selected = "#999999";
          fg_virtual = "#bbbbbb";

          # Cursor
          cursor = "#c0c0d0";
          cursor_primary = "#7090c0";

          # Selection
          selection = "#d0d8e8";

          # Statusline
          statusline_insert_bg = "#d8e8d8";
          statusline_select_bg = "#d8d8e8";

          # Menu
          menu_selected_bg = "#c0d0e0";
          menu_selected_fg = "#111111";

          # Markup / headings
          heading = "#2060a0";
          italic = "#444455";
          link = "#206080";
          link_url = "#4080a0";
          quote = "#666677";
          raw = "#408040";

          # Syntax
          keyword = "#a06020";
          comment = "#999999";

          # Diagnostics
          diag_hint = "#60a060";
          diag_warning = "#a0a060";
          diag_error = "#a06060";

          # Diff
          diff_plus = "#408040";
          diff_minus = "#a04040";
          diff_delta = "#808040";
        };
      };

      # RGB variants for transparency (R, G, B as string)
      accent_rgb = "255, 102, 0";
      accent2_rgb = "255, 170, 0";
      bg_dark_rgb = "13, 13, 13";

      # Strip leading # from hex color
      noHash = hex: builtins.substring 1 6 hex;

      # Convert "#rrggbb" to "R, G, B" string
      hexToRgb =
        hex:
        let
          r = toString (hexByteToDec (builtins.substring 1 2 hex));
          g = toString (hexByteToDec (builtins.substring 3 2 hex));
          b = toString (hexByteToDec (builtins.substring 5 2 hex));
        in
        "${r}, ${g}, ${b}";

      # Convert "#rrggbb" to "38;2;R;G;B" for ANSI 256-color sequences
      hexToAnsi =
        hex:
        let
          r = toString (hexByteToDec (builtins.substring 1 2 hex));
          g = toString (hexByteToDec (builtins.substring 3 2 hex));
          b = toString (hexByteToDec (builtins.substring 5 2 hex));
        in
        "38;2;${r};${g};${b}";
    };
    description = "User color palette for CLI tools and non-graphical configs";
  };
}
