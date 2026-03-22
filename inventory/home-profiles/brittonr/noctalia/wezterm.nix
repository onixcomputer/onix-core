{ config, lib, ... }:
let
  theme = config.theme.data;
  k = config.keymap;

  # Convert keymap modifier "Ctrl+Shift" → wezterm format "CTRL|SHIFT"
  weztermMods = builtins.replaceStrings [ "+" ] [ "|" ] (lib.toUpper k.modifiers.terminal);

  # Map keymap key names to wezterm key names
  weztermKey =
    key:
    let
      mapping = {
        "equal" = "=";
        "minus" = "-";
        "up" = "UpArrow";
        "down" = "DownArrow";
        "left" = "LeftArrow";
        "right" = "RightArrow";
        "page_up" = "PageUp";
        "page_down" = "PageDown";
        "home" = "Home";
        "end" = "End";
        "enter" = "Enter";
        "backspace" = "Backspace";
        "tab" = "Tab";
        "escape" = "Escape";
        "space" = "Space";
      };
    in
    mapping.${key} or key;

  ta = k.terminalActions;
in
{
  xdg.configFile."wezterm/colors.lua".text = ''
    return {
      background = '${theme.bg.hex}',
      foreground = '${theme.fg.hex}',
      cursor_bg = '${theme.fg.hex}',
      cursor_fg = '${theme.bg.hex}',
      cursor_border = '${theme.fg.hex}',
      selection_bg = '${theme.accent.hex}',
      selection_fg = '${theme.bg.hex}',
      scrollbar_thumb = '${theme.bg_highlight.hex}',

      ansi = {
        '${theme.term_black.hex}',
        '${theme.term_red.hex}',
        '${theme.term_green.hex}',
        '${theme.term_yellow.hex}',
        '${theme.term_blue.hex}',
        '${theme.term_magenta.hex}',
        '${theme.term_cyan.hex}',
        '${theme.term_white.hex}',
      },
      brights = {
        '${theme.term_bright_black.hex}',
        '${theme.term_bright_red.hex}',
        '${theme.term_bright_green.hex}',
        '${theme.term_bright_yellow.hex}',
        '${theme.term_bright_blue.hex}',
        '${theme.term_bright_magenta.hex}',
        '${theme.term_bright_cyan.hex}',
        '${theme.term_bright_white.hex}',
      },

      tab_bar = {
        background = '${theme.bg_dark.hex}',
        active_tab = {
          bg_color = '${theme.accent.hex}',
          fg_color = '${theme.bg.hex}',
        },
        inactive_tab = {
          bg_color = '${theme.bg_highlight.hex}',
          fg_color = '${theme.fg_dim.hex}',
        },
        inactive_tab_hover = {
          bg_color = '${theme.bg_highlight.hex}',
          fg_color = '${theme.fg.hex}',
        },
        new_tab = {
          bg_color = '${theme.bg_dark.hex}',
          fg_color = '${theme.fg_dim.hex}',
        },
        new_tab_hover = {
          bg_color = '${theme.bg_highlight.hex}',
          fg_color = '${theme.fg.hex}',
        },
      },
    }
  '';

  programs.wezterm = {
    enable = true;

    extraConfig = ''
      local wezterm = require 'wezterm'
      local config = wezterm.config_builder()

      -- Font
      config.font = wezterm.font '${config.font.mono}'
      config.font_size = ${toString config.font.size.terminal}
      config.freetype_load_flags = 'NO_HINTING'

      -- Window
      config.window_padding = {
        left = ${toString config.layout.terminal.padding},
        right = ${toString config.layout.terminal.padding},
        top = ${toString config.layout.terminal.padding},
        bottom = ${toString config.layout.terminal.padding},
      }
      config.window_background_opacity = 1.0
      config.window_decorations = 'NONE'
      config.window_close_confirmation = 'NeverPrompt'

      -- Cursor
      config.default_cursor_style = 'BlinkingBlock'
      config.cursor_blink_rate = ${toString (builtins.floor (builtins.mul (builtins.fromJSON config.terminal.cursorBlinkInterval) 1000))}
      config.cursor_blink_ease_in = 'Constant'
      config.cursor_blink_ease_out = 'Constant'
      config.force_reverse_video_cursor = true

      -- Performance
      config.animation_fps = 60
      config.max_fps = 240
      config.front_end = 'WebGpu'
      config.webgpu_power_preference = 'HighPerformance'

      -- Wayland
      config.enable_wayland = true
      config.use_ime = true

      -- Inactive pane dimming
      config.inactive_pane_hsb = {
        brightness = ${toString config.terminal.inactiveTextAlpha},
      }

      -- Tab bar
      config.enable_tab_bar = false

      -- Scrollback
      config.scrollback_lines = ${toString config.terminal.scrollbackLines}
      config.enable_scroll_bar = true

      -- Bell
      config.audible_bell = 'Disabled'
      config.visual_bell = {
        fade_in_duration_ms = 0,
        fade_out_duration_ms = 0,
      }

      -- Mouse
      config.hide_mouse_cursor_when_typing = true

      -- Shell integration
      config.term = 'wezterm'

      -- Disable update checks
      config.check_for_updates = false

      -- Colors: prefer Noctalia runtime colors (updated on wallpaper/mode
      -- change), fall back to Nix-generated build-time defaults.
      -- Wezterm auto-reloads when dofile'd paths change on disk.
      local noctalia_ok, noctalia_colors = pcall(dofile, wezterm.home_dir .. '/.config/wezterm/noctalia-colors.lua')
      if noctalia_ok and noctalia_colors then
        config.colors = noctalia_colors
      else
        config.colors = dofile(wezterm.home_dir .. '/.config/wezterm/colors.lua')
      end

      -- Keybindings
      local act = wezterm.action

      config.keys = {
        -- Font size
        { key = '${weztermKey ta.fontUp}', mods = '${weztermMods}', action = act.IncreaseFontSize },
        { key = '${weztermKey ta.fontDown}', mods = '${weztermMods}', action = act.DecreaseFontSize },
        { key = '${weztermKey ta.fontReset}', mods = '${weztermMods}', action = act.ResetFontSize },

        -- Copy / paste
        { key = '${weztermKey ta.copy}', mods = '${weztermMods}', action = act.CopyTo 'Clipboard' },
        { key = '${weztermKey ta.paste}', mods = '${weztermMods}', action = act.PasteFrom 'Clipboard' },

        -- Tabs
        { key = '${weztermKey ta.newTab}', mods = '${weztermMods}', action = act.SpawnTab 'CurrentPaneDomain' },
        { key = '${weztermKey ta.closeTab}', mods = '${weztermMods}', action = act.CloseCurrentTab { confirm = false } },
        { key = '${weztermKey ta.nextTab}', mods = '${weztermMods}', action = act.ActivateTabRelative(1) },
        { key = '${weztermKey ta.prevTab}', mods = '${weztermMods}', action = act.ActivateTabRelative(-1) },

        -- Panes
        { key = '${weztermKey ta.newWindow}', mods = '${weztermMods}', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
        { key = '${weztermKey ta.closeWindow}', mods = '${weztermMods}', action = act.CloseCurrentPane { confirm = false } },
        { key = '${weztermKey ta.nextWindow}', mods = '${weztermMods}', action = act.ActivatePaneDirection 'Next' },
        { key = '${weztermKey ta.prevWindow}', mods = '${weztermMods}', action = act.ActivatePaneDirection 'Prev' },

        -- Scrolling
        { key = '${weztermKey ta.scrollUp}', mods = '${weztermMods}', action = act.ScrollByLine(-1) },
        { key = '${weztermKey ta.scrollDown}', mods = '${weztermMods}', action = act.ScrollByLine(1) },
        { key = '${weztermKey ta.scrollPageUp}', mods = '${weztermMods}', action = act.ScrollByPage(-1) },
        { key = '${weztermKey ta.scrollPageDown}', mods = '${weztermMods}', action = act.ScrollByPage(1) },
        { key = '${weztermKey ta.scrollHome}', mods = '${weztermMods}', action = act.ScrollToTop },
        { key = '${weztermKey ta.scrollEnd}', mods = '${weztermMods}', action = act.ScrollToBottom },

        -- Clear scrollback
        { key = 'Backspace', mods = '${weztermMods}', action = act.ClearScrollback 'ScrollbackAndViewport' },

        -- Vim-style tab navigation
        { key = '${weztermKey k.nav.right}', mods = '${weztermMods}', action = act.ActivateTabRelative(1) },
        { key = '${weztermKey k.nav.left}', mods = '${weztermMods}', action = act.ActivateTabRelative(-1) },

        -- Vim-style pane navigation
        { key = '${weztermKey k.nav.down}', mods = '${weztermMods}', action = act.ActivatePaneDirection 'Next' },
        { key = '${weztermKey k.nav.up}', mods = '${weztermMods}', action = act.ActivatePaneDirection 'Prev' },

        -- Search (helix: /)
        { key = '${weztermKey ta.search}', mods = '${weztermMods}', action = act.Search { CaseSensitiveString = "" } },

        -- Quick select (helix: s)
        { key = '${weztermKey ta.quickSelect}', mods = '${weztermMods}', action = act.QuickSelect },

        -- Copy mode (helix: x)
        { key = '${weztermKey ta.copyMode}', mods = '${weztermMods}', action = act.ActivateCopyMode },

        -- Command palette (helix: space pickers)
        { key = '${weztermKey ta.commandPalette}', mods = '${weztermMods}', action = act.ActivateCommandPalette },

        -- Prompt navigation (helix: C-u / C-d, but at block granularity)
        { key = '${weztermKey ta.promptPrev}', mods = '${weztermMods}', action = act.ScrollToPrompt(-1) },
        { key = '${weztermKey ta.promptNext}', mods = '${weztermMods}', action = act.ScrollToPrompt(1) },
      }

      -- URL handling & scroll speed
      config.mouse_bindings = {
        {
          event = { Up = { streak = 1, button = 'Left' } },
          mods = 'CTRL',
          action = act.OpenLinkAtMouseCursor,
        },
        -- Scroll 1 line per wheel tick (default is ~3-5)
        {
          event = { Down = { streak = 1, button = { WheelUp = 1 } } },
          mods = 'NONE',
          action = act.ScrollByLine(-1),
        },
        {
          event = { Down = { streak = 1, button = { WheelDown = 1 } } },
          mods = 'NONE',
          action = act.ScrollByLine(1),
        },
      }

      return config
    '';
  };
}
