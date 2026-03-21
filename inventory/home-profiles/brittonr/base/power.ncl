# Power management settings — source of truth.
#
# Defines battery warning/critical/danger/full thresholds and
# temperature critical thresholds for power management.
#
# Consumed by: power.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/power.ncl
#   3. Commit .ncl
let BatteryPercentage =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 0 && value <= 100 => 'Ok,
    _ => 'Error { message = "must be a number between 0 and 100" },
  }
  )
in

let TemperatureCelsius =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 0 && value <= 150 => 'Ok,
    _ => 'Error { message = "must be a temperature between 0 and 150 degrees Celsius" },
  }
  )
in

{
  battery | doc "Battery threshold settings" = {
    warning | doc "Battery warning level (%)" | BatteryPercentage = 20,
    critical | doc "Battery critical level (%)" | BatteryPercentage = 10,
    danger | doc "Battery danger level (%)" | BatteryPercentage = 5,
    full | doc "Battery full level (%)" | BatteryPercentage = 95,
  },
  temperature | doc "Temperature threshold settings" = {
    critical | doc "Critical temperature threshold (°C)" | TemperatureCelsius = 80,
  },
}
