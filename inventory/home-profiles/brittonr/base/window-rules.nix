{ lib, config, ... }:
{
  options.windowRules = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      # Workspace assignments by app-id regex
      assignments = [
        {
          appId = "kitty";
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
          appId = "kitty";
          title = "^${config.apps.sysmon.name}$";
          workspace = "4";
          maximized = true;
        }
        {
          appId = "kitty";
          title = "^journalctl$";
          workspace = "4";
          maximized = true;
        }
      ];
    };
    description = "Window rules for workspace assignments and app-specific behavior";
  };
}
