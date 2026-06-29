# Desktop-local Herdr profile data — source of truth.
#
# Herdr 0.7.0 does not accept a modifier-only prefix such as bare Alt:
# its key parser requires a non-modifier key in `keys.prefix`. The prefix and
# plugin chords below are derived from the shared base/keymap.ncl source.
let keymap = import "../../base/keymap.ncl" in

let lower = std.string.lowercase in

let prefixed = fun key => "prefix+%{lower key}" in

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
        prefix = "%{lower keymap.modifiers.secondary}+%{lower keymap.herdr.prefixKey}",
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
            key = prefixed keymap.herdr.jjWorkspace.new,
            actionType = "plugin_action",
            command = "nathanflurry.jj-workspace.new",
            description = "new jj workspace",
          },
          {
            key = prefixed keymap.herdr.jjWorkspace.newTab,
            actionType = "plugin_action",
            command = "nathanflurry.jj-workspace.new-tab",
            description = "new jj workspace (in tab)",
          },
          {
            key = prefixed keymap.herdr.jjWorkspace.remove,
            actionType = "plugin_action",
            command = "nathanflurry.jj-workspace.remove",
            description = "remove jj workspace",
          },
        ],
      },
    },
}
