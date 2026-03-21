# Shell configuration — source of truth.
#
# Defines starship prompt settings and other shell
# configuration parameters.
#
# Consumed by: shell-config.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/shell-config.ncl
#   3. Commit .ncl
let NonNeg =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 0 => 'Ok,
    _ => 'Error { message = "must be a non-negative number" },
  }
  )
in

{
  starship | doc "Starship prompt configuration" = {
    truncationLength | doc "Directory truncation length" | NonNeg = 3,
    cmdDurationMinTime | doc "Minimum command duration for display (ms)" | NonNeg = 0,
  },
}
