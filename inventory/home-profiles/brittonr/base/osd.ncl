# On-screen display settings — source of truth.
#
# Defines OSD location and timing settings for volume
# and brightness overlays.
#
# Consumed by: osd.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/osd.ncl
#   3. Commit .ncl
let Location =
  std.contract.from_validator (match {
    "top_left" => 'Ok,
    "top_right" => 'Ok,
    "bottom_left" => 'Ok,
    "bottom_right" => 'Ok,
    "center" => 'Ok,
    _ => 'Error { message = "must be one of: top_left, top_right, bottom_left, bottom_right, center" },
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

{
  enabled | doc "Enable on-screen display" | Bool = true,
  location | doc "OSD display location" | Location = "top_right",
  autoHideMs | doc "Auto-hide timeout in milliseconds" | Positive = 2000,
}
