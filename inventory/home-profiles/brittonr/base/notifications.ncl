# Notification daemon settings — source of truth.
#
# Defines timeout, dimensions, position, and urgency levels
# for notification systems.
#
# Consumed by: notifications.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/notifications.ncl
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
    "top-left" => 'Ok,
    "top-right" => 'Ok,
    "bottom-left" => 'Ok,
    "bottom-right" => 'Ok,
    _ => 'Error { message = "must be one of: top-left, top-right, bottom-left, bottom-right" },
  }
  )
in

let Location =
  std.contract.from_validator (match {
    "top_left" => 'Ok,
    "top_right" => 'Ok,
    "bottom_left" => 'Ok,
    "bottom_right" => 'Ok,
    _ => 'Error { message = "must be one of: top_left, top_right, bottom_left, bottom_right" },
  }
  )
in

{
  timeout | doc "Notification timeout in milliseconds" | Positive = 5000,
  maxVisible | doc "Maximum visible notifications" | Positive = 5,
  width | doc "Notification width in pixels" | Positive = 300,
  height | doc "Notification height in pixels" | Positive = 100,
  padding | doc "Notification padding in pixels" | Positive = 15,
  margin | doc "Notification margin in pixels" | Positive = 10,
  position | doc "Notification position (hyphenated)" | Position = "top-right",
  location | doc "Notification location (underscored)" | Location = "top_right",
  gap | doc "Gap between notifications in pixels" | Positive = 10,
  iconSize | doc "Icon size in pixels" | Positive = 32,
  maxHistory | doc "Maximum notification history" | Positive = 20,
  urgency | doc "Timeout multipliers by urgency level" = {
    low | Positive = 3,
    normal | Positive = 5,
    critical | Positive = 10,
  },
  noctalia | doc "Noctalia-specific urgency durations" = {
    lowUrgencyDuration | Positive = 3,
    normalUrgencyDuration | Positive = 8,
    criticalUrgencyDuration | Positive = 15,
  },
}
