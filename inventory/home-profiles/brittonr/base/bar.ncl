# Status bar settings — source of truth.
#
# Layout, sizing, and format options for the status bar.
# Theme-dependent values (calendar colors, waybar colors) are resolved
# by the Nix stub from config.theme.data since themes are dynamic.
#
# Consumed by: bar.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/bar.ncl
#   3. Commit .ncl
let Positive =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

let NonNeg =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 0 => 'Ok,
    _ => 'Error { message = "must be a non-negative number" },
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

let Position =
  let valid = ["top", "bottom"] in
  std.contract.from_validator (match {
    value if std.is_string value && std.array.elem value valid => 'Ok,
    value if std.is_string value =>
      'Error {
        message = "unknown position: \"%{value}\"",
        notes = ["Valid: %{std.serialize 'Json valid}"],
      },
    _ => 'Error { message = "position must be a string" },
  }
  )
in

let Density =
  let valid = ["compact", "default", "spacious"] in
  std.contract.from_validator (match {
    value if std.is_string value && std.array.elem value valid => 'Ok,
    value if std.is_string value =>
      'Error {
        message = "unknown density: \"%{value}\"",
        notes = ["Valid: %{std.serialize 'Json valid}"],
      },
    _ => 'Error { message = "density must be a string" },
  }
  )
in

let DisplayMode =
  let valid = ["always_visible", "auto_hide", "on_demand"] in
  std.contract.from_validator (match {
    value if std.is_string value && std.array.elem value valid => 'Ok,
    value if std.is_string value =>
      'Error {
        message = "unknown display mode: \"%{value}\"",
        notes = ["Valid: %{std.serialize 'Json valid}"],
      },
    _ => 'Error { message = "display mode must be a string" },
  }
  )
in

{
  height | doc "Bar height in pixels" | Positive = 30,
  spacing | doc "Gap between modules" | NonNeg = 4,
  position | doc "Screen edge" | Position = "top",
  floating | doc "Float above windows" | Bool = false,
  density | doc "Spacing density" | Density = "default",
  displayMode | doc "Visibility behavior" | DisplayMode = "always_visible",
  showCapsule | doc "Show capsule decoration" | Bool = true,
  outerCorners | doc "Round outer corners" | Bool = false,
  clockFormat | doc "Strftime-style clock format" | NonEmpty = "HH:mm ddd, MMM dd",
  calendarScrollSensitivity | doc "Scroll speed for calendar widget" | Positive = 1,

  tray | { spacing | doc "Tray icon spacing" | NonNeg } = {
    spacing = 10,
  },

  maxLength
    | {
      title | doc "Max window title chars" | Positive,
      module | doc "Max module label chars" | Positive,
    }
    = {
      title = 50,
      module = 40,
    },

  # Waybar styling — CSS values kept as strings since they include units.
  waybar
    | {
      workspaceHoverOpacity | NonEmpty,
      workspaceHoverBorderOpacity | NonEmpty,
      workspaceActiveShadowOpacity | NonEmpty,
      workspaceActiveHoverShadowOpacity | NonEmpty,
      moduleBgOpacity | NonEmpty,
      moduleRadius | NonEmpty,
      modulePadding | NonEmpty,
      moduleMargin | NonEmpty,
      workspaceMinWidth | NonEmpty,
      blinkDuration | NonEmpty,
    }
    = {
      workspaceHoverOpacity = "0.15",
      workspaceHoverBorderOpacity = "0.25",
      workspaceActiveShadowOpacity = "0.3",
      workspaceActiveHoverShadowOpacity = "0.4",
      moduleBgOpacity = "0.8",
      moduleRadius = "0.5em",
      modulePadding = "0 0.6em",
      moduleMargin = "0 0.15em",
      workspaceMinWidth = "24px",
      blinkDuration = "0.5s",
    },
}
