# Theme builder.
#
# Accepts a theme spec with required color fields and optional overrides,
# merges defaults, and applies mk_color to produce fully expanded output
# with all derived forms (hex, no_hash, rgb, ansi) pre-computed.
#
# Usage from a theme file:
#   let mk_theme = import "./mk-theme.ncl" in
#   mk_theme { name = "My Theme", base00 = "#1a1b26", ... }
let contracts = import "./contracts.ncl" in
let mc = contracts.mk_color in

# NOTE: To allow theme overrides, all default records use | default on every field.
# This is verbose but explicit — Nickel's merge semantics require it.

# --- Default values for optional fields ---
let default_opacity = {
  terminal | default = "0.92",
  popups | default = "0.90",
  notifications | default = "0.90",
}
in

let default_waybar = {
  workspace_hover_opacity | default = "0.15",
  workspace_hover_border_opacity | default = "0.25",
  workspace_active_shadow_opacity | default = "0.3",
  workspace_active_hover_shadow_opacity | default = "0.4",
  module_bg_opacity | default = "0.8",
  module_radius | default = "0.5em",
}
in

# --- Default extension blocks (CLI sub-palettes) ---
let default_editor = {
  black | default = "#000000",
  selection_dark | default = "#333333",
  selection_light | default = "#e6f3ff",
  popup_dark | default = "#2a2a2a",
  popup_light | default = "#f0f0f0",
  surface_dark | default = "#2a2a2a",
  surface_light | default = "#f5f5f5",
  keyword_control | default = "#ff3300",
  keyword_control_light | default = "#cc3300",
  function_dark | default = "#0099ff",
  function_builtin_dark | default = "#0066cc",
  function_light | default = "#0066cc",
  function_builtin_light | default = "#004499",
  string_dark | default = "#00cc66",
  string_regexp_dark | default = "#009944",
  string_light | default = "#008844",
  string_regexp_light | default = "#006633",
  constant_dark | default = "#ffcc00",
  constant_light | default = "#cc8800",
  type_dark | default = "#cccccc",
  type_builtin_dark | default = "#aaaaaa",
  type_light | default = "#555555",
  type_builtin_light | default = "#333333",
  variable_param_dark | default = "#ccccff",
  variable_param_light | default = "#4455cc",
  comment_dark | default = "#777777",
  comment_light | default = "#999999",
  bracket_dark | default = "#cccccc",
  bracket_light | default = "#666666",
  error_red | default = "#cc0000",
  hint_color | default = "#888888",
  statusline_select_dark | default = "#888888",
  statusline_select_light | default = "#666666",
}
in

let default_zen_dark = {
  bg | default = "#1c1c1c",
  bg_elevated | default = "#2a2a2a",
  bg_surface | default = "#252525",
  fg | default = "#d4d4d4",
  fg_muted | default = "#888888",
  fg_inactive | default = "#555555",
  fg_virtual | default = "#3a3a3a",
  fg_linenr | default = "#444444",
  fg_linenr_selected | default = "#666666",
  fg_punctuation | default = "#777777",
  cursor | default = "#5a5a6a",
  cursor_primary | default = "#7a9ec2",
  cursor_match | default = "#4a5a4a",
  selection | default = "#333344",
  selection_primary | default = "#3a3a4a",
  statusline_insert_bg | default = "#3a5a3a",
  statusline_select_bg | default = "#4a4a5a",
  menu_selected_bg | default = "#3a4a5a",
  menu_selected_fg | default = "#ffffff",
  heading | default = "#7a9ec2",
  heading1 | default = "#8ab4f8",
  heading2 | default = "#7aa8d8",
  heading3 | default = "#6a8eb2",
  italic | default = "#b4c4d4",
  link | default = "#7ab4c2",
  link_url | default = "#5a8a9a",
  quote | default = "#888899",
  raw | default = "#9ab48a",
  list_checked | default = "#6a9a6a",
  list_unchecked | default = "#9a6a6a",
  keyword | default = "#c49a6a",
  comment | default = "#666666",
  type | default = "#8ab48a",
  variable | default = "#b4b4c4",
  constant | default = "#c4a47a",
  diag_hint | default = "#5a7a5a",
  diag_info | default = "#5a7a9a",
  diag_warning | default = "#9a8a5a",
  diag_error | default = "#9a5a5a",
  diff_plus | default = "#5a8a5a",
  diff_minus | default = "#8a5a5a",
  diff_delta | default = "#7a7a5a",
}
in

