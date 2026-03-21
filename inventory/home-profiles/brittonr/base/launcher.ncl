# Application launcher settings — source of truth.
#
# Defines dimensions, position, and view mode settings
# for application launchers.
#
# Consumed by: launcher.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/launcher.ncl
#   3. Commit .ncl
let Positive =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

let Position =
  std.contract.from_validator (match {
    "center" => 'Ok,
    "top" => 'Ok,
    "bottom" => 'Ok,
    "left" => 'Ok,
    "right" => 'Ok,
    _ => 'Error { message = "must be one of: center, top, bottom, left, right" },
  }
  )
in

let ViewMode =
  std.contract.from_validator (match {
    "list" => 'Ok,
    "grid" => 'Ok,
    _ => 'Error { message = "must be one of: list, grid" },
  }
  )
in

{
  width | doc "Launcher width in pixels" | Positive = 600,
  height | doc "Launcher height in pixels" | Positive = 500,
  iconSize | doc "Icon size in pixels" | Positive = 40,
  spacing | doc "Spacing between items in pixels" | Positive = 10,
  position | doc "Launcher position on screen" | Position = "center",
  viewMode | doc "Display mode for launcher" | ViewMode = "list",
  sortByMostUsed | doc "Sort applications by usage frequency" | Bool = true,
  enableClipboardHistory | doc "Enable clipboard history integration" | Bool = true,
  fuzzel | doc "Fuzzel-specific settings" = {
    widthPercent | doc "Width as percentage of screen" | Positive = 50,
    horizontalPad | doc "Horizontal padding in pixels" | Positive = 20,
    verticalPad | doc "Vertical padding in pixels" | Positive = 10,
    innerPad | doc "Inner padding in pixels" | Positive = 10,
    scriptWidth | doc "Script width percentage" | Positive = 60,
  },
}
