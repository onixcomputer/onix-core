# Gesture configuration — source of truth.
#
# Defines DnD edge scroll and lisgd gesture settings
# for touchpad and touchscreen input.
#
# Consumed by: gestures.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/gestures.ncl
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

{
  dndEdgeScroll | doc "Drag and drop edge scroll settings" = {
    triggerWidth | doc "Edge trigger width in pixels" | Positive = 40,
    delayMs | doc "Trigger delay in milliseconds" | Positive = 150,
    maxSpeed | doc "Maximum scroll speed" | Positive = 1200,
  },
  lisgd | doc "Lisgd gesture daemon settings" = {
    timeout | doc "Gesture timeout in milliseconds" | Positive = 150,
    outputIndex | doc "Output device index" | NonNeg = 0,
  },
}
