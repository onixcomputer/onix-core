# Color and theme contracts.
#
# Validates hex color format, provides derived-form computation,
# and defines the theme schema for the unified color system.
# Imported by mk-theme.ncl and individual theme files.

# --- Hex conversion lookup table ---
let hex_chars = {
  "0" = 0,
  "1" = 1,
  "2" = 2,
  "3" = 3,
  "4" = 4,
  "5" = 5,
  "6" = 6,
  "7" = 7,
  "8" = 8,
  "9" = 9,
  "a" = 10,
  "b" = 11,
  "c" = 12,
  "d" = 13,
  "e" = 14,
  "f" = 15,
  "A" = 10,
  "B" = 11,
  "C" = 12,
  "D" = 13,
  "E" = 14,
  "F" = 15,
}
in

let hex_byte_to_dec_ = fun hi lo =>
  hex_chars."%{hi}" * 16 + hex_chars."%{lo}"
in

let mk_color_ = fun hex =>
  let lo = std.string.lowercase hex in
  let r = hex_byte_to_dec_ (std.string.substring 1 2 lo) (std.string.substring 2 3 lo) in
  let g = hex_byte_to_dec_ (std.string.substring 3 4 lo) (std.string.substring 4 5 lo) in
  let b = hex_byte_to_dec_ (std.string.substring 5 6 lo) (std.string.substring 6 7 lo) in
  let rs = std.to_string r in
  let gs = std.to_string g in
  let bs = std.to_string b in
  {
    hex = lo,
    no_hash = std.string.substring 1 7 lo,
    rgb = "%{rs}, %{gs}, %{bs}",
    ansi = "38;2;%{rs};%{gs};%{bs}",
  }
in

# --- Exported contracts and utilities ---
{
  HexColor =
    std.contract.from_validator (match {
      value if std.is_string value
        && std.string.is_match "^#[0-9a-fA-F]{6}$" value => 'Ok,
      value if std.is_string value =>
        'Error {
          message = "invalid hex color: \"%{value}\"",
          notes = ["Expected format: #rrggbb (e.g. #ff6600)"],
        },
      _ => 'Error { message = "hex color must be a string" },
    }
    ),

  mk_color = mk_color_,

  # Apply mk_color to every field in a flat record of hex strings
  mk_colors = fun record =>
    std.record.map (fun _name hex => mk_color_ hex) record,
}
