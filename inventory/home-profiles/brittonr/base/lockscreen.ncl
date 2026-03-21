# Lock screen settings — source of truth.
#
# Defines font sizes and fade timeout for hyprlock
# lock screen styling.
#
# Consumed by: lockscreen.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/lockscreen.ncl
#   3. Commit .ncl
let Positive =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

{
  clockFontSize | doc "Clock font size in points" | Positive = 86,
  dateFontSize | doc "Date font size in points" | Positive = 22,
  fadeTimeout | doc "Fade timeout in milliseconds" | Positive = 2000,
}
