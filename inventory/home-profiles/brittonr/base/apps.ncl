# Default applications — source of truth.
#
# Defines the user's preferred apps (terminal, browser, file manager,
# sysmon) with names, commands, and Wayland app-ids. Other .ncl files
# can import this to validate appId references.
#
# Commands that need Nix store paths use @placeholder@ tokens
# resolved by the Nix stub.
#
# Consumed by: apps.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/apps.ncl
#   3. Commit .ncl
let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

let App = {
  name | doc "Human-readable application name" | NonEmpty,
  command | doc "Executable path or @placeholder@" | NonEmpty,
  appId | doc "Wayland app-id for window matching" | NonEmpty | optional,
}
in

{
  terminal | App = {
    name = "wezterm",
    command = "@wezterm@",
    appId = "org.wezfurlong.wezterm",
  },

  browser | App = {
    name = "librewolf",
    command = "librewolf",
    appId = "librewolf",
  },

  fileManager | App = {
    name = "yazi",
    command = "yazi",
  },

  sysmon | App = {
    name = "btop",
    command = "btop",
  },
}
