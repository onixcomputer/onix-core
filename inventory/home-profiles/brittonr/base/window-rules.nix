{ lib, config, ... }:
{
  options.windowRules = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      # Workspace assignments by app-id regex
      assignments = [
        {
          appId = "org.wezfurlong.wezterm";
          workspace = "1";
        }
        {
          appId = "librewolf";
          workspace = "2";
          maximized = true;
        }
        {
          appId = "vesktop";
          workspace = "3";
        }
        {
          appId = "Element";
          workspace = "3";
        }
      ];

      # App-specific overrides (matched by title within an app-id)
      titleOverrides = [
        {
          appId = "librewolf";
          title = "^Picture-in-Picture$";
          floating = true;
        }
        {
          appId = "org.wezfurlong.wezterm";
          title = "^${config.apps.sysmon.name}$";
          workspace = "4";
          maximized = true;
        }
        {
          appId = "org.wezfurlong.wezterm";
          title = "^journalctl$";
          workspace = "4";
          maximized = true;
        }
      ];
    };
    description = "Window rules for workspace assignments and app-specific behavior";
  };
}
