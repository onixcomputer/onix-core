# Niri keybindings — source of truth.
#
# Structured binding definitions that get rendered to KDL by the Nix
# stub. Imports keymap.ncl for key names, apps.ncl for app identifiers,
# and settings.ncl for layout values.
#
# Three binding types:
#   action — built-in niri action (e.g. close-window)
#   spawn  — launch a process with args (@placeholder@ for store paths)
#   raw    — pre-formatted KDL action string (for complex one-offs)
#
# Consumed by: niri-keybinds.nix (renders to KDL)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/noctalia/lib/niri-keybinds.ncl
#   3. Commit .ncl
let keymap = import "../../base/keymap.ncl" in
let settings = import "../../base/settings.ncl" in

let mod = keymap.modifiers.wm in
let alt = keymap.modifiers.secondary in
let nav = keymap.nav in
let wm = keymap.wm in

# Uppercase helper for nav keys (niri wants H not h)
let up = fun s =>
  let bytes = std.string.to_number (std.string.substring 0 1 s |> std.string.uppercase |> std.string.from_enum) in
  "%{std.string.uppercase s}"
in

# Actually, Nickel's std.string.uppercase works on the whole string
let up = std.string.uppercase in

let ipc = fun target action =>
  ["@noctalia-shell@", "ipc", "call", target, action]
in

let resize_pct = "%{std.to_string settings.layout.resizePercent}%%" in

# --- Niri action name registry ---
let valid_actions = [
  "close-window",
  "consume-or-expel-window-left",
  "consume-or-expel-window-right",
  "fit-workspace-columns",
  "focus-column-left",
  "focus-column-right",
  "focus-monitor-down",
  "focus-monitor-left",
  "focus-monitor-previous",
  "focus-monitor-right",
  "focus-monitor-up",
  "focus-window-down",
  "focus-window-or-workspace-down",
  "focus-window-or-workspace-up",
  "focus-window-up",
  "focus-workspace",
  "focus-workspace-down",
  "focus-workspace-up",
  "fullscreen-window",
  "maximize-column",
  "move-column-left",
  "move-column-right",
  "move-column-to-monitor-down",
  "move-column-to-monitor-left",
  "move-column-to-monitor-right",
  "move-column-to-monitor-up",
  "move-column-to-workspace",
  "move-window-down",
  "move-window-down-or-to-workspace-down",
  "move-window-up",
  "move-window-up-or-to-workspace-up",
  "power-off-monitors",
  "screenshot-screen",
  "set-column-width",
  "set-window-height",
  "show-hotkey-overlay",
  "switch-preset-column-width",
  "toggle-column-tabbed-display",
  "toggle-overview",
  "toggle-window-floating",
]
in

let NiriAction =
  std.contract.from_validator (match {
    value if std.is_string value && std.array.elem value valid_actions => 'Ok,
    value if std.is_string value =>
      'Error { message = "unknown niri action: \"%{value}\"" },
    _ => 'Error { message = "action must be a string" },
  }
  )
in

let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

# --- Binding record types ---
let ActionBinding = {
  key | NonEmpty,
  action | NiriAction,
  args | String | optional,
  comment | String | optional,
}
in

let SpawnBinding = {
  key | NonEmpty,
  spawn | Array String,
  comment | String | optional,
}
in

let RawBinding = {
  key | NonEmpty,
  raw | NonEmpty,
  comment | String | optional,
}
in

# --- Directional binding generators ---
# vim_binds: only vim nav keys (hjkl)
let vim_binds = fun modifier left_action right_action up_action down_action =>
  [
    { key = "%{modifier}+%{up nav.left}", action = left_action },
    { key = "%{modifier}+%{up nav.right}", action = right_action },
    { key = "%{modifier}+%{up nav.up}", action = up_action },
    { key = "%{modifier}+%{up nav.down}", action = down_action },
  ]
in

# dir_binds: vim keys + arrow keys
let dir_binds = fun modifier left_action right_action up_action down_action =>
  vim_binds modifier left_action right_action up_action down_action
  @ [
    { key = "%{modifier}+Left", action = left_action },
    { key = "%{modifier}+Right", action = right_action },
    { key = "%{modifier}+Up", action = up_action },
    { key = "%{modifier}+Down", action = down_action },
  ]
in

# --- Workspace binding generator ---
let workspace_focus =
  std.array.generate
    (fun i =>
      let n = i + 1 in
      let key_char = if n == 10 then "0" else std.to_string n in
      { key = "%{mod}+%{key_char}", action = "focus-workspace", args = std.to_string n }
    )
    10
