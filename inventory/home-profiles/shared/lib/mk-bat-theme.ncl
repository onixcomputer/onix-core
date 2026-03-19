# Bat tmTheme XML generator.
#
# Takes { name, colors } via evalNickelFileWith and returns an XML plist
# string for bat's TextMate theme format.
#
# Required color fields: bg, fg, orange, blue, cyan, green, yellow,
# red, comment, bg_highlight, border.
let ColorPalette = {
  bg | String,
  fg | String,
  orange | String,
  blue | String,
  cyan | String,
  green | String,
  yellow | String,
  red | String,
  comment | String,
  bg_highlight | String,
  border | String,
}
in

let scope_entry = fun name scope fg style =>
  let fg_block =
    if fg == "" then
      ""
    else
      "      <key>foreground</key>\n      <string>%{fg}</string>"
  in
  let style_block =
    if style == "" then
      ""
    else
      "      <key>fontStyle</key>\n      <string>%{style}</string>"
  in
  let settings_inner =
    std.string.join
      "\n"
      (
        std.array.filter (fun s => s != "") [fg_block, style_block]
      )
  in
  m%"
    <dict>
      <key>name</key>
      <string>%{name}</string>
      <key>scope</key>
      <string>%{scope}</string>
      <key>settings</key>
      <dict>
  %{settings_inner}
      </dict>
    </dict>"%
in

fun args =>
  let name | String = args.name in
  let c | ColorPalette = args.colors in
  m%"<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>name</key>
  <string>%{name}</string>
  <key>settings</key>
  <array>
    <dict>
      <key>settings</key>
      <dict>
        <key>background</key>
        <string>%{c.bg}</string>
        <key>foreground</key>
        <string>%{c.fg}</string>
        <key>caret</key>
        <string>%{c.orange}</string>
        <key>lineHighlight</key>
        <string>%{c.bg_highlight}</string>
        <key>selection</key>
        <string>%{c.border}</string>
      </dict>
    </dict>
    %{scope_entry "Comment" "comment" c.comment "italic"}
    %{scope_entry "String" "string" c.yellow ""}
    %{scope_entry "Number" "constant.numeric" c.cyan ""}
    %{scope_entry "Keyword" "keyword" c.orange "bold"}
    %{scope_entry "Function" "entity.name.function" c.blue ""}
    %{scope_entry "Type" "entity.name.type, entity.name.class" c.cyan ""}
    %{scope_entry "Variable" "variable" c.fg ""}
    %{scope_entry "Operator" "keyword.operator" c.orange ""}
    %{scope_entry "Constant" "constant" c.cyan ""}
    %{scope_entry "Markup Heading" "markup.heading" c.orange "bold"}
    %{scope_entry "Markup Bold" "markup.bold" "" "bold"}
    %{scope_entry "Markup Italic" "markup.italic" "" "italic"}
    %{scope_entry "Markup Code" "markup.inline.raw, markup.fenced_code" c.green ""}
    %{scope_entry "Diff Added" "markup.inserted" c.green ""}
    %{scope_entry "Diff Deleted" "markup.deleted" c.red ""}
    %{scope_entry "Diff Changed" "markup.changed" c.yellow ""}
  </array>
</dict>
</plist>"%
