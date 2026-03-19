{ lib, config, ... }:
{
  options.bar = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      height = 30;
      spacing = 4;
      position = "top";
      floating = false;
      density = "default";
      displayMode = "always_visible";
      showCapsule = true;
      outerCorners = false;
      clockFormat = "HH:mm ddd, MMM dd";
      calendarScrollSensitivity = 1;
      tray = {
        spacing = 10;
      };
      maxLength = {
        title = 50;
        module = 40;
      };
      calendar = {
        months = config.theme.data.orange.hex;
        days = config.theme.data.accent2.hex;
        weeks = config.theme.data.green.hex;
        weekdays = config.theme.data.yellow.hex;
        today = config.theme.data.red.hex;
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
          bg = config.theme.data.bar_waybar.bg.hex;
          fg = config.theme.data.bar_waybar.fg.hex;
          accent = config.theme.data.bar_waybar.accent.hex;
          tooltip_bg = config.theme.data.bar_waybar.tooltip_bg.hex;
          muted = config.theme.data.bar_waybar.muted.hex;
          warning = config.theme.data.bar_waybar.warning.hex;
          critical = config.theme.data.bar_waybar.critical.hex;
          critical_bg = config.theme.data.bar_waybar.critical_bg.hex;
          charging = config.theme.data.bar_waybar.charging.hex;
        };
      };
    };
    description = "Status bar shared settings";
  };
}
