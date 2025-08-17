_: {
  # Dunst notification daemon - supports color emoji!
  services.dunst = {
    enable = true;

    settings = {
      global = {
        # Positioning
        origin = "top-right";
        offset = "20x20";

        # Size
        width = 350;
        height = 100;
        notification_limit = 5;

        # Visual style - matching clean look
        frame_width = 2;
        frame_color = "#7aa2f7";
        separator_height = 2;
        separator_color = "frame";
        corner_radius = 12;
        transparency = 10; # Slight transparency

        # Padding
        padding = 15;
        horizontal_padding = 15;
        text_icon_padding = 15;

        # Text - Use Nerd Font for icons and symbols
        font = "CaskaydiaMono Nerd Font 11";
        markup = "full";
        format = "<b>%s</b>\n%b";

        # Disable any default icon theme that might override text
        enable_recursive_icon_lookup = false;
        icon_theme = "";

        # Icons
        icon_position = "left";
        max_icon_size = 48;

        # Interaction
        mouse_left_click = "do_action, close_current";
        mouse_middle_click = "close_all";
        mouse_right_click = "close_current";

        # Wayland layer
        layer = "overlay";
        force_xwayland = false;
      };

      # Tokyo Night colors
      urgency_low = {
        background = "#1a1b26ee";
        foreground = "#c0caf5";
        frame_color = "#9ece6a";
        timeout = 3000;
      };

      urgency_normal = {
        background = "#1a1b26ee";
        foreground = "#c0caf5";
        frame_color = "#7aa2f7";
        timeout = 5000;
      };

      urgency_critical = {
        background = "#1a1b26ee";
        foreground = "#c0caf5";
        frame_color = "#f7768e";
        timeout = 0;
      };
    };
  };
}
