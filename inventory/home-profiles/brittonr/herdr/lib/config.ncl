# Desktop-local Herdr profile data — source of truth.
#
# Herdr 0.7.0 does not accept a modifier-only prefix such as bare Alt:
# its key parser requires a non-modifier key in `keys.prefix`. Use the
# Alt-based terminal chord below so Herdr stays close to the requested Alt
# prefix while remaining valid Herdr TOML.
let NonEmpty =
  std.contract.from_validator (match {
    value if std.is_string value && std.string.length value > 0 => 'Ok,
    _ => 'Error { message = "must be a non-empty string" },
  }
  )
in

let PluginCommand = {
  key | NonEmpty,
  actionType | NonEmpty,
  command | NonEmpty,
  description | NonEmpty,
}
in

{
  config
    | {
      onboarding | Bool,
      update
        | {
          version_check | Bool,
          manifest_check | Bool,
        },
      keys
        | {
          prefix | NonEmpty,
        },
    }
    = {
      onboarding = false,
      update = {
        version_check = false,
        manifest_check = false,
      },
      keys = {
        prefix = "alt+space",
      },
    },

  plugins
    | {
      jjWorkspace
        | {
          installSource | NonEmpty,
          commands | Array PluginCommand,
        },
    }
    = {
      jjWorkspace = {
        installSource = "NathanFlurry/herdr-plugin-jj-workspace",
        commands = [
          {
            key = "prefix+a",
            actionType = "plugin_action",
            command = "nathanflurry.jj-workspace.new",
            description = "new jj workspace",
          },
          {
            key = "prefix+shift+a",
            actionType = "plugin_action",
            command = "nathanflurry.jj-workspace.new-tab",
            description = "new jj workspace (in tab)",
          },
          {
            key = "prefix+d",
            actionType = "plugin_action",
            command = "nathanflurry.jj-workspace.remove",
            description = "remove jj workspace",
          },
        ],
      },
    },
}
