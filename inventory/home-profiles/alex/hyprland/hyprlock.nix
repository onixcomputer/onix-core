{ config, lib, ... }:
let
  theme = config.theme.colors;
  # Remove # from hex colors
  c = color: lib.removePrefix "#" color;
in
{
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

        outer_color = "rgb(${c theme.accent})";
        inner_color = "rgb(${c theme.bg_highlight})";
        font_color = "rgb(${c theme.fg})";
        fail_color = "rgb(${c theme.red})";
        check_color = "rgb(${c theme.green})";
        capslock_color = "rgb(${c theme.yellow})"; # Yellow warning for caps lock

        fade_on_empty = true;
        fade_timeout = 2000; # Slower fade for smoother effect
        placeholder_text = "<span foreground=\"##${c theme.accent}aa\" font_size=\"13pt\" font_family=\"CaskaydiaMono Nerd Font\">Password</span>";
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
          color = "rgb(${c theme.fg})";
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
          color = "rgb(${c theme.accent})";
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
