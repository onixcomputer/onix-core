{ lib, config, ... }:
let
  c = config.theme.data;
  e = c.editor;
  g = c.grayscale;
in
{
  options.helixTheme = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      dark = {
        "ui.background".bg = c.bg.hex;
        "ui.text".fg = g.white.hex;
        "ui.statusline" = {
          bg = c.accent.hex;
          fg = e.black.hex;
          modifiers = [ "bold" ];
        };
        "ui.statusline.insert" = {
          bg = e.function_dark.hex;
          fg = g.white.hex;
          modifiers = [ "bold" ];
        };
        "ui.statusline.select" = {
          bg = e.statusline_select_dark.hex;
          fg = g.white.hex;
          modifiers = [ "bold" ];
        };
        "ui.cursor".bg = c.accent.hex;
        "ui.cursor.primary".bg = e.function_dark.hex;
        "ui.selection".bg = e.selection_dark.hex;
        "ui.menu" = {
          bg = e.surface_dark.hex;
          fg = g.white.hex;
        };
        "ui.menu.selected" = {
          bg = c.accent.hex;
          fg = e.black.hex;
        };
        "ui.popup" = {
          bg = e.popup_dark.hex;
          fg = g.white.hex;
        };
        "ui.linenr".fg = g.dark.hex;
        "ui.linenr.selected" = {
          fg = c.accent.hex;
          modifiers = [ "bold" ];
        };

        "keyword" = {
          fg = c.accent.hex;
          modifiers = [ "bold" ];
        };
        "keyword.control" = {
          fg = e.keyword_control.hex;
          modifiers = [ "bold" ];
        };
        "function" = {
          fg = e.function_dark.hex;
          modifiers = [ "italic" ];
        };
        "function.builtin" = {
          fg = e.function_builtin_dark.hex;
          modifiers = [ "bold" ];
        };
        "type".fg = e.type_dark.hex;
        "type.builtin" = {
          fg = e.type_builtin_dark.hex;
          modifiers = [ "bold" ];
        };
        "string".fg = e.string_dark.hex;
        "string.regexp" = {
          fg = e.string_regexp_dark.hex;
          modifiers = [ "italic" ];
        };
        "comment" = {
          fg = e.comment_dark.hex;
          modifiers = [ "italic" ];
        };
        "variable".fg = g.white.hex;
        "variable.parameter".fg = e.variable_param_dark.hex;
        "constant" = {
          fg = e.constant_dark.hex;
          modifiers = [ "bold" ];
        };
        "constant.numeric".fg = c.orange.hex;
        "operator" = {
          fg = c.accent.hex;
          modifiers = [ "bold" ];
        };
        "punctuation.bracket".fg = e.bracket_dark.hex;
        "tag" = {
          fg = e.function_dark.hex;
          modifiers = [ "bold" ];
        };
        "attribute".fg = c.accent.hex;
        "error" = {
          fg = e.keyword_control.hex;
          modifiers = [ "bold" ];
        };
        "warning" = {
          fg = c.accent.hex;
          modifiers = [ "bold" ];
        };
        "info".fg = e.function_dark.hex;
        "hint".fg = e.hint_color.hex;

        rainbow = [
          c.accent.hex
          e.function_dark.hex
          e.hint_color.hex
          g.white.hex
          e.string_dark.hex
          e.constant_dark.hex
        ];
      };

      light = {
        "ui.background".bg = g.white.hex;
        "ui.text".fg = e.type_builtin_light.hex;
        "ui.statusline" = {
          bg = c.accent.hex;
          fg = g.white.hex;
          modifiers = [ "bold" ];
        };
        "ui.statusline.insert" = {
          bg = e.function_dark.hex;
          fg = g.white.hex;
          modifiers = [ "bold" ];
        };
        "ui.statusline.select" = {
          bg = e.statusline_select_light.hex;
          fg = g.white.hex;
          modifiers = [ "bold" ];
        };
        "ui.cursor".bg = c.accent.hex;
        "ui.cursor.primary".bg = e.function_dark.hex;
        "ui.selection".bg = e.selection_light.hex;
        "ui.menu" = {
          bg = e.surface_light.hex;
          fg = e.type_builtin_light.hex;
        };
        "ui.menu.selected" = {
          bg = c.accent.hex;
          fg = g.white.hex;
        };
        "ui.popup" = {
          bg = e.popup_light.hex;
          fg = e.type_builtin_light.hex;
        };
        "ui.linenr".fg = e.type_builtin_dark.hex;
        "ui.linenr.selected" = {
          fg = c.accent.hex;
          modifiers = [ "bold" ];
        };

        "keyword" = {
          fg = c.accent.hex;
          modifiers = [ "bold" ];
        };
        "keyword.control" = {
          fg = e.keyword_control_light.hex;
          modifiers = [ "bold" ];
        };
        "function" = {
          fg = e.function_light.hex;
          modifiers = [ "italic" ];
        };
        "function.builtin" = {
          fg = e.function_builtin_light.hex;
          modifiers = [ "bold" ];
        };
        "type".fg = e.type_light.hex;
        "type.builtin" = {
          fg = e.type_builtin_light.hex;
          modifiers = [ "bold" ];
        };
        "string".fg = e.string_light.hex;
        "string.regexp" = {
          fg = e.string_regexp_light.hex;
          modifiers = [ "italic" ];
        };
        "comment" = {
          fg = e.comment_light.hex;
          modifiers = [ "italic" ];
        };
        "variable".fg = e.type_builtin_light.hex;
        "variable.parameter".fg = e.variable_param_light.hex;
        "constant" = {
          fg = e.constant_light.hex;
          modifiers = [ "bold" ];
        };
        "constant.numeric".fg = c.accent.hex;
        "operator" = {
          fg = e.keyword_control.hex;
          modifiers = [ "bold" ];
        };
        "punctuation.bracket".fg = e.bracket_light.hex;
        "tag" = {
          fg = e.function_dark.hex;
          modifiers = [ "bold" ];
        };
        "attribute".fg = c.accent.hex;
        "error" = {
          fg = e.error_red.hex;
          modifiers = [ "bold" ];
        };
        "warning" = {
          fg = c.accent.hex;
          modifiers = [ "bold" ];
        };
        "info".fg = e.function_light.hex;
        "hint".fg = e.comment_light.hex;

        rainbow = [
          c.accent.hex
          e.function_dark.hex
          e.bracket_light.hex
          e.type_builtin_light.hex
          e.string_light.hex
          e.constant_light.hex
        ];
      };
    };
    description = "Helix editor theme definitions built from config.theme";
  };
}
