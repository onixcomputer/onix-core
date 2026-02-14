{ lib, config, ... }:
let
  c = config.colors;
  e = c.editor;
  g = c.grayscale;
in
{
  options.helixTheme = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      dark = {
        "ui.background".bg = c.bg;
        "ui.text".fg = g.white;
        "ui.statusline" = {
          bg = c.accent;
          fg = e.black;
          modifiers = [ "bold" ];
        };
        "ui.statusline.insert" = {
          bg = e.function_dark;
          fg = g.white;
          modifiers = [ "bold" ];
        };
        "ui.statusline.select" = {
          bg = e.statusline_select_dark;
          fg = g.white;
          modifiers = [ "bold" ];
        };
        "ui.cursor".bg = c.accent;
        "ui.cursor.primary".bg = e.function_dark;
        "ui.selection".bg = e.selection_dark;
        "ui.menu" = {
          bg = e.surface_dark;
          fg = g.white;
        };
        "ui.menu.selected" = {
          bg = c.accent;
          fg = e.black;
        };
        "ui.popup" = {
          bg = e.popup_dark;
          fg = g.white;
        };
        "ui.linenr".fg = g.dark;
        "ui.linenr.selected" = {
          fg = c.accent;
          modifiers = [ "bold" ];
        };

        "keyword" = {
          fg = c.accent;
          modifiers = [ "bold" ];
        };
        "keyword.control" = {
          fg = e.keyword_control;
          modifiers = [ "bold" ];
        };
        "function" = {
          fg = e.function_dark;
          modifiers = [ "italic" ];
        };
        "function.builtin" = {
          fg = e.function_builtin_dark;
          modifiers = [ "bold" ];
        };
        "type".fg = e.type_dark;
        "type.builtin" = {
          fg = e.type_builtin_dark;
          modifiers = [ "bold" ];
        };
        "string".fg = e.string_dark;
        "string.regexp" = {
          fg = e.string_regexp_dark;
          modifiers = [ "italic" ];
        };
        "comment" = {
          fg = e.comment_dark;
          modifiers = [ "italic" ];
        };
        "variable".fg = g.white;
        "variable.parameter".fg = e.variable_param_dark;
        "constant" = {
          fg = e.constant_dark;
          modifiers = [ "bold" ];
        };
        "constant.numeric".fg = c.orange;
        "operator" = {
          fg = c.accent;
          modifiers = [ "bold" ];
        };
        "punctuation.bracket".fg = e.bracket_dark;
        "tag" = {
          fg = e.function_dark;
          modifiers = [ "bold" ];
        };
        "attribute".fg = c.accent;
        "error" = {
          fg = e.keyword_control;
          modifiers = [ "bold" ];
        };
        "warning" = {
          fg = c.accent;
          modifiers = [ "bold" ];
        };
        "info".fg = e.function_dark;
        "hint".fg = e.hint_color;

        rainbow = [
          c.accent
          e.function_dark
          e.hint_color
          g.white
          e.string_dark
          e.constant_dark
        ];
      };

      light = {
        "ui.background".bg = g.white;
        "ui.text".fg = e.type_builtin_light;
        "ui.statusline" = {
          bg = c.accent;
          fg = g.white;
          modifiers = [ "bold" ];
        };
        "ui.statusline.insert" = {
          bg = e.function_dark;
          fg = g.white;
          modifiers = [ "bold" ];
        };
        "ui.statusline.select" = {
          bg = e.statusline_select_light;
          fg = g.white;
          modifiers = [ "bold" ];
        };
        "ui.cursor".bg = c.accent;
        "ui.cursor.primary".bg = e.function_dark;
        "ui.selection".bg = e.selection_light;
        "ui.menu" = {
          bg = e.surface_light;
          fg = e.type_builtin_light;
        };
        "ui.menu.selected" = {
          bg = c.accent;
          fg = g.white;
        };
        "ui.popup" = {
          bg = e.popup_light;
          fg = e.type_builtin_light;
        };
        "ui.linenr".fg = e.type_builtin_dark;
        "ui.linenr.selected" = {
          fg = c.accent;
          modifiers = [ "bold" ];
        };

        "keyword" = {
          fg = c.accent;
          modifiers = [ "bold" ];
        };
        "keyword.control" = {
          fg = e.keyword_control_light;
          modifiers = [ "bold" ];
        };
        "function" = {
          fg = e.function_light;
          modifiers = [ "italic" ];
        };
        "function.builtin" = {
          fg = e.function_builtin_light;
          modifiers = [ "bold" ];
        };
        "type".fg = e.type_light;
        "type.builtin" = {
          fg = e.type_builtin_light;
          modifiers = [ "bold" ];
        };
        "string".fg = e.string_light;
        "string.regexp" = {
          fg = e.string_regexp_light;
          modifiers = [ "italic" ];
        };
        "comment" = {
          fg = e.comment_light;
          modifiers = [ "italic" ];
        };
        "variable".fg = e.type_builtin_light;
        "variable.parameter".fg = e.variable_param_light;
        "constant" = {
          fg = e.constant_light;
          modifiers = [ "bold" ];
        };
        "constant.numeric".fg = c.accent;
        "operator" = {
          fg = e.keyword_control;
          modifiers = [ "bold" ];
        };
        "punctuation.bracket".fg = e.bracket_light;
        "tag" = {
          fg = e.function_dark;
          modifiers = [ "bold" ];
        };
        "attribute".fg = c.accent;
        "error" = {
          fg = e.error_red;
          modifiers = [ "bold" ];
        };
        "warning" = {
          fg = c.accent;
          modifiers = [ "bold" ];
        };
        "info".fg = e.function_light;
        "hint".fg = e.comment_light;

        rainbow = [
          c.accent
          e.function_dark
          e.bracket_light
          e.type_builtin_light
          e.string_light
          e.constant_light
        ];
      };
    };
    description = "Helix editor theme definitions built from config.colors";
  };
}
