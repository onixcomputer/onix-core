# Input device settings — source of truth.
#
# Defines keyboard layout, touchpad, and mouse settings
# for input device configuration.
#
# Consumed by: input.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/input.ncl
#   3. Commit .ncl
let AccelProfile =
  std.contract.from_validator (match {
    "adaptive" => 'Ok,
    "flat" => 'Ok,
    _ => 'Error { message = "must be one of: adaptive, flat" },
  }
  )
in

let ClickMethod =
  std.contract.from_validator (match {
    "clickfinger" => 'Ok,
    "buttonareas" => 'Ok,
    _ => 'Error { message = "must be one of: clickfinger, buttonareas" },
  }
  )
in

let ScrollMethod =
  std.contract.from_validator (match {
    "two-finger" => 'Ok,
    "edge" => 'Ok,
    "button" => 'Ok,
    _ => 'Error { message = "must be one of: two-finger, edge, button" },
  }
  )
in

let TapButtonMap =
  std.contract.from_validator (match {
    "left-right-middle" => 'Ok,
    "left-middle-right" => 'Ok,
    _ => 'Error { message = "must be one of: left-right-middle, left-middle-right" },
  }
  )
in

let Positive =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

let calibration_matrix_length = 6 in
let CalibrationMatrix =
  std.contract.from_validator (match {
    value if std.is_array value && std.array.length value == 0 => 'Ok,
    value if std.is_array value
      && std.array.length value == calibration_matrix_length
      && std.array.all std.is_number value => 'Ok,
    _ => 'Error { message = "must be empty or a six-number libinput calibration matrix" },
  }
  )
in

{
  keyboard | doc "Keyboard configuration" = {
    layout | doc "Keyboard layout" | String = "us",
    options | doc "XKB options (comma separated)" | String = "caps:escape",
  },
  touchpad | doc "Touchpad configuration" = {
    naturalScroll | doc "Enable natural scroll direction" | Bool = true,
    tap | doc "Enable tap to click" | Bool = true,
    disableWhileTyping | doc "Disable touchpad while typing" | Bool = true,
    accelSpeed | doc "Acceleration speed (-1.0 to 1.0)" | Number = 0.2,
    accelProfile | doc "Acceleration profile" | AccelProfile = "adaptive",
    clickMethod | doc "Click method" | ClickMethod = "clickfinger",
    scrollMethod | doc "Scroll method" | ScrollMethod = "two-finger",
    scrollFactor | doc "Touchpad scroll multiplier" | Positive = 0.85,
    tapButtonMap | doc "Touchpad tap button order" | TapButtonMap = "left-right-middle",
    middleEmulation | doc "Enable left+right middle-click emulation" | Bool = true,
  },
  mouse | doc "Mouse configuration" = {
    focusFollows | doc "Focus follows mouse" | Bool = true,
    warpToFocus | doc "Warp mouse to focused window" | Bool = true,
  },
  tablet | doc "Tablet and stylus configuration" = {
    mapToBuiltinOutput | doc "Map absolute stylus coordinates to the built-in display" | Bool = true,
    mapToFocusedOutput | doc "Map stylus coordinates to the focused output" | Bool = false,
    mapToFocusedWindow | doc "Map stylus coordinates to the focused window" | Bool = false,
    leftHanded | doc "Enable left-handed stylus/tablet orientation" | Bool = false,
    calibrationMatrix | doc "Optional libinput tablet calibration matrix" | CalibrationMatrix = [],
  },
}