in

let workspace_move =
  std.array.generate
    (fun i =>
      let n = i + 1 in
      let key_char = if n == 10 then "0" else std.to_string n in
      { key = "%{mod}+Shift+%{key_char}", action = "move-column-to-workspace", args = std.to_string n }
    )
    10
in

{
  # --- Window management ---
  windowManagement | Array ActionBinding = [
    { key = "%{mod}+Shift+Slash", action = "show-hotkey-overlay" },
    { key = "%{mod}+%{wm.close}", action = "close-window" },
    { key = "%{mod}+%{wm.toggleTabs}", action = "toggle-column-tabbed-display" },
    { key = "%{mod}+%{wm.fullscreen}", action = "fullscreen-window" },
    { key = "%{alt}+F", action = "toggle-window-floating" },
    { key = "%{mod}+%{wm.maxColumn}", action = "maximize-column" },
    { key = "%{mod}+Shift+%{wm.maxColumn}", action = "fit-workspace-columns" },
    { key = "%{mod}+%{wm.presetWidth}", action = "switch-preset-column-width" },
    { key = "%{mod}+%{wm.overview}", action = "toggle-overview" },
    { key = "%{mod}+Shift+O", action = "power-off-monitors" },
  ],

  windowManagementSpawn | Array SpawnBinding = [
    { key = "%{mod}+Y", spawn = ["toggle-sticky-window"] },
    { key = "%{mod}+%{wm.reload}", spawn = ["niri", "msg", "action", "load-config-file"] },
  ],

  windowManagementRaw | Array RawBinding = [
    { key = "%{mod}+Control+%{wm.maxColumn}", raw = "fit-workspace-columns grid=true" },
  ],

  # --- Focus (vim + arrow + alt variants) ---
  # Vim and alt use workspace-crossing up/down; arrows use simpler window-only
  focusNav | Array ActionBinding =
    vim_binds
      mod
      "focus-column-left"
      "focus-column-right"
      "focus-window-or-workspace-up"
      "focus-window-or-workspace-down"
    @ [
      # Arrow keys — simpler up/down (no workspace crossing)
      { key = "%{mod}+Left", action = "focus-column-left" },
      { key = "%{mod}+Right", action = "focus-column-right" },
      { key = "%{mod}+Up", action = "focus-window-up" },
      { key = "%{mod}+Down", action = "focus-window-down" },
    ]
    @ vim_binds
      alt
      "focus-column-left"
      "focus-column-right"
      "focus-window-or-workspace-up"
      "focus-window-or-workspace-down"
    @ [
      { key = "%{mod}+WheelScrollUp", action = "focus-workspace-up" },
      { key = "%{mod}+WheelScrollDown", action = "focus-workspace-down" },
    ],

  # --- Move windows (vim + arrow) ---
  # Vim uses workspace-crossing; arrows use simpler window-only
  moveNav | Array ActionBinding =
    vim_binds
      "%{mod}+Control"
      "move-column-left"
      "move-column-right"
      "move-window-up-or-to-workspace-up"
      "move-window-down-or-to-workspace-down"
    @ [
      { key = "%{mod}+Control+Left", action = "move-column-left" },
      { key = "%{mod}+Control+Right", action = "move-column-right" },
      { key = "%{mod}+Control+Up", action = "move-window-up" },
      { key = "%{mod}+Control+Down", action = "move-window-down" },
    ],

  # --- Monitor focus (vim + arrow) ---
  monitorNav | Array ActionBinding =
    [{ key = "%{mod}+Escape", action = "focus-monitor-previous" }]
    @ dir_binds
      "%{mod}+Shift"
      "focus-monitor-left"
      "focus-monitor-right"
      "focus-monitor-up"
      "focus-monitor-down",

  # --- Move to monitor (vim + arrow) ---
  monitorMove | Array ActionBinding =
    dir_binds
      "%{mod}+Control+Shift"
      "move-column-to-monitor-left"
      "move-column-to-monitor-right"
      "move-column-to-monitor-up"
      "move-column-to-monitor-down",

  # --- Column operations ---
  columns | Array ActionBinding = [
    { key = "%{mod}+BracketLeft", action = "consume-or-expel-window-left" },
    { key = "%{mod}+BracketRight", action = "consume-or-expel-window-right" },
  ],

  # --- Resizing ---
  resize | Array RawBinding = [
    { key = "%{mod}+Minus", raw = "set-column-width \"-%{resize_pct}\"" },
    { key = "%{mod}+Equal", raw = "set-column-width \"+%{resize_pct}\"" },
    { key = "%{mod}+Shift+Minus", raw = "set-window-height \"-%{resize_pct}\"" },
    { key = "%{mod}+Shift+Equal", raw = "set-window-height \"+%{resize_pct}\"" },
  ],

  # --- Workspaces (generated from count) ---
  workspaceFocus | Array ActionBinding = workspace_focus,
  workspaceMove | Array ActionBinding = workspace_move,

  # --- Application launchers ---
  applications | Array SpawnBinding = [
    { key = "%{mod}+%{wm.terminal}", spawn = ["@terminal@"] },
    { key = "%{mod}+Shift+%{wm.terminal}", spawn = ["sh", "-c", "@terminal@ --directory $(@xcwd@)"] },
    { key = "%{mod}+%{wm.fileManager}", spawn = ["sh", "-c", "@terminal@ --directory $(@xcwd@) @fileManager@"] },
    { key = "%{mod}+%{wm.browser}", spawn = ["@browser@"] },
    { key = "%{mod}+%{wm.sysmon}", spawn = ["@terminal@", "@sysmon@"] },
    { key = "%{mod}+Period", spawn = ["bemoji", "-t"], comment = "Emoji picker" },
    { key = "%{mod}+Control+W", spawn = ["@terminal@", "impala"], comment = "WiFi TUI" },
    { key = "%{mod}+Control+B", spawn = ["@terminal@", "bluetui"], comment = "Bluetooth TUI" },
  ],

  # --- Noctalia IPC ---
  noctalia | Array SpawnBinding = [
    { key = "%{mod}+%{wm.launcher}", spawn = ipc "launcher" "toggle" },
    { key = "%{mod}+%{wm.clipboard}", spawn = ipc "launcher" "clipboard" },
    { key = "%{mod}+N", spawn = ipc "controlCenter" "toggle" },
    { key = "%{mod}+G", spawn = ipc "sessionMenu" "toggle" },
    { key = "%{mod}+%{wm.themeToggle}", spawn = ipc "darkMode" "toggle" },
    { key = "%{mod}+Comma", spawn = ipc "notifications" "dismissAll" },
    { key = "%{mod}+Shift+Comma", spawn = ipc "notifications" "clear" },
    { key = "%{mod}+Shift+Escape", spawn = ipc "lockScreen" "lock", comment = "Lock screen" },
    { key = "%{mod}+Shift+W", spawn = ipc "wallpaper" "toggle" },
  ],

  # --- Media / hardware keys ---
  media | Array SpawnBinding = [
    { key = "XF86AudioRaiseVolume", spawn = ipc "volume" "increase" },
    { key = "XF86AudioLowerVolume", spawn = ipc "volume" "decrease" },
    { key = "XF86AudioMute", spawn = ipc "volume" "muteOutput" },
    { key = "XF86AudioMicMute", spawn = ipc "volume" "muteInput" },
    { key = "XF86AudioNext", spawn = ["playerctl", "next"] },
    { key = "XF86AudioPause", spawn = ["playerctl", "play-pause"] },
    { key = "XF86AudioPlay", spawn = ["playerctl", "play-pause"] },
    { key = "XF86AudioPrev", spawn = ["playerctl", "previous"] },
    { key = "XF86MonBrightnessUp", spawn = ipc "brightness" "increase" },
    { key = "XF86MonBrightnessDown", spawn = ipc "brightness" "decrease" },
    { key = "%{mod}+TouchpadScrollUp", spawn = ipc "volume" "increase" },
    { key = "%{mod}+TouchpadScrollDown", spawn = ipc "volume" "decrease" },
  ],

  # --- Screenshots & recording ---
  capture | Array SpawnBinding = [
    { key = "%{mod}+%{wm.screenshot}", spawn = ["screenshot-region"] },
    { key = "%{mod}+Print", spawn = ["screenshot-screen-edit"] },
    { key = "%{mod}+Shift+P", spawn = ["color-picker"] },
    { key = "%{mod}+Control+R", spawn = ["record-region"] },
    { key = "%{mod}+Shift+%{wm.close}", spawn = ["record-stop"] },
  ],

  captureActions | Array ActionBinding = [
    { key = "Print", action = "screenshot-screen" },
  ],
}
