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

{
  keyboard | doc "Keyboard configuration" = {
    layout | doc "Keyboard layout" | String = "us",
  },
  touchpad | doc "Touchpad configuration" = {
    naturalScroll | doc "Enable natural scroll direction" | Bool = true,
    tap | doc "Enable tap to click" | Bool = true,
    disableWhileTyping | doc "Disable touchpad while typing" | Bool = true,
    accelSpeed | doc "Acceleration speed (-1.0 to 1.0)" | Number = 0.2,
    accelProfile | doc "Acceleration profile" | AccelProfile = "adaptive",
    clickMethod | doc "Click method" | ClickMethod = "clickfinger",
    scrollMethod | doc "Scroll method" | ScrollMethod = "two-finger",
  },
  mouse | doc "Mouse configuration" = {
    focusFollows | doc "Focus follows mouse" | Bool = true,
    warpToFocus | doc "Warp mouse to focused window" | Bool = true,
  },
}