let default_zen_light = {
  bg | default = "#fafafa",
  bg_elevated | default = "#e8e8e8",
  bg_surface | default = "#f0f0f0",
  fg | default = "#333333",
  fg_muted | default = "#666666",
  fg_inactive | default = "#aaaaaa",
  fg_linenr | default = "#cccccc",
  fg_linenr_selected | default = "#999999",
  fg_virtual | default = "#bbbbbb",
  fg_punctuation | default = "#888888",
  cursor | default = "#c0c0d0",
  cursor_primary | default = "#7090c0",
  cursor_match | default = "#d0e8d0",
  selection | default = "#d0d8e8",
  selection_primary | default = "#c0d0e8",
  statusline_insert_bg | default = "#d8e8d8",
  statusline_select_bg | default = "#d8d8e8",
  menu_selected_bg | default = "#c0d0e0",
  menu_selected_fg | default = "#111111",
  heading | default = "#2060a0",
  heading1 | default = "#1858b0",
  heading2 | default = "#2868a8",
  heading3 | default = "#407898",
  italic | default = "#444455",
  link | default = "#206080",
  link_url | default = "#4080a0",
  quote | default = "#666677",
  raw | default = "#408040",
  keyword | default = "#a06020",
  comment | default = "#999999",
  diag_hint | default = "#60a060",
  diag_warning | default = "#a0a060",
  diag_error | default = "#a06060",
  diff_plus | default = "#408040",
  diff_minus | default = "#a04040",
  diff_delta | default = "#808040",
}
in

let default_rainbow = {
  red | default = "#E06C75",
  yellow | default = "#E5C07B",
  blue | default = "#61AFEF",
  orange | default = "#D19A66",
  green | default = "#98C379",
  violet | default = "#C678DD",
  cyan | default = "#56B6C2",
}
in

let default_btop = {
  main_fg | default = "#cfc9c2",
  hi_fg | default = "#7dcfff",
  selected_bg | default = "#414868",
  inactive_fg | default = "#565f89",
}
in

let default_bar_waybar = {
  bg | default = "#16161e",
  fg | default = "#c0caf5",
  accent | default = "#7aa2f7",
  tooltip_bg | default = "#24283b",
  muted | default = "#313244",
  warning | default = "#f9e2af",
  critical | default = "#f38ba8",
  critical_bg | default = "#1e1e2e",
  charging | default = "#a6e3a1",
}
in

let default_misc = {
  docker_accent | default = "#83a598",
  screencast_active | default = "#f38ba8",
  screencast_inactive | default = "#7d0d2d",
}
in

let default_grayscale = {
  white | default = "#ffffff",
  light | default = "#e6e6e6",
  medium | default = "#b3b3b3",
  dim | default = "#808080",
  dark | default = "#666666",
  muted | default = "#999999",
}
in

