{ config, ... }:
let
  theme = config.theme.colors;
in
{
  services.dunst = {
    enable = true;

    settings = {
      global = {
        origin = "top-right";
        offset = "20x20";

        width = 350;
        height = 100;
        notification_limit = 5;

        frame_width = 2;
        frame_color = theme.accent;
        separator_height = 2;
        separator_color = "frame";
        corner_radius = theme.hypr.rounding;
        transparency = 10;

        padding = 15;
        horizontal_padding = 15;
        text_icon_padding = 15;

        font = "CaskaydiaMono Nerd Font 11";
        markup = "full";
        format = "<b>%s</b>\n%b";
        show_indicators = false;

        enable_recursive_icon_lookup = false;
        icon_theme = "";

        icon_position = "left";
        max_icon_size = 48;

        mouse_left_click = "do_action, close_current";
        mouse_middle_click = "close_all";
        mouse_right_click = "close_current";

        layer = "overlay";
        force_xwayland = false;
      };

      urgency_low = {
        background = "${theme.bg}ee";
        foreground = theme.fg;
        frame_color = theme.green;
        timeout = 3;
      };

      urgency_normal = {
        background = "${theme.bg}ee";
        foreground = theme.fg;
        frame_color = theme.accent;
        timeout = 5;
      };

      urgency_critical = {
        background = "${theme.bg}ee";
        foreground = theme.fg;
        frame_color = theme.red;
        timeout = 10;
      };

      kitty_ignore = {
        appname = "kitty";
        skip_display = true;
      };
    };
  };
}
