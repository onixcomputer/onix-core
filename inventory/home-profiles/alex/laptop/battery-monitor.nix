{ pkgs, ... }:
let
  batteryMonitorScript = pkgs.writeShellScript "battery-monitor" ''
    BATTERY_THRESHOLD=15
    CRITICAL_THRESHOLD=5
    NOTIFICATION_FLAG="/run/user/$UID/battery_notified"
    CRITICAL_FLAG="/run/user/$UID/battery_critical"

    get_battery_percentage() {
      ${pkgs.upower}/bin/upower -i $(${pkgs.upower}/bin/upower -e | grep 'BAT') | \
        grep -E "percentage" | grep -o '[0-9]\+' || echo "100"
    }

    get_battery_state() {
      ${pkgs.upower}/bin/upower -i $(${pkgs.upower}/bin/upower -e | grep 'BAT') | \
        grep -E "state" | awk '{print $2}' || echo "unknown"
    }

    BATTERY_LEVEL=$(get_battery_percentage)
    BATTERY_STATE=$(get_battery_state)

    if [[ "$BATTERY_STATE" == "discharging" ]]; then
      if [[ "$BATTERY_LEVEL" -le "$CRITICAL_THRESHOLD" ]]; then
        if [[ ! -f "$CRITICAL_FLAG" ]]; then
          ${pkgs.libnotify}/bin/notify-send -u critical \
            "Battery Critical!" \
            "Battery at $BATTERY_LEVEL% - System will hibernate soon!" \
            -i battery-caution
          touch "$CRITICAL_FLAG"
        fi
      elif [[ "$BATTERY_LEVEL" -le "$BATTERY_THRESHOLD" ]]; then
        if [[ ! -f "$NOTIFICATION_FLAG" ]]; then
          ${pkgs.libnotify}/bin/notify-send -u normal \
            "Battery Low" \
            "Battery at $BATTERY_LEVEL% - Time to charge!" \
            -i battery-low
          touch "$NOTIFICATION_FLAG"
        fi
      else
        rm -f "$NOTIFICATION_FLAG" "$CRITICAL_FLAG"
      fi
    else
      rm -f "$NOTIFICATION_FLAG" "$CRITICAL_FLAG"
    fi
  '';
in
{
  # Battery monitor service
  systemd.user.services.battery-monitor = {
    Unit = {
      Description = "Battery level monitor";
      After = [ "graphical-session.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${batteryMonitorScript}";
    };
  };

  # Timer to run battery monitor every 30 seconds
  systemd.user.timers.battery-monitor = {
    Unit = {
      Description = "Battery monitor timer";
      Requires = [ "battery-monitor.service" ];
    };

    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "30s";
      AccuracySec = "10s";
    };

    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
