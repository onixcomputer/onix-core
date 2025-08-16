_: {
  programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        hide_cursor = true;
        grace = 0;
        disable_loading_bar = true;
      };

      # Authentication settings
      auth = {
        "fingerprint:enabled" = true; # Enable parallel fingerprint authentication
        "fingerprint:ready_message" = "(Scan fingerprint to unlock)";
        "fingerprint:present_message" = "Scanning fingerprint";
      };

      # BACKGROUND - Simple blur of current screen
      background = {
        monitor = "";
        path = "screenshot";
        blur_passes = 4;
        blur_size = 7;
        noise = 0.0117;
        contrast = 0.8916;
        brightness = 0.6172;
        vibrancy = 0.1696;
        vibrancy_darkness = 0.0;
      };

      # PASSWORD INPUT - Even bigger, cleaner centered field with Tokyo Night colors
      input-field = {
        monitor = "";
        size = "385, 72"; # 20% bigger
        outline_thickness = 2;

        dots_size = 0.30;
        dots_spacing = 0.45;
        dots_center = true;
        dots_rounding = -1;

        outer_color = "rgba(122, 162, 247, 0.8)";
        inner_color = "rgba(36, 40, 59, 0.85)";
        font_color = "rgb(c0caf5)";
        fail_color = "rgba(247, 118, 142, 0.9)";
        check_color = "rgba(158, 206, 106, 0.9)";
        capslock_color = "rgba(224, 175, 104, 0.9)"; # Yellow warning for caps lock

        fade_on_empty = true;
        fade_timeout = 2000; # Slower fade for smoother effect
        placeholder_text = "<span foreground=\"##7aa2f7aa\" font_size=\"13pt\" font_family=\"CaskaydiaMono Nerd Font\">Password</span>";
        hide_input = false;
        rounding = 14; # More rounded

        fail_transition = 300;

        position = "0, -100"; # Slightly higher to make room for time
        halign = "center";
        valign = "center";
      };

      # TIME DISPLAY - Large clock above password field
      label = [
        {
          monitor = "";
          text = "cmd[update:1000] echo \"$(date +'%I:%M %p')\""; # 12-hour format with AM/PM
          color = "rgba(192, 202, 245, 0.9)";
          font_size = 86; # 20% bigger
          font_family = "CaskaydiaMono Nerd Font";
          position = "0, 140";
          halign = "center";
          valign = "center";
        }
        # DATE DISPLAY - Smaller date below time
        {
          monitor = "";
          text = "cmd[update:1000] echo \"$(date +'%A, %B %d')\"";
          color = "rgba(122, 162, 247, 0.7)";
          font_size = 22; # Also slightly bigger
          font_family = "CaskaydiaMono Nerd Font";
          position = "0, 60";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
