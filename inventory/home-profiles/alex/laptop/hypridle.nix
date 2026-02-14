{ config, ... }:
{
  services.hypridle = {
    enable = true;

    settings = {
      general = {
        before_sleep_cmd = "hyprctl dispatch dpms off";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };

      listener = [
        {
          # Turn off screen after 10 minutes
          timeout = config.timeouts.dim;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        {
          # Suspend after 30 minutes (laptop only)
          timeout = config.timeouts.lock;
          on-timeout = "systemctl suspend";
        }
      ];
    };
  };
}
