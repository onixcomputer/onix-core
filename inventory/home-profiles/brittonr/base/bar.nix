{ lib, config, ... }:
{
  options.bar = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      height = 30;
      spacing = 4;
      calendarScrollSensitivity = 1;
      calendar = {
        months = config.colors.orange;
        days = config.colors.accent2;
        weeks = config.colors.green;
        weekdays = config.colors.yellow;
        today = config.colors.red;
      };
      waybar = {
        workspaceHoverOpacity = "0.15";
        workspaceHoverBorderOpacity = "0.25";
        workspaceActiveShadowOpacity = "0.3";
        workspaceActiveHoverShadowOpacity = "0.4";
        moduleBgOpacity = "0.8";
        moduleRadius = "0.5em";
        modulePadding = "0 0.6em";
        moduleMargin = "0 0.15em";
        workspaceMinWidth = "24px";
        blinkDuration = "0.5s";
        colors = {
          inherit (config.colors.waybar)
            bg
            fg
            accent
            tooltip_bg
            muted
            warning
            critical
            critical_bg
            charging
            ;
        };
      };
    };
    description = "Status bar (waybar) shared settings";
  };
}
