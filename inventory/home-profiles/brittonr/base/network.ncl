# Network connectivity settings — source of truth.
#
# Defines tailscale and WiFi connectivity settings
# for network configuration.
#
# Consumed by: network.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/network.ncl
#   3. Commit .ncl
let NonNeg =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 0 => 'Ok,
    _ => 'Error { message = "must be a non-negative number" },
  }
  )
in

{
  tailscale | doc "Tailscale VPN settings" = {
    acceptRoutes | doc "Accept subnet routes from other nodes" | Bool = true,
  },
  wifi | doc "WiFi settings" = {
    rescanDelay | doc "Rescan delay in seconds" | NonNeg = 2,
  },
}
