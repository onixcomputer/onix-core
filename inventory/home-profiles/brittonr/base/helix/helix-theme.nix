# Helix editor theme — thin stub over helix-theme.ncl.
#
# Colors are flattened to simple strings. Full config.theme.data is
# too large for the WASM stack when serialized as Nickel source text.
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  wasm = import "${inputs.self}/lib/wasm.nix" {
    plugins = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.wasm-plugins;
  };
  c = config.theme.data;
  e = c.editor;
  g = c.grayscale;
  data = wasm.evalNickelFileWith ./helix-theme.ncl {
    accent = c.accent.hex;
    orange = c.orange.hex;
    bg = c.bg.hex;
    g_white = g.white.hex;
    g_dark = g.dark.hex;
    e_black = e.black.hex;
    e_function_dark = e.function_dark.hex;
    e_function_light = e.function_light.hex;
    e_function_builtin_dark = e.function_builtin_dark.hex;
    e_function_builtin_light = e.function_builtin_light.hex;
    e_statusline_select_dark = e.statusline_select_dark.hex;
    e_statusline_select_light = e.statusline_select_light.hex;
    e_selection_dark = e.selection_dark.hex;
    e_selection_light = e.selection_light.hex;
    e_surface_dark = e.surface_dark.hex;
    e_surface_light = e.surface_light.hex;
    e_popup_dark = e.popup_dark.hex;
    e_popup_light = e.popup_light.hex;
    e_keyword_control = e.keyword_control.hex;
    e_keyword_control_light = e.keyword_control_light.hex;
    e_type_dark = e.type_dark.hex;
    e_type_light = e.type_light.hex;
    e_type_builtin_dark = e.type_builtin_dark.hex;
    e_type_builtin_light = e.type_builtin_light.hex;
    e_string_dark = e.string_dark.hex;
    e_string_light = e.string_light.hex;
    e_string_regexp_dark = e.string_regexp_dark.hex;
    e_string_regexp_light = e.string_regexp_light.hex;
    e_comment_dark = e.comment_dark.hex;
    e_comment_light = e.comment_light.hex;
    e_variable_param_dark = e.variable_param_dark.hex;
    e_variable_param_light = e.variable_param_light.hex;
    e_constant_dark = e.constant_dark.hex;
    e_constant_light = e.constant_light.hex;
    e_bracket_dark = e.bracket_dark.hex;
    e_bracket_light = e.bracket_light.hex;
    e_hint_color = e.hint_color.hex;
    e_error_red = e.error_red.hex;
  };
in
{
  options.helixTheme = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = data;
    description = "Helix editor theme definitions built from config.theme";
  };
}
