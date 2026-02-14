{ lib, ... }:
{
  options.icons = lib.mkOption {
    type = lib.types.attrs;
    readOnly = true;
    default = {
      # Media player icons
      media = {
        default = "";
        spotify = "";
        librewolf = "";
        chromium = "";
        mpv = "";
      };

      # System monitoring
      system = {
        cpu = "󰍛";
        memory = "󰘚";
        temperature = "󰔏";
        temperatureCritical = "󰸁";
      };

      # Battery status
      battery = {
        charging = "󰂄";
        plugged = "󰚥";
        levels = [
          "󰂎"
          "󰁺"
          "󰁻"
          "󰁼"
          "󰁽"
          "󰁾"
          "󰁿"
          "󰂀"
          "󰂁"
          "󰂂"
          "󰁹"
        ];
      };

      # Audio
      audio = {
        muted = "󰝟";
        levels = [
          "󰕿"
          "󰖀"
          "󰕾"
        ];
      };

      # Network
      network = {
        wifi = "󰤨";
        wifiSwitch = "󰖩";
        ethernet = "󰈁";
        settings = "󰢾";
        rescan = "󰛵";
        lock = "󰌾";
      };

      # Workspace indicators
      workspace = {
        active = "●";
        default = "";
      };

      # Application launchers
      apps = {
        terminal = "";
        launcher = "";
        nixos = "";
      };

      # NixOS generation management
      generations = {
        current = "";
        other = "";
        rebuild = "";
        garbage = "";
        list = "";
      };
    };
    description = "Nerd Font icons for status bar, menus, and scripts";
  };
}
