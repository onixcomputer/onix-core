# Service timing settings — source of truth.
#
# Defines systemd service timing values like restart
# and timeout settings.
#
# Consumed by: services.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/services.ncl
#   3. Commit .ncl
let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

{
  restartSec | doc "Service restart timing settings" = {
    fast | doc "Fast restart interval" | NonEmpty = "5s",
    normal | doc "Normal restart interval" | NonEmpty = "10s",
  },
  timeoutStopSec | doc "Service stop timeout" | NonEmpty = "2s",
}
