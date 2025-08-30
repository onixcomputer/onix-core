_: {
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
          timeout = 600;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
        # {
        #   # Suspend after 30 minutes (laptop only)
        #   timeout = 1800;
        #   on-timeout = "systemctl suspend";
        # }
      ];
    };
  };
}
