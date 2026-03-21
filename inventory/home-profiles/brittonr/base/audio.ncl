# Audio settings — source of truth.
#
# Volume control parameters and bluetooth codec preference.
#
# Consumed by: audio.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/audio.ncl
#   3. Commit .ncl
let Percent =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 0 && value <= 200 => 'Ok,
    _ => 'Error { message = "must be a number between 0 and 200" },
  }
  )
in

let PositiveInt =
  std.contract.from_validator (match {
    value if std.is_number value && value > 0 => 'Ok,
    _ => 'Error { message = "must be a positive number" },
  }
  )
in

let BluetoothCodec =
  let valid = ["sbc", "aac", "ldac", "aptx", "aptx-hd", "lc3"] in
  std.contract.from_validator (match {
    value if std.is_string value && std.array.elem value valid => 'Ok,
    value if std.is_string value =>
      'Error {
        message = "unknown codec: \"%{value}\"",
        notes = ["Valid codecs: %{std.serialize 'Json valid}"],
      },
    _ => 'Error { message = "codec must be a string" },
  }
  )
in

{
  volume
    | {
      step | doc "Volume change per key press" | PositiveInt,
      max | doc "Hard ceiling (>100 = software boost)" | Percent,
      default | doc "Initial volume at session start" | Percent,
    }
    = {
      step = 5,
      max = 150,
      default = 100,
    },

  bluetooth | { codec | doc "Preferred bluetooth audio codec" | BluetoothCodec } = {
    codec = "ldac",
  },
}
