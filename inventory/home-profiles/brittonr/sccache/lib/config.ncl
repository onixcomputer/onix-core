# Desktop-local sccache profile data — source of truth.
#
# Validates the managed Cargo defaults, sccache cache roots, and
# fail-open log path used by the Home Manager module.
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

{
  cargo
    | {
      targetDir | NonEmpty,
      netRetry | Positive,
      termQuiet | Bool,
      ignoreServerIoError | NonEmpty,
      linker | NonEmpty,
    }
    = {
      targetDir = "/home/brittonr/.cargo-target",
      netRetry = 3,
      termQuiet = false,
      ignoreServerIoError = "1",
      linker = "mold",
    },

  sccache
    | {
      cacheDir | NonEmpty,
      cacheBudgetGiB | Positive,
      errorLog | NonEmpty,
      basedirs | Array NonEmpty,
    }
    = {
      cacheDir = "/home/brittonr/.cache/sccache",
      cacheBudgetGiB = 32,
      errorLog = "/home/brittonr/.cache/sccache/error.log",
      basedirs = [
        "/home/brittonr/git",
        "/home/brittonr/git/worktrees",
      ],
    },
}
