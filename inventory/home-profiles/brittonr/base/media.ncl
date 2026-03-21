# Media player settings — source of truth.
#
# Defines mpv and cava settings with static numeric values.
# Theme-dependent values (subtitles colors, cava gradient)
# are merged in the .nix stub from config.theme.data.
#
# Consumed by: media.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/media.ncl
#   3. Commit .ncl
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

{
  mpv | doc "MPV media player settings" = {
    subFontSize | doc "Subtitle font size" | Positive = 36,
    osdFontSize | doc "On-screen display font size" | Positive = 30,
    seekShort | doc "Short seek duration (seconds)" | Positive = 5,
    seekLong | doc "Long seek duration (seconds)" | Positive = 60,
    defaultVolume | doc "Default volume level" | Positive = 100,
    maxVolume | doc "Maximum volume level" | Positive = 200,
    subBorderSize | doc "Subtitle border size" | Positive = 3,
    cacheSecs | doc "Cache duration (seconds)" | Positive = 300,
    demuxerMaxBytes | doc "Demuxer max bytes" | NonEmpty = "1024MiB",
    volumeStep | doc "Volume adjustment step" | Positive = 2,
    speedStep | doc "Speed adjustment step" | Number = 0.25,
    screenshotTemplate | doc "Screenshot filename template" | NonEmpty = "%F-%P-%n",
  },

  cava | doc "Cava audio visualizer settings (static values only)" = {
    framerate | doc "Visualization framerate" | Positive = 60,
    sensitivity | doc "Input sensitivity" | Positive = 100,
    bars | doc "Number of bars (0 = auto)" | Number = 0,
    barWidth | doc "Width of each bar" | Positive = 2,
    barSpacing | doc "Spacing between bars" | Positive = 1,
    lowerCutoffFreq | doc "Lower frequency cutoff" | Positive = 50,
    higherCutoffFreq | doc "Higher frequency cutoff" | Positive = 10000,
    smoothing | doc "Audio smoothing settings" = {
      integral | doc "Integral smoothing" | Positive = 77,
      gravity | doc "Gravity smoothing" | Positive = 100,
      noiseReduction | doc "Noise reduction factor" | Number = 0.77,
    },
  },
}
