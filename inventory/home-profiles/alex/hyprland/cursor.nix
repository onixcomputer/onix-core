{ pkgs, ... }:
{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = pkgs.phinger-cursors;
    name = "phinger-cursors-dark";
    size = 24;
  };
  home.sessionVariables = {
    XCURSOR_THEME = "phinger-cursors-dark";
    XCURSOR_SIZE = "24";
  };
  wayland.windowManager.hyprland.settings = {
    env = [
      "XCURSOR_THEME,phinger-cursors-dark"
      "XCURSOR_SIZE,24"
    ];
  };
}
