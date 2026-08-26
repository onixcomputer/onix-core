# Fleet Kache Cargo profile data — source of truth.
#
# The machine-level Clan service owns cache storage and remote policy. This file
# validates portable Cargo defaults and the shared system configuration path.
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
      configPath | NonEmpty,
    }
    = {
      configPath = "/etc/kache-rustfs/config.toml",
    },
}
