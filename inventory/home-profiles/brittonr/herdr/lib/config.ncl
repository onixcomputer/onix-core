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

let gitCommitHexLength = 40 in

let GitCommit =
  std.contract.from_validator (match {
    value if std.is_string value
      && std.string.length value == gitCommitHexLength
      && std.string.is_match "^[0-9a-f]+$" value => 'Ok,
    _ => 'Error { message = "must be a lowercase 40-character Git commit" },
  }
  )
in

let PluginSource = {
  name | NonEmpty,
  source | NonEmpty,
  version | NonEmpty,
  revision | GitCommit,
}
in

let PluginCommand = {
  key | NonEmpty,
  actionType | NonEmpty,
  command | NonEmpty,
  description | NonEmpty,
}
in

let SidebarToken = {
  token | NonEmpty,
  fg | NonEmpty | optional,
  bold | Bool | optional,
  dim | Bool | optional,
}
in

let SidebarRow = Array SidebarToken in

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
      ui
        | {
          sidebar
            | {
              spaces
                | {
                  row_gap | Number,
                  rows | Array SidebarRow,
                },
            },
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
      ui = {
        sidebar = {
          spaces = {
            row_gap = 0,
            # r[impl onix.britton-desktop.herdr.pueue.sidebar_overview]
            rows = [
              [{ token = "state_icon" }, { token = "workspace" }],
              [{ token = "branch" }, { token = "git_status" }],
              [{ token = "$pueue_status", fg = "#cba6f7", bold = true }],
              [{ token = "$pueue_running_1", dim = true }],
              [{ token = "$pueue_running_2", dim = true }],
            ],
          },
        },
      },
    },

  # r[impl onix.britton-desktop.herdr.workflow_plugins.sources]
  # r[impl onix.britton-desktop.herdr.wrapper.plugins.fixed]
  pluginSources
    | Array PluginSource
    = [
      {
        name = "herdr-file-viewer",
        source = "smarzban/herdr-file-viewer",
        version = "1.14.0",
        revision = "96fcc0a2bdd2727ec88c38f8c8806f97b7ca0ea0",
      },
      {
        name = "herdr-reviewr",
        source = "persiyanov/herdr-reviewr",
        version = "0.26.2",
        revision = "1068100ec5553f51f7527f60fb08055d7f2fd29e",
      },
      {
        name = "vim-herdr-navigation",
        source = "paulbkim-dev/vim-herdr-navigation",
        version = "0.1.0",
        revision = "548607d0e417fdb30966846fce7436aa05a6738d",
      },
      {
        name = "ghzinga",
        source = "osolmaz/ghzinga/plugins/herdr",
        version = "0.5.0",
        revision = "30cf4ac79c69140cdac1c8bcf7caa54be34f361b",
      },
      {
        name = "herdr-mirror",
        source = "nikok6/herdr-mirror",
        version = "0.1.14",
        revision = "8bfc7cfca617ab92b068f8ef21b48c3bed807918",
      },
      {
        name = "herdr-plugin-jj-workspace",
        source = "NathanFlurry/herdr-plugin-jj-workspace",
        version = "0.1.0",
        revision = "a9f1d3bcdaa2354e336a5173da85cbe4970c0f2e",
      },
      {
        name = "herdr-plugin-pueue",
        source = "../herdr-plugin-pueue",
        version = "0.1.0",
        revision = "29b2ba060297ec15909e06ef1311200c17965cbe",
      },
    ],

  plugins
    | {
      jjWorkspace
        | {
          commands | Array PluginCommand,
        },
      pueueDashboard
        | {
          commands | Array PluginCommand,
        },
      fileViewer
        | {
          commands | Array PluginCommand,
        },
      reviewr
        | {
          commands | Array PluginCommand,
        },
      vimNavigation
        | {
          commands | Array PluginCommand,
        },
    }
    = {
      jjWorkspace = {
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
      # r[impl onix.britton-desktop.herdr.pueue.bindings]
      # r[impl onix.britton-desktop.herdr.wrapper.ownership]
      pueueDashboard = {
        commands = [
          {
            key = prefixed keymap.herdr.pueueDashboard.popup,
            actionType = "plugin_action",
            command = "dev.herdr.pueue.open-dashboard",
            description = "open Pueue dashboard popup",
          },
          {
            key = prefixed keymap.herdr.pueueDashboard.split,
            actionType = "plugin_action",
            command = "dev.herdr.pueue.open-dashboard-split",
            description = "open Pueue dashboard split",
          },
        ],
      },
      # r[impl onix.britton-desktop.herdr.workflow_plugins.bindings]
      fileViewer = {
        commands = [
          {
            key = prefixed keymap.herdr.fileViewer.split,
            actionType = "plugin_action",
            command = "herdr-file-viewer.open-file-viewer",
            description = "open file viewer split",
          },
          {
            key = prefixed keymap.herdr.fileViewer.tab,
            actionType = "plugin_action",
            command = "herdr-file-viewer.open-file-viewer-tab",
            description = "open file viewer tab",
          },
        ],
      },
      reviewr = {
        commands = [
          {
            key = prefixed keymap.herdr.reviewr.toggle,
            actionType = "plugin_action",
            command = "persiyanov.reviewr.toggle",
            description = "toggle reviewr sidebar",
          },
        ],
      },
      vimNavigation = {
        commands = [
          {
            key = lower keymap.herdr.vimNavigation.left,
            actionType = "plugin_action",
            command = "vim-herdr-navigation.left",
            description = "navigate left between Vim and Herdr",
          },
          {
            key = lower keymap.herdr.vimNavigation.down,
            actionType = "plugin_action",
            command = "vim-herdr-navigation.down",
            description = "navigate down between Vim and Herdr",
          },
          {
            key = lower keymap.herdr.vimNavigation.up,
            actionType = "plugin_action",
            command = "vim-herdr-navigation.up",
            description = "navigate up between Vim and Herdr",
          },
          {
            key = lower keymap.herdr.vimNavigation.right,
            actionType = "plugin_action",
            command = "vim-herdr-navigation.right",
            description = "navigate right between Vim and Herdr",
          },
        ],
      },
    },
}
