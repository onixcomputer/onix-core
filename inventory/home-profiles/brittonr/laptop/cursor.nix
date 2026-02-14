{ config, ... }:
{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    inherit (config.cursor) package name size;
  };
  home.sessionVariables = {
    XCURSOR_THEME = config.cursor.name;
    XCURSOR_SIZE = toString config.cursor.size;
  };
  wayland.windowManager.hyprland.settings = {
    env = [
      "XCURSOR_THEME,${config.cursor.name}"
      "XCURSOR_SIZE,${toString config.cursor.size}"
    ];
  };
}
