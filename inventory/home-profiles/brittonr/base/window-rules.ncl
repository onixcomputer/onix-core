# Window rules — source of truth for workspace assignments and overrides.
#
# Centralizes all compositor window-matching rules so appId regexes,
# workspace targets, and per-title overrides are validated in one place.
#
# Consumed by: window-rules.nix (exposes as readOnly HM options)
# Validated at `ncl export` time.
#
# Workflow:
#   1. Edit this file
#   2. Run: ncl export inventory/home-profiles/brittonr/base/window-rules.ncl
#   3. Commit .ncl
let settings = import "./settings.ncl" in
let apps = import "./apps.ncl" in

let workspaceNames = settings.workspaces.names in

let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

let Workspace =
  std.contract.from_validator (match {
    value if std.is_string value && std.array.elem value workspaceNames => 'Ok,
    value if std.is_string value =>
      'Error {
        message = "unknown workspace: \"%{value}\"",
        notes = ["Valid workspaces: %{std.serialize 'Json workspaceNames}"],
      },
    _ => 'Error { message = "workspace must be a string" },
  }
  )
in

let Assignment = {
  appId | doc "Wayland app-id regex" | NonEmpty,
  workspace | doc "Target workspace name" | Workspace,
  maximized | doc "Open maximized" | Bool | default = false,
}
in

let TitleOverride = {
  appId | doc "Wayland app-id regex" | NonEmpty,
  title | doc "Window title regex" | NonEmpty,
  workspace | doc "Target workspace (optional)" | Workspace | optional,
  maximized | doc "Open maximized" | Bool | optional,
  floating | doc "Open floating" | Bool | optional,
}
in

{
  # Workspace assignments by app-id regex.
  # Use apps.<name>.appId for apps defined in apps.ncl to stay in sync.
  assignments | Array Assignment = [
    { appId = apps.terminal.appId, workspace = "1" },
    { appId = apps.browser.appId, workspace = "2", maximized = true },
    { appId = "vesktop", workspace = "3" },
    { appId = "Element", workspace = "3" },
  ],

  # App-specific overrides matched by title within an app-id.
  # Use @placeholder@ tokens for values resolved at Nix eval time.
  titleOverrides | Array TitleOverride = [
    { appId = apps.browser.appId, title = "^Picture-in-Picture$", floating = true },
    { appId = apps.terminal.appId, title = "@sysmon-title@", workspace = "4", maximized = true },
    { appId = apps.terminal.appId, title = "^journalctl$", workspace = "4", maximized = true },
  ],
}
