# Screenshot annotation settings — source of truth.
#
# Defines satty annotation tool settings for screenshot
# editing and markup.
#
# Consumed by: screenshot.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/screenshot.ncl
#   3. Commit .ncl
let Positive =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

{
  annotationSizeFactor | doc "Size factor for annotations" | Positive = 2.0,
  brushSmoothHistorySize | doc "Brush smoothing history size" | Positive = 5,
}
