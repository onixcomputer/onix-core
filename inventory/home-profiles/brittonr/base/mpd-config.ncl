# MPD service parameters — source of truth.
#
# Port numbers, buffer sizes, timeouts, and audio format for the
# Music Player Daemon. Consumed by mpd and drift configurations.
#
# Consumed by: mpd-config.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/mpd-config.ncl
#   3. Commit .ncl
let Port =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 1 && value <= 65535 => 'Ok,
    _ => 'Error { message = "must be a valid port number (1-65535)" },
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

let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

let ReplayGain =
  let valid = ["off", "track", "album", "auto"] in
  std.contract.from_validator (match {
    value if std.is_string value && std.array.elem value valid => 'Ok,
    value if std.is_string value =>
      'Error {
        message = "unknown replaygain mode: \"%{value}\"",
        notes = ["Valid: %{std.serialize 'Json valid}"],
      },
    _ => 'Error { message = "replaygain must be a string" },
  }
  )
in

let AudioFormat =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.is_match "^[0-9]+:[0-9]+:[0-9]+$" value => 'Ok,
    _ => 'Error { message = "must be rate:bits:channels (e.g. 44100:16:2)" },
  }
  )
in

{
  port | doc "MPD control port" | Port = 6600,
  httpPort | doc "HTTP streaming port" | Port = 8000,
  bufferSize | doc "Output buffer size (KB)" | NonEmpty = "4096",
  maxConnections | doc "Max simultaneous clients" | NonEmpty = "20",
  connectionTimeout | doc "Idle timeout (seconds)" | NonEmpty = "60",
  format | doc "Audio output format (rate:bits:channels)" | AudioFormat = "44100:16:2",
  replaygain | doc "ReplayGain mode" | ReplayGain = "album",
}