# --- The builder function ---
fun spec =>
  let or_default = fun field fallback =>
    if std.record.has_field field spec then
      spec."%{field}"
    else
      fallback
  in

  # Terminal colors default to semantic colors (prefixed to avoid record field shadowing)
  let _term_black = or_default "term_black" spec.base01 in
  let _term_red = or_default "term_red" spec.red in
  let _term_green = or_default "term_green" spec.green in
  let _term_yellow = or_default "term_yellow" spec.yellow in
  let _term_blue = or_default "term_blue" spec.blue in
  let _term_magenta = or_default "term_magenta" spec.magenta in
  let _term_cyan = or_default "term_cyan" spec.cyan in
  let _term_white = or_default "term_white" spec.base05 in

  let _term_bright_black = or_default "term_bright_black" spec.base03 in
  let _term_bright_red = or_default "term_bright_red" spec.red in
  let _term_bright_green = or_default "term_bright_green" spec.green in
  let _term_bright_yellow = or_default "term_bright_yellow" spec.orange in
  let _term_bright_blue = or_default "term_bright_blue" spec.blue in
  let _term_bright_magenta = or_default "term_bright_magenta" spec.purple in
  let _term_bright_cyan = or_default "term_bright_cyan" spec.cyan in
  let _term_bright_white = or_default "term_bright_white" spec.base06 in

  let _bg = or_default "bg" spec.base00 in
  let _bg_dark = or_default "bg_dark" spec.base00 in
  let _bg_highlight = or_default "bg_highlight" spec.base02 in
  let _fg = or_default "fg" spec.base06 in
  let _fg_dim = or_default "fg_dim" spec.base05 in
  let _border = or_default "border" spec.base03 in
  let _accent = or_default "accent" spec.blue in
  let _accent2 = or_default "accent2" spec.purple in
  let _comment = or_default "comment" spec.base03 in
  let _term_bg = or_default "term_bg" _bg in
  let _term_fg = or_default "term_fg" _fg in
  let _term_selection = or_default "term_selection" _accent in

  # Extension blocks: merge user overrides with defaults
  let editor_raw = default_editor & (or_default "editor" {}) in
  let zen_dark_raw = default_zen_dark & (or_default "zen_dark" {}) in
  let zen_light_raw = default_zen_light & (or_default "zen_light" {}) in
  let rainbow_raw = default_rainbow & (or_default "rainbow" {}) in
  let btop_raw = default_btop & (or_default "btop" {}) in
  let bar_waybar_raw = default_bar_waybar & (or_default "bar_waybar" {}) in
  let misc_raw = default_misc & (or_default "misc" {}) in
  let grayscale_raw = default_grayscale & (or_default "grayscale" {}) in

  # Build the output with all derived forms
  {
    # Metadata (plain strings, not colors)
    name = spec.name,
    author = spec.author,
    variant = spec.variant,

    # Surface colors
    base00 = mc spec.base00,
    base01 = mc spec.base01,
    base02 = mc spec.base02,
    base03 = mc spec.base03,
    base04 = mc spec.base04,
    base05 = mc spec.base05,
    base06 = mc spec.base06,
    base07 = mc spec.base07,

    # Semantic colors
    red = mc spec.red,
    orange = mc spec.orange,
    yellow = mc spec.yellow,
    green = mc spec.green,
    cyan = mc spec.cyan,
    blue = mc spec.blue,
    purple = mc spec.purple,
    magenta = mc spec.magenta,

    # Special UI colors
    bg = mc _bg,
    bg_dark = mc _bg_dark,
    bg_highlight = mc _bg_highlight,
    fg = mc _fg,
    fg_dim = mc _fg_dim,
    border = mc _border,
    accent = mc _accent,
    accent2 = mc _accent2,
    comment = mc _comment,

    # Terminal special
    term_bg = mc _term_bg,
    term_fg = mc _term_fg,
    term_selection = mc _term_selection,

    # Terminal 16-color
    term_black = mc _term_black,
    term_red = mc _term_red,
    term_green = mc _term_green,
    term_yellow = mc _term_yellow,
    term_blue = mc _term_blue,
    term_magenta = mc _term_magenta,
    term_cyan = mc _term_cyan,
    term_white = mc _term_white,

    term_bright_black = mc _term_bright_black,
    term_bright_red = mc _term_bright_red,
    term_bright_green = mc _term_bright_green,
    term_bright_yellow = mc _term_bright_yellow,
    term_bright_blue = mc _term_bright_blue,
    term_bright_magenta = mc _term_bright_magenta,
    term_bright_cyan = mc _term_bright_cyan,
    term_bright_white = mc _term_bright_white,

    # Convenience RGB values
    accent_rgb = (mc _accent).rgb,
    accent2_rgb = (mc _accent2).rgb,
    bg_dark_rgb = (mc _bg_dark).rgb,

    # Non-color styling (defaults with user overrides winning)
    opacity = default_opacity & (or_default "opacity" {}),
    waybar_style = default_waybar & (or_default "waybar" {}),
    hypr = or_default "hypr" {},

    # GTK metadata (names only, packages added in Nix)
    gtk = or_default "gtk" {},

    # Wallpaper metadata (URLs/hashes only, fetchurl added in Nix)
    wallpapers = or_default "wallpapers" {},

    # Extension blocks — all colors get derived forms
    editor = contracts.mk_colors editor_raw,
    zen = {
      dark = contracts.mk_colors zen_dark_raw,
      light = contracts.mk_colors zen_light_raw,
    },
    rainbow = contracts.mk_colors rainbow_raw,
    btop = contracts.mk_colors btop_raw,
    bar_waybar = contracts.mk_colors bar_waybar_raw,
    misc = contracts.mk_colors misc_raw,
    grayscale = contracts.mk_colors grayscale_raw,
  }
