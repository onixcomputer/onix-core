# Desktop-local kache profile data — source of truth.
#
# Validates the managed Cargo defaults and local-only kache pilot settings used
# by the Home Manager module.
let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
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

let NonNegative =
  std.contract.from_validator (match {
    value if std.is_number value && value >= 0 => 'Ok,
    _ => 'Error { message = "must be a non-negative number" },
  }
  )
in

{
  cargo
    | {
      targetDir | NonEmpty,
      jobs | Positive,
      netRetry | Positive,
      termQuiet | Bool,
      linker | NonEmpty,
      linkerArgs | Array NonEmpty,
    }
    = {
      targetDir = "/home/brittonr/.cargo-target",
      # Keep direct Cargo below full workstation saturation. 20 jobs leaves
      # headroom on britton-desktop's 32 hardware threads for the compositor,
      # editor, language servers, and background services.
      jobs = 20,
      netRetry = 3,
      termQuiet = false,
      linker = "cc",
      linkerArgs = [
        "-fuse-ld=mold",
      ],
    },

  kache
    | {
      cacheDir | NonEmpty,
      cacheBudgetGiB | Positive,
      localOnly | Bool,
      daemonService | Bool,
      daemonIdleTimeoutSecs | NonNegative,
      daemonRestartDelay | NonEmpty,
      daemonLogFilter | NonEmpty,
    }
    = {
      cacheDir = "/home/brittonr/.cache/kache",
      cacheBudgetGiB = 32,
      localOnly = true,
      daemonService = true,
      # 0 disables upstream's idle-exit watchdog so systemd remains the daemon owner.
      daemonIdleTimeoutSecs = 0,
      daemonRestartDelay = "5s",
      daemonLogFilter = "kache=info",
    },
}
